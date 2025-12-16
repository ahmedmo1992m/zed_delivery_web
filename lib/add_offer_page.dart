// add_offer_page.dart
// نسخة احترافية متوافقة مع هيكل بيانات Firestore (sizes كـ Array of Maps)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// تأكد إن المسار ده صح عشان متضربش
import 'store_offers_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

// 💡 نموذج بيانات مُعدَّل: ليناسب البيانات المجلوبة من Firestore
class ItemModel {
  final String id;
  final String name;
  final List<String> sizes; // قائمة أسماء الأحجام فقط (عشان الـ UI)
  // لو فيه إضافات (Addons) ممكن تضيفها هنا كمان
  const ItemModel(this.id, this.name, this.sizes);
}

// كلاس الإعدادات الخاصة برفع الصور (زي ما كانت)
class ImageKitConfig {
  static const String publicKey = 'public_DdZaQNVPnIkcdTeeu+GlqFVn1hM=';
  static const String privateKey = 'private_XVb2nRDWt1k6eOf1UB306WjwIoY=';
  static const String uploadUrl =
      'https://upload.imagekit.io/api/v1/files/upload';
  static const String folder = '/store_offers';
}

// ----------------------------------------------------------------------
// ----------------------------------------------------------------------

class AddOfferPage extends StatefulWidget {
  final String storeId;
  final String? storeName;
  const AddOfferPage({super.key, required this.storeId, this.storeName});

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _active = true;
  bool _isSaving = false;

  // 🟢 حالة جلب الأصناف
  List<ItemModel> _availableItems = [];
  bool _isLoadingItems = true;

  // 🆕 متغيرات الحالة الجديدة
  String? _selectedOfferType;
  final List<String> _offerTypes = [' خطأ     ', 'باقة بسعر ثابت', ' خطأ '];

  // 🆕 متغيرات خاصة بالعروض
  List<Map<String, dynamic>> _buyItems = [];
  List<Map<String, dynamic>> _getFreeItems = [];
  double? _fixedPrice;
  List<Map<String, dynamic>> _bundleItems = [];
  double? _percentageDiscount;

  // 📸 متغيرات رفع الصور
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // 🟢 أول حاجة بتتعمل: جلب أصناف المحل
    _fetchAvailableItems();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🟢 دالة جلب المنتجات من Firestore وتجهيزها
  // ----------------------------------------------------------
  Future<void> _fetchAvailableItems() async {
    if (widget.storeId.isEmpty) {
      if (mounted) setState(() => _isLoadingItems = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('store_items') // ✅ تم تغيير الاسم هنا
          .where('store_id', isEqualTo: widget.storeId)
          .where(
            'available',
            isEqualTo: true,
          ) // عشان منجيبش المنتجات الغير متاحة
          .get();

      final List<ItemModel> fetchedItems = snapshot.docs.map((doc) {
        final data = doc.data();
        final itemID = doc.id; // استخدام ID المستند كمعرف للمنتج

        // استخراج أسماء الأحجام فقط من Array of Maps
        final sizesList = data['sizes'] as List<dynamic>? ?? [];
        final itemSizes = sizesList
            .map((s) => s['name'].toString())
            .where((name) => name.isNotEmpty) // فلترة الأسماء الفارغة
            .toList();

        // لو مفيش أحجام، بنحط حجم افتراضي عشان الـ Dropdown ميضربش
        if (itemSizes.isEmpty) {
          itemSizes.add('افتراضي');
        }

        return ItemModel(itemID, data['name'].toString(), itemSizes);
      }).toList();

      if (mounted) {
        setState(() {
          _availableItems = fetchedItems;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ خطأ في جلب الأصناف: $e')));
        setState(() => _isLoadingItems = false);
      }
    }
  }

  // الدوال المساعدة (بدون تغيير)
  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? now.add(const Duration(days: 7))),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? d) =>
      d == null ? '-' : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _uploadedImageUrl = null; // إعادة تعيين الرابط قبل رفع جديد
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ الرجاء اختيار صورة أولاً.')),
      );
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ImageKitConfig.uploadUrl),
      );
      String basicAuth =
          'Basic ${base64Encode(utf8.encode('${ImageKitConfig.privateKey}:'))}';
      request.headers['Authorization'] = basicAuth;
      request.fields['fileName'] =
          'offer_${DateTime.now().millisecondsSinceEpoch}.jpg';
      request.fields['folder'] = ImageKitConfig.folder;
      request.files.add(
        await http.MultipartFile.fromPath('file', _selectedImage!.path),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _uploadedImageUrl = data['url']);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ تم رفع الصورة بنجاح!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل رفع الصورة: $responseData')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ حدث خطأ أثناء رفع الصورة: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // دالة بناء الـ Payload النهائي (بدون تغيير)
  Map<String, dynamic> _buildOfferPayload() {
    Map<String, dynamic> offerDetails = {};

    if (_selectedOfferType == '   خطأ  ؟؟؟     ') {
      offerDetails = {
        'type_key': 'buy_get_free',
        'buy': _buyItems,
        'get_free': _getFreeItems,
      };
    } else if (_selectedOfferType == 'باقة بسعر ثابت') {
      offerDetails = {
        'type_key': 'fixed_price_bundle',
        'price': _fixedPrice,
        'bundle': _bundleItems,
      };
    } else if (_selectedOfferType == '  ؟؟؟ خطأ  ') {
      offerDetails = {
        'type_key': 'percentage_discount',
        'percentage': _percentageDiscount,
        'target': 'all',
      };
    }

    return {
      'store_id': widget.storeId,
      'title': _titleController.text,
      'description': _descriptionController.text,
      'image_url': _uploadedImageUrl ?? '',
      'start_date': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
      'end_date': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
      'active': _active,
      'created_at': Timestamp.now(),
      'offer_type_display': _selectedOfferType,
      'details': offerDetails,
    };
  }

  Future<void> _saveOffer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage != null && _uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ الرجاء رفع الصورة قبل الحفظ')),
      );
      return;
    }

    // ⚠️ تأكد من إدخال البيانات الخاصة بنوع العرض المختار
    if (_selectedOfferType == ' X     ' &&
        (_buyItems.isEmpty || _getFreeItems.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ يجب إضافة منتجات للمشتريات ومنتجات مجانية في هذا العرض.',
          ),
        ),
      );
      return;
    }

    if (_selectedOfferType == 'باقة بسعر ثابت' &&
        (_fixedPrice == null || _bundleItems.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ يجب تحديد سعر الباقة وإضافة محتوياتها.'),
        ),
      );
      return;
    }

    if (_selectedOfferType == ' خطأ ' && _percentageDiscount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ يجب تحديد نسبة الخصم.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = _buildOfferPayload();
      await FirebaseFirestore.instance.collection('offers').add(payload);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ تم إضافة العرض بنجاح')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🆕 دالة بناء صف اختيار صنف، حجم وكمية (تم تطويرها للاعتماد على _availableItems)
  Widget _buildItemSelectionRow({
    required String title,
    required Map<String, dynamic> itemData, // البيانات الحالية للمنتج
    required ValueChanged<Map<String, dynamic>> onChanged,
    required VoidCallback onRemove,
  }) {
    // ⚠️ البحث عن المنتج المُختار من القائمة المجلوبة
    final ItemModel selectedItemModel = _availableItems.firstWhere(
      (e) => e.id == itemData['item_id'],
      orElse: () => _availableItems.first,
    );

    // لو مفيش منتجات، مش هنعرض حاجة

    // عشان نضمن إن الـ size اللي في itemData موجود في الأحجام المتاحة للمنتج ده
    String? currentSize = selectedItemModel.sizes.contains(itemData['size'])
        ? itemData['size']
        : selectedItemModel.sizes.isNotEmpty
        ? selectedItemModel.sizes.first
        : null;

    final int quantity = itemData['quantity'] ?? 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: title.contains('مجاني')
          ? Colors.green.shade50
          : Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<ItemModel>(
                    decoration: const InputDecoration(
                      labelText: 'الصنف',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    value: selectedItemModel,
                    items: _availableItems
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                    onChanged: (newItem) {
                      if (newItem != null) {
                        onChanged({
                          'item_id': newItem.id,
                          'size': newItem.sizes.isNotEmpty
                              ? newItem.sizes.first
                              : null, // اختر الحجم الأول كافتراضي
                          'quantity': quantity,
                        });
                      }
                    },
                    validator: (v) => v == null ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'الحجم',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    value: currentSize,
                    items: selectedItemModel.sizes
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (newSize) {
                      onChanged({
                        'item_id': selectedItemModel.id,
                        'size': newSize,
                        'quantity': quantity,
                      });
                    },
                    validator: (v) => v == null ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: quantity.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'كمية',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    onChanged: (v) {
                      final q = int.tryParse(v) ?? 1;
                      onChanged({
                        'item_id': selectedItemModel.id,
                        'size': currentSize,
                        'quantity': q,
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 بناء واجهة إدخال العروض حسب النوع (تم إضافة حماية للـ availableItems)
  Widget _buildOfferSpecificFields() {
    if (_selectedOfferType == null) {
      return const Center(child: Text('اختر نوع العرض أولاً لتحديد تفاصيله.'));
    }

    // ⚠️ حماية عشان لو مفيش أصناف مضافة
    if (_availableItems.isEmpty) {
      return const Center(
        child: Text('لا يوجد أصناف متاحة في المحل لتحديد العرض.'),
      );
    }

    // تهيئة البيانات الافتراضية لأول صنف
    final Map<String, dynamic> defaultItemData = {
      'item_id': _availableItems.first.id,
      'size': _availableItems.first.sizes.first,
      'quantity': 1,
    };

    if (_selectedOfferType == 'خطأ') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '**المشتريات (Buy):**',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._buyItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return _buildItemSelectionRow(
              title: 'منتج مشتري #${index + 1}',
              itemData: item,
              onChanged: (newItemData) =>
                  setState(() => _buyItems[index] = newItemData),
              onRemove: () => setState(() => _buyItems.removeAt(index)),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _buyItems.add(defaultItemData);
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة منتج للمشتريات (Buy)'),
          ),
          const Divider(height: 24),

          const Text(
            '**المجاني (Get Free):**',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._getFreeItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildItemSelectionRow(
              title: 'منتج مجاني #${index + 1}',
              itemData: item,
              onChanged: (newItemData) =>
                  setState(() => _getFreeItems[index] = newItemData),
              onRemove: () => setState(() => _getFreeItems.removeAt(index)),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _getFreeItems.add(defaultItemData);
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة منتج مجاني (Get Free)'),
          ),
        ],
      );
    } else if (_selectedOfferType == 'باقة بسعر ثابت') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: _fixedPrice?.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'السعر الثابت للباقة (جنيه)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              prefixIcon: Icon(Icons.money),
            ),
            onChanged: (v) => _fixedPrice = double.tryParse(v),
            validator: (v) =>
                (v == null || v.isEmpty || double.tryParse(v) == null)
                ? 'ادخل سعر صحيح'
                : null,
          ),
          const SizedBox(height: 16),
          const Text(
            '📦 **محتويات الباقة (Bundle):**',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._bundleItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildItemSelectionRow(
              title: 'منتج باقة #${index + 1}',
              itemData: item,
              onChanged: (newItemData) =>
                  setState(() => _bundleItems[index] = newItemData),
              onRemove: () => setState(() => _bundleItems.removeAt(index)),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _bundleItems.add(defaultItemData);
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة منتج للباقة'),
          ),
        ],
      );
    } else if (_selectedOfferType == ' خطأ ') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: _percentageDiscount?.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'نسبة الخصم (%)',
              hintText: 'مثال: 10 أو 25',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              prefixIcon: Icon(Icons.percent),
            ),
            onChanged: (v) => _percentageDiscount = double.tryParse(v),
            validator: (v) =>
                (v == null ||
                    double.tryParse(v) == null ||
                    (double.tryParse(v) ?? 0) > 100)
                ? 'ادخل نسبة صحيحة بين 1 و 100'
                : null,
          ),
          const SizedBox(height: 10),
          const Text(
            'الخصم سيتم تطبيقه على الإجمالي حالياً (يمكن إضافة خيارات للتخصيص لاحقاً).',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // 💡 معاينة العرض المحدثة (بدون تغيير)
  void _previewOffer() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('معاينة العرض'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'العنوان: **${_titleController.text}**',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'النوع: **${_selectedOfferType ?? 'لم يحدد'}**',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Text('التفاصيل: ${_descriptionController.text}'),
              const SizedBox(height: 10),
              if (_selectedImage != null)
                Image.file(
                  _selectedImage!,
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 6),
              Text(
                'المدة: ${_formatDate(_startDate)} → ${_formatDate(_endDate)}',
              ),
              const SizedBox(height: 6),
              Text('الحالة: ${_active ? 'مفعل' : 'غير مفعل'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('اغلاق'),
          ),
        ],
      ),
    );
  }

  // 💡 إعادة بناء الـ fields الأساسية (بدون تغيير)
  Widget _buildBasicFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'عنوان العرض',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.tag_faces),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'ادخل عنوان العرض' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'تفاصيل العرض',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.description),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'ادخل تفاصيل العرض' : null,
        ),
        const SizedBox(height: 12),
        // أزرار الصورة
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: Text(
                  _selectedImage == null ? 'اختر صورة للعرض' : 'تم اختيار صورة',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_selectedImage != null && !_isUploadingImage)
                    ? _uploadImage
                    : null,
                icon: _isUploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _uploadedImageUrl == null ? 'رفع الصورة' : 'تم الرفع',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _uploadedImageUrl != null
                      ? Colors.green
                      : Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
        if (_uploadedImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Image.network(
              _uploadedImageUrl!,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          ),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إضافة عرض${widget.storeName != null ? ' - ${widget.storeName}' : ''}',
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'عروض المحل',
            onPressed: () {
              if (widget.storeId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreOffersPage(storeId: widget.storeId),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خطأ: لا يوجد معرف للمحل')),
                );
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. كارت تفاصيل العرض الأساسية
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'تفاصيل العرض الأساسية',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _buildBasicFields(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. حالة التحميل أو عرض نموذج إدخال العروض
                _isLoadingItems
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text('جاري تحميل أصناف المحل...'),
                            ],
                          ),
                        ),
                      )
                    : Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'تحديد نوع العرض',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'اختر نوع العرض',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(8),
                                    ),
                                  ),
                                ),
                                value: _selectedOfferType,
                                items: _offerTypes
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedOfferType = newValue;
                                    // إعادة تعيين تفاصيل العروض القديمة
                                    _buyItems = [];
                                    _getFreeItems = [];
                                    _bundleItems = [];
                                    _fixedPrice = null;
                                    _percentageDiscount = null;
                                  });
                                },
                                validator: (v) => v == null
                                    ? 'الرجاء اختيار نوع العرض'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildOfferSpecificFields(), // واجهة الإدخال حسب النوع
                            ],
                          ),
                        ),
                      ),

                const SizedBox(height: 16),

                // 3. كارت مدة العرض وحالة التفعيل
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'مدة العرض وحالته',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(isStart: true),
                                child: Text('من: ${_formatDate(_startDate)}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(isStart: false),
                                child: Text('إلى: ${_formatDate(_endDate)}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('حالة العرض'),
                            Switch(
                              value: _active,
                              onChanged: (v) => setState(() => _active = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. أزرار التحكم
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('معاينة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                        ),
                        onPressed: _previewOffer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ العرض'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                        ),
                        onPressed: (_isSaving || _isLoadingItems)
                            ? null
                            : _saveOffer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
