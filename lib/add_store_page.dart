// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

// إحداثيات مركز مدينة المنصورة
const double centerLat = 31.0409;
const double centerLng = 31.3785;

// دالة لحساب المسافة بين نقطتين بالكيلومتر (Haversine)
double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  const double R = 6371; // نصف قطر الأرض بالكيلومتر
  final double dLat = (lat2 - lat1) * (3.141592653589793 / 180);
  final double dLng = (lng2 - lng1) * (3.141592653589793 / 180);
  final double a =
      (sin(dLat / 2) * sin(dLat / 2)) +
      (cos(lat1 * (3.141592653589793 / 180)) *
          cos(lat2 * (3.141592653589793 / 180)) *
          sin(dLng / 2) *
          sin(dLng / 2));
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

// إعدادات ImageKit
class ImageKitConfig {
  static const String publicKey = 'public_DdZaQNVPnIkcdTeeu+GlqFVn1hM=';
  static const String privateKey = 'private_XVb2nRDWt1k6eOf1UB306WjwIoY=';
  static const String uploadUrl =
      'https://upload.imagekit.io/api/v1/files/upload';
  static const String folder = '/stores_logos';
}

// ================== صفحة إنشاء الحساب ==================
class AddStorePage extends StatefulWidget {
  const AddStorePage({super.key});

  @override
  AddStorePageState createState() => AddStorePageState();
}

class AddStorePageState extends State<AddStorePage> {
  final storeNameController = TextEditingController();
  final addressController = TextEditingController();
  final storeRegionController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  File? _logoImage;
  String? _uploadedLogoUrl;
  LatLng? _selectedLocation;
  bool _isProcessing = false;
  bool _isUploadingLogo = false; // هنستخدمها كـ Loading Indicator

  @override
  void dispose() {
    storeNameController.dispose();
    addressController.dispose();
    storeRegionController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ================== رفع اللوجو (التعديل الجديد) ==================
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File compressedLogo = await _compressImage(File(pickedFile.path));

    // 🟢 1. تحديث الـ State بالصورة الجديدة عشان تظهر في الـ Preview
    setState(() {
      _logoImage = compressedLogo;
      _uploadedLogoUrl = null; // بنصفر الـ URL لحد ما يتم الرفع بنجاح
    });

    // 🟢 2. استدعاء دالة الرفع مباشرة بعد اختيار الصورة
    await _uploadLogo();
  }

  Future<void> _uploadLogo() async {
    if (_logoImage == null) return;

    // 🟢 3. بنعمل تحديث للـ State عشان يظهر شريط التحميل (CircularProgressIndicator)
    setState(() => _isUploadingLogo = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ImageKitConfig.uploadUrl),
      );
      String basicAuth =
          'Basic ${base64Encode(utf8.encode('${ImageKitConfig.privateKey}:'))}';
      request.headers['Authorization'] = basicAuth;
      request.fields['fileName'] =
          'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      request.fields['folder'] = ImageKitConfig.folder;
      request.files.add(
        await http.MultipartFile.fromPath('file', _logoImage!.path),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (response.statusCode == 200) {
        setState(() => _uploadedLogoUrl = data['url']);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ تم رفع اللوجو بنجاح!')));
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
      // 🟢 4. بنوقف شريط التحميل في كل الأحوال
      setState(() => _isUploadingLogo = false);
    }
  }

  Future<File> _compressImage(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, lastIndex);
    final outPath = "${splitted}_out${filePath.substring(lastIndex)}";
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 70,
      rotate: 0,
      keepExif: false,
    );

    if (result != null) {
      return File(result.path);
    } else {
      return file;
    }
  }

  // ================== تحديد الموقع (مُعدَّل) ==================
  Future<void> _pickLocation() async {
    setState(() => _isProcessing = true);
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض صلاحية الوصول للموقع.')),
      );
      return;
    }

    LatLng tempLocation = LatLng(centerLat, centerLng);
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      tempLocation = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}
    setState(() => _isProcessing = false);

    // استقبال القيمة اللي هترجع من الـ Dialog
    final selectedPoint = await showDialog<LatLng>(
      context: context,
      builder: (context) {
        LatLng? selectedPoint;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تحديد موقع المحل'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedLocation ?? tempLocation,
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) {
                        // 🟢 تم إلغاء كل فحص المسافة، نحدّد النقطة على طول
                        setDialogState(() => selectedPoint = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.app.store',
                      ),
                      if (selectedPoint != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: selectedPoint!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (selectedPoint != null) {
                      // 🟢 بيخرج من الـ Dialog ويرجع النقطة اللي تم اختيارها
                      Navigator.pop(context, selectedPoint);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('تأكيد'),
                ),
              ],
            );
          },
        );
      },
    );

    // 🟢 بيحدث الـ State لما النقطة بترجع من الـ Dialog
    if (selectedPoint != null) {
      setState(() {
        _selectedLocation = selectedPoint;
      });
    }
  }

  // ================== إنشاء الحساب ==================
  Future<void> _createAccount() async {
    final storeName = storeNameController.text.trim();
    final address = addressController.text.trim();
    final storeRegion = storeRegionController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (storeName.isEmpty ||
        address.isEmpty ||
        storeRegion.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ الرجاء إدخال كل البيانات المطلوبة')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ الرجاء تحديد موقع المحل على الخريطة')),
      );
      return;
    }
    // 🔴 الشرط الجديد: لازم يكون فيه رابط للوجو تم رفعه
    if (_uploadedLogoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ الرجاء اختيار لوجو المحل والانتظار حتى يتم رفعه'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // هنا بنفحص إذا كان رقم التليفون موجود قبل كده
      final existingPhone = await FirebaseFirestore.instance
          .collection('stores')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (existingPhone.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ رقم التليفون هذا مستخدم بالفعل')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      // لو الرقم مش موجود، نكمل عملية إنشاء الحساب
      await FirebaseFirestore.instance.collection('stores').add({
        'storeName': storeName,
        'address': address,
        'storeRegion': storeRegion,
        'phone': phone,
        'password': password,
        'logoUrl': _uploadedLogoUrl,
        'location': {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        },
        'averageRating': 0.0,
        'ratingsCount': 0,
        'totalRating': 0.0,
        'isOpen': true,
        'profitPercentage': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إضافة المحل بنجاح! جاهز لإضافة محل جديد.'),
        ),
      );

      // تنظيف الـ Text Fields والـ State عشان إضافة محل تاني
      storeNameController.clear();
      addressController.clear();
      storeRegionController.clear();
      phoneController.clear();
      passwordController.clear();

      // تنظيف حالة الصورة والموقع
      setState(() {
        _logoImage = null;
        _uploadedLogoUrl = null;
        _selectedLocation = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إنشاء الحساب: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 🟢 تعديل الـ Widget عشان يستخدم تصميم الـ Card القديم (عشان تبقى حقول موحدة)
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            prefixIcon: Icon(icon, color: Colors.indigo),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔴 الخلفية متدرجة من الأحمر للأبيض
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE57373), // لون أحمر فاتح (مثلاً)
              Colors.white,
            ],
            stops: [0.0, 0.4], // التدرج يبدأ من الأحمر وينتهي للأبيض عند 40%
          ),
        ),
        child: Column(
          children: [
            // 🔴 الـ AppBar بقى جزء من الـ Body عشان نطبق التدرج
            SafeArea(
              child: SizedBox(
                height: kToolbarHeight,
                child: AppBar(
                  title: const Text(
                    'إنشاء محل جديد',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        kToolbarHeight -
                        40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        storeNameController,
                        'اسم المحل',
                        Icons.store,
                      ),
                      _buildTextField(
                        addressController,
                        'العنوان',
                        Icons.location_on,
                      ),
                      _buildTextField(
                        storeRegionController,
                        'المنطقة',
                        Icons.map,
                      ),
                      _buildTextField(
                        phoneController,
                        'رقم التليفون',
                        Icons.phone,
                      ),
                      _buildTextField(
                        passwordController,
                        'كلمة السر',
                        Icons.lock,
                        obscureText: true,
                      ),
                      const SizedBox(height: 10),

                      // 🖼️ حقل لوجو المحل بالشكل الجديد (المعدل)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            // ⬅️ هذا الـ Column الرئيسي بتاع الـ Card
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'لوجو المحل (صورة)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),

                              // 📌 عرض الصورة اللي تم اختيارها
                              if (_logoImage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _logoImage!,
                                          fit: BoxFit.cover,
                                          width: 80,
                                          height: 80,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        // 👈 استخدم Expanded عشان النص ياخد المساحة الباقية
                                        child: Text(
                                          _isUploadingLogo
                                              ? '⏳ جاري الرفع...'
                                              : (_uploadedLogoUrl != null
                                                    ? '✅ تم الرفع بنجاح'
                                                    : '❌ فشل الرفع'),
                                          style: TextStyle(
                                            color: _isUploadingLogo
                                                ? Colors.orange.shade700
                                                : (_uploadedLogoUrl != null
                                                      ? Colors.green
                                                      : Colors.red),
                                            fontWeight: FontWeight.bold,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // 🟢 الجزء المُعدَّل: هنشيل زرار "رفع" وهنخلي زرار "اختيار اللوجو" هو الوحيد
                              Row(
                                children: [
                                  // زرار اختيار اللوجو
                                  OutlinedButton.icon(
                                    onPressed:
                                        _pickLogo, // 👈 لما يدوس عليه هيختار ويرفع فوراً
                                    icon: const Icon(Icons.image),
                                    label: Text(
                                      _isUploadingLogo
                                          ? 'جاري الرفع...'
                                          : 'اختيار اللوجو',
                                    ),
                                  ),
                                  // 🔴 تم إزالة زرار الرفع هنا بالكامل 🔴
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 📍 حقل تحديد الموقع بالشكل الجديد
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'موقع المحل',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedLocation == null
                                          ? '❌ لم يتم تحديد الموقع'
                                          : '✅ تم التحديد: ${_selectedLocation!.latitude.toStringAsFixed(3)}, ${_selectedLocation!.longitude.toStringAsFixed(3)}',
                                      style: TextStyle(
                                        color: _selectedLocation == null
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickLocation,
                                    icon: Icon(
                                      _selectedLocation == null
                                          ? Icons.map_outlined
                                          : Icons.edit_location_alt,
                                    ),
                                    label: Text(
                                      _selectedLocation == null
                                          ? 'تحديد'
                                          : 'تغيير',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      _isProcessing
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _createAccount,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                foregroundColor: Colors.white,
                                elevation: 5,
                              ),
                              child: const Text(
                                ' إضافة المحل',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      const SizedBox(height: 20),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
