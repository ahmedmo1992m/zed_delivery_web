import 'dart:convert';
// تم إزالة استيراد 'dart:io'; تمامًا لأنه بيسبب مشاكل في الويب
// import 'dart:io';
import 'dart:typed_data'; // لازم للـ Uint8List اللي بنستخدمها في الويب
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class AddItemsPage extends StatefulWidget {
  final String storeId;
  const AddItemsPage({super.key, required this.storeId});

  @override
  State<AddItemsPage> createState() => _AddItemsPageState();
}
// ignore_for_file: prefer_final_fields

class _AddItemsPageState extends State<AddItemsPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _sortController = TextEditingController(
    text: '0',
  );
  final TextEditingController searchController = TextEditingController();

  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _available = true;

  // XFile هو النوع الأفضل اللي بيشتغل على كل المنصات
  XFile? _pickedXFile;
  String? _uploadedImageUrl;

  List<Map<String, dynamic>> _sizes = [];
  List<Map<String, dynamic>> _addons = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String imageKitUploadUrl =
      'https://upload.imagekit.io/api/v1/files/upload';
  static const String imageKitPrivateKey =
      'private_XVb2nRDWt1k6eOf1UB306WjwIoY=';

  late TabController _tabController;
  String searchQuery = "";
  DocumentSnapshot? editingItem; // لتعديل صنف موجود

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _sortController.dispose();
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // 1. الدالة المعدلة: _pickImage()
  Future _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() {
      _pickedXFile = image;
      _isLoading = true; // بدأ التحميل
      _uploadedImageUrl = null;
    });

    // 🔴 التعديل هنا: نمرر الـ XFile مباشرةً لدالة الرفع
    final url = await _uploadToImageKit(image);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (url != null) {
        _uploadedImageUrl = url;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم رفع الصورة بنجاح')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل رفع الصورة. حاول مرة أخرى.')),
        );
      }
    });
  }

  // 2. الدالة المعدلة: _uploadToImageKit()
  // 🔴 تم تغيير نوع الـ Input من (File file) إلى (XFile xFile)
  Future<String?> _uploadToImageKit(XFile xFile) async {
    try {
      // 🔴 نستخدم xFile.readAsBytes() لقراءة الـ bytes، ودي بتشتغل على الويب
      final bytes = await xFile.readAsBytes();
      final base64Str = base64Encode(bytes);
      final filename = '${const Uuid().v4()}.jpg';

      final response = await http.post(
        Uri.parse(imageKitUploadUrl),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$imageKitPrivateKey:'))}',
        },
        body: {'file': base64Str, 'fileName': filename},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      } else {
        debugPrint(
          'ImageKit upload failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('upload error: $e');
      return null;
    }
  }

  void _addSizeRow() => setState(() => _sizes.add({'name': '', 'price': ''}));
  void _addAddonRow() => setState(() => _addons.add({'name': '', 'price': ''}));
  void _removeSize(int index) => setState(() => _sizes.removeAt(index));
  void _removeAddon(int index) => setState(() => _addons.removeAt(index));

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _descController.clear();
    _priceController.clear();
    _sizes.clear();
    _addons.clear();
    _pickedXFile = null;
    _uploadedImageUrl = null;
    _selectedCategoryId = null;
    _available = true;
    _sortController.text = '0';
    editingItem = null;
    setState(() {});
  }

  void _editItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    editingItem = doc;
    _nameController.text = data['name'] ?? '';
    _descController.text = data['description'] ?? '';
    _priceController.text = (data['price'] ?? '').toString();
    _sortController.text = (data['sort_order'] ?? '0').toString();
    _selectedCategoryId = data['category_id'];
    _available = data['available'] ?? true;
    _sizes = List<Map<String, dynamic>>.from(data['sizes'] ?? []);
    _addons = List<Map<String, dynamic>>.from(data['addons'] ?? []);
    _uploadedImageUrl = data['image'];
    _pickedXFile = null;
    _tabController.animateTo(0);
    setState(() {});
  }

  Future<void> _saveItem({DocumentSnapshot? editingItem}) async {
    if (!_formKey.currentState!.validate()) return;

    // شرط إجباري لو مفيش صورة مرفوعة
    if (_uploadedImageUrl == null || _uploadedImageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب رفع صورة الصنف أولاً.')),
      );
      return;
    }

    final itemData = {
      'store_id': widget.storeId,
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'price': _sizes.isNotEmpty
          ? double.tryParse(_sizes.first['price'].toString()) ?? 0
          : double.tryParse(_priceController.text) ?? 0,
      'sizes': _sizes,
      'addons': _addons,
      'available': _available,
      'created_at': FieldValue.serverTimestamp(),
      'sort_order': int.tryParse(_sortController.text) ?? 0,
      'category_id': _selectedCategoryId,
      'image': _uploadedImageUrl ?? "",
    };

    try {
      setState(() => _isLoading = true);
      if (editingItem == null) {
        // إضافة صنف جديد
        final newDoc = await _firestore.collection('store_items').add(itemData);
        await _firestore
            .collection('categories')
            .doc(_selectedCategoryId)
            .collection('items')
            .doc(newDoc.id)
            .set(itemData);
      } else {
        // تحديث الصنف الموجود
        await _firestore
            .collection('store_items')
            .doc(editingItem.id)
            .update(itemData);
        await _firestore
            .collection('categories')
            .doc(_selectedCategoryId)
            .collection('items')
            .doc(editingItem.id)
            .update(itemData);
      }
      setState(() => _isLoading = false);
      _clearForm();
      _tabController.animateTo(1); // بعد التحديث نروح للتاب الأصناف المضافة

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingItem == null ? 'تم الحفظ بنجاح' : 'تم التحديث بنجاح',
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSizesEditor() {
    return Column(
      children: [
        ..._sizes.asMap().entries.map((entry) {
          final i = entry.key;
          final data = entry.value;
          return Row(
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  initialValue: data['name'],
                  decoration: const InputDecoration(labelText: 'اسم الحجم'),
                  onChanged: (v) => data['name'] = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: data['price']?.toString(),
                  decoration: const InputDecoration(labelText: 'سعر'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => data['price'] = double.tryParse(v) ?? 0,
                ),
              ),
              IconButton(
                onPressed: () => _removeSize(i),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _addSizeRow,
            icon: const Icon(Icons.add),
            label: const Text('إضافة حجم'),
          ),
        ),
      ],
    );
  }

  Widget _buildAddonsEditor() {
    return Column(
      children: [
        ..._addons.asMap().entries.map((entry) {
          final i = entry.key;
          final data = entry.value;
          return Row(
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  initialValue: data['name'],
                  decoration: const InputDecoration(labelText: 'اسم الإضافة'),
                  onChanged: (v) => data['name'] = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: data['price']?.toString(),
                  decoration: const InputDecoration(labelText: 'سعر'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => data['price'] = double.tryParse(v) ?? 0,
                ),
              ),
              IconButton(
                onPressed: () => _removeAddon(i),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _addAddonRow,
            icon: const Icon(Icons.add),
            label: const Text('إضافة إضافة'),
          ),
        ),
      ],
    );
  }

  // دالة مساعدة لعرض الصورة سواء من ملف مؤقت (XFile) أو من رابط سيرفر (URL)
  Widget _buildImageWidget(
    String? imageUrl,
    XFile? pickedFile, {
    double height = 160,
    double width = double.infinity,
  }) {
    if (pickedFile != null) {
      // حالة الصورة المحددة حديثاً (باستخدام Memory)
      return FutureBuilder<Uint8List>(
        future: pickedFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              height: height,
              width: width,
              fit: BoxFit.cover,
            );
          }
          return SizedBox(
            height: height,
            width: width,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      // حالة الصورة المرفوعة سابقاً (من الرابط)
      return Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    } else {
      // لا توجد صورة
      return SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: Icon(Icons.image, size: 40, color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildAddItemTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCard(
              title: 'البيانات الأساسية',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصنف',
                      prefixIcon: Icon(Icons.note_alt),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'اكتب اسم الصنف'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'وصف مختصر',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'السعر الأساسي',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (_sizes.isEmpty &&
                                  (v == null || v.trim().isEmpty))
                              ? 'حط سعر أو أضف أحجام'
                              : null,
                          enabled: _sizes
                              .isEmpty, // إذا فيه أحجام، مفيش داعي لسعر أساسي
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _sortController,
                          decoration: const InputDecoration(
                            labelText: 'ترتيب',
                            prefixIcon: Icon(Icons.format_list_numbered),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('categories')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const Text('خطأ في جلب الاقسام');
                      }

                      if (!snap.hasData) return const LinearProgressIndicator();
                      final docs = snap.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: _selectedCategoryId?.isNotEmpty == true
                            ? _selectedCategoryId
                            : null, // نستخدم null هنا بدلاً من '' عشان Dropdown
                        decoration: const InputDecoration(
                          labelText: 'القسم',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null, // نستخدم null هنا بدلاً من ''
                            child: Text('اختار قسم'),
                          ),
                          ...docs.map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d['name'] ?? ''),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'اختر قسم' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('التوفر'),
                      const SizedBox(width: 8),
                      Switch(
                        value: _available,
                        onChanged: (v) => setState(() => _available = v),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('اختار صورة'),
                      ),
                    ],
                  ),
                  // استخدام الـ Widget المعدّل للعرض
                  if (_pickedXFile != null || _uploadedImageUrl != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(_uploadedImageUrl, _pickedXFile),
                    ),
                    const SizedBox(height: 8),
                    // شريط حالة الرفع
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isLoading
                                ? 'يتم رفع الصورة...'
                                : (_uploadedImageUrl == null
                                      ? 'لم يتم رفع الصورة. اختر صورة جديدة.'
                                      : 'الصورة مُرفوعة بنجاح.'),
                          ),
                        ),
                        // نُظهر زر الرفع فقط لو فشل الرفع الأول
                        if (!_isLoading &&
                            _pickedXFile != null &&
                            _uploadedImageUrl == null)
                          ElevatedButton(
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              // 🔴 تم تغيير الاستدعاء لـ XFile
                              final url = await _uploadToImageKit(
                                _pickedXFile!,
                              );
                              setState(() => _isLoading = false);
                              if (url != null) {
                                if (!mounted) return;
                                setState(() => _uploadedImageUrl = url);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم رفع الصورة'),
                                  ),
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('فشل رفع الصورة'),
                                  ),
                                );
                              }
                            },
                            child: const Text('إعادة رفع الصورة'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _buildCard(title: 'الأحجام', child: _buildSizesEditor()),
            _buildCard(title: 'الإضافات', child: _buildAddonsEditor()),
            _buildCard(
              title: 'معاينة سريعة',
              child: Column(
                children: [
                  ListTile(
                    // استخدام الـ Widget المعدّل للعرض في المعاينة
                    leading:
                        _pickedXFile != null ||
                            (_uploadedImageUrl != null &&
                                _uploadedImageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImageWidget(
                              _uploadedImageUrl,
                              _pickedXFile,
                              height: 56,
                              width: 56,
                            ),
                          )
                        : const CircleAvatar(child: Icon(Icons.fastfood)),
                    title: Text(
                      _nameController.text.isEmpty
                          ? 'اسم الصنف'
                          : _nameController.text,
                    ),
                    subtitle: Text(
                      _descController.text.isEmpty
                          ? 'وصف الصنف'
                          : _descController.text,
                    ),
                    trailing: Text(
                      '${_sizes.isNotEmpty ? _sizes.first['price'] : (_priceController.text.isEmpty ? '0' : _priceController.text)} EGP',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_sizes.isNotEmpty)
                        ..._sizes.map(
                          (s) =>
                              Chip(label: Text('${s['name']} - ${s['price']}')),
                        ),
                      if (_addons.isNotEmpty)
                        ..._addons.map(
                          (a) =>
                              Chip(label: Text('${a['name']} +${a['price']}')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  _isLoading ||
                      (_uploadedImageUrl == null && _pickedXFile != null)
                  ? null
                  : () => _saveItem(editingItem: editingItem),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(editingItem == null ? 'حفظ الصنف' : 'تحديث الصنف'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final available = data['available'] ?? true;
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: data['image'] != null && data['image'] != ''
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  data['image'],
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            : const CircleAvatar(child: Icon(Icons.fastfood)),
        title: Text(data['name'] ?? ''),
        subtitle: Text(
          '${data['description'] ?? ''}\n${data['price'] ?? 0} EGP',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') _editItem(doc);
            if (value == 'delete') {
              await _firestore.collection('store_items').doc(doc.id).delete();
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم حذف الصنف')));
            }
            if (value == 'toggle') {
              await _firestore.collection('store_items').doc(doc.id).update({
                'available': !available,
              });
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    !available ? 'تم تشغيل الصنف' : 'تم إيقاف الصنف',
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(available ? 'إيقاف' : 'تشغيل'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'بحث باسم الصنف',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('store_items')
                .where('store_id', isEqualTo: widget.storeId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('حدث خطأ'));
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs =
                  snap.data!.docs.where((d) {
                    final name = (d['name'] ?? '').toString().toLowerCase();
                    return name.contains(searchQuery);
                  }).toList()..sort((a, b) {
                    final aTime = a['created_at'] ?? Timestamp(0, 0);
                    final bTime = b['created_at'] ?? Timestamp(0, 0);
                    return bTime.compareTo(aTime);
                  });

              if (docs.isEmpty) {
                return const Center(child: Text('لا توجد أصناف'));
              } else {
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildItemCard(docs[index]),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة وتعديل الأصناف'),
        backgroundColor: const Color(0xFFA8E6CF),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFA8E6CF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Colors.green[800], // اللون للتاب المحدد
                unselectedLabelColor: Colors.grey, // اللون للتاب غير المحدد
                indicatorColor: Colors.green[700], // خط تحت التاب المحدد
                tabs: const [
                  Tab(text: 'أضف صنف', icon: Icon(Icons.add_box, size: 26)),
                  Tab(
                    text: 'الأصناف المضافة',
                    icon: Icon(Icons.list, size: 26),
                  ),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildAddItemTab(), _buildItemsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
