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
import 'package:shared_preferences/shared_preferences.dart';
import 'order_page.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🟢 تم إضافة مكتبة Firebase Auth
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

// إعدادات ImageKit
class ImageKitConfig {
  static const String publicKey = 'public_DdZaQNVPnIkcdTeeu+GlqFVn1hM=';
  static const String privateKey = 'private_XVb2nRDWt1k6eOf1UB306WjwIoY=';
  static const String uploadUrl =
      'https://upload.imagekit.io/api/v1/files/upload';
  static const String folder = '/stores_logos';
}

// ================== صفحة الدخول (بدون تغيير) ==================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateStoreFcmToken(String storeId) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      final url = Uri.parse(
        'https://us-central1-sapeq-bd456.cloudfunctions.net/updateAgentStatus',
      );
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'agentId': storeId,
          'fcmToken': fcmToken,
          'isOnline': true,
        }),
      );
    } catch (e) {
      ('❌ فشل تحديث FCM Token: $e');
    }
  }

  Future<void> _loginAccount(String phone, String password) async {
    setState(() => _isProcessing = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('phone', isEqualTo: phone)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        // ✅ التعديل هنا: هتحفظ الـ ID ونوع المستخدم في الذاكرة
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userType', 'store');
        await prefs.setString('storeId', doc.id);

        if (!mounted) return;
        await _updateStoreFcmToken(doc.id);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderPage(
              storeId: doc.id,
              storeName: data['storeName'] ?? '',
              address: data['address'] ?? '',
              phone: data['phone'] ?? '',
              storeRegion: data['storeRegion'] ?? '',
              isGuest: false,
              lat: (data['location']?['lat'] ?? 0.0).toDouble(),
              lng: (data['location']?['lng'] ?? 0.0).toDouble(),
              averageRating: (data['averageRating'] ?? 0.0).toDouble(),
              createdAt: data['createdAt']?.toDate().toString() ?? '',
              isOpen: data['isOpen'] ?? true,
              logoUrl: data['logoUrl'] ?? '',
              totalRating: (data['totalRating'] ?? 0.0).toDouble(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ رقم الهاتف أو كلمة السر خاطئة')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ حدث خطأ: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

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
      body: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.indigo.shade50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'تسجيل الدخول',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 55, 5, 190),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(phoneController, 'رقم التليفون', Icons.phone),
            _buildTextField(
              passwordController,
              'كلمة السر',
              Icons.lock,
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => _loginAccount(
                      phoneController.text.trim(),
                      passwordController.text.trim(),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'تسجيل الدخول',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignUpPage()),
              ),
              child: const Text(
                'إنشاء حساب جديد',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.indigo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== صفحة إنشاء الحساب (المُعدَّلة) ==================
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  SignUpPageState createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> {
  final storeNameController = TextEditingController();
  final addressController = TextEditingController();
  final storeRegionController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  // 🟢 متغيرات Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // المستخدم الحالي اللي عمل تسجيل دخول بجوجل

  File? _logoImage;
  String? _uploadedLogoUrl;
  LatLng? _selectedLocation;
  bool _isProcessing = false;
  bool _isUploadingLogo = false;

  @override
  void dispose() {
    storeNameController.dispose();
    addressController.dispose();
    storeRegionController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ================== تسجيل الدخول بجوجل والتحقق من التكرار (جديد) ==================
  // لازم تكون عامل Import للحزمة دي فوق
  // import 'package:google_sign_in/google_sign_in.dart';

  Future<void> _signInWithGoogleAndCheck() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. تهيئة Google Sign-In للموبايل
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // المستخدم ألغى تسجيل الدخول
        setState(() => _isProcessing = false);
        return;
      }

      // 2. الحصول على بيانات التحقق (Auth)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. إنشاء بيانات اعتماد (Credential) لاستخدامها مع Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. تسجيل الدخول/إنشاء المستخدم في Firebase باستخدام بيانات الاعتماد
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // 5. التحقق من تسجيل المحل في Firestore باستخدام الـ UID بتاع جوجل
        final querySnapshot = await FirebaseFirestore.instance
            .collection('stores')
            .where('googleUid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // ✅ المحل مُسجل بالفعل
          if (!mounted) return;
          // نعمل Logout من جوجل ونظهر رسالة ونرجعه لصفحة الدخول
          await _auth.signOut();
          await googleSignIn.signOut(); // مهم: Logout من Google كمان
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ هذا الإيميل مسجل به محل بالفعل! يرجى تسجيل الدخول برقم الهاتف وكلمة السر.',
              ),
            ),
          );
          Navigator.pop(context);
          return;
        } else {
          // ⚠️ أول مرة يسجل: نحفظ بيانات المستخدم وننتقل لخطوة ملء البيانات
          setState(() => _currentUser = user);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ تم التحقق بالجيميل بنجاح! يمكنك الآن إكمال بيانات المحل.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ فشل التحقق بجوجل. تأكد من إعداد Firebase وحزمة google_sign_in: $e',
          ),
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ================== رفع اللوجو (بدون تغيير) ==================
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File compressedLogo = await _compressImage(File(pickedFile.path));
    setState(() => _logoImage = compressedLogo);
    _uploadedLogoUrl = null; // إعادة تعيين الرابط قبل رفع جديد
  }

  Future<void> _uploadLogo() async {
    if (_logoImage == null) return;

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

  // ================== تحديد الموقع (بدون تغيير) ==================
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

    LatLng tempLocation = LatLng(31.0409, 31.3785);
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

    await showDialog(
      context: context,
      builder: (context) {
        LatLng? selectedPoint;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تحديد موقع المحل'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? tempLocation,
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
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
              actions: [
                TextButton(
                  onPressed: () {
                    if (selectedPoint != null) {
                      _selectedLocation = selectedPoint;
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('تأكيد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================== إنشاء الحساب (المُعدَّل) ==================
  Future<void> _createAccount() async {
    // ⚠️ التحقق من خطوة الجيميل أولاً
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ يجب التحقق من الهوية أولاً باستخدام الجيميل.'),
        ),
      );
      return;
    }

    final storeName = storeNameController.text.trim();
    final address = addressController.text.trim();
    final storeRegion = storeRegionController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (storeName.isEmpty ||
        address.isEmpty ||
        storeRegion.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ الرجاء إدخال كل البيانات المطلوبة')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. فحص رقم التليفون (زي ما هو)
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

      // 2. إنشاء الحساب (باستخدام add() وبإضافة حقل الـ UID)
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
        // 🟢 الحقل الجديد للتحقق فقط (يمنع التكرار بالجيميل)
        'googleUid': _currentUser!.uid,
        'authEmail': _currentUser!.email,

        'averageRating': 0.0,
        'ratingsCount': 0,
        'totalRating': 0.0,
        'isOpen': true,
        'profitPercentage': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ تم إنشاء الحساب بنجاح!')));

      // ⚠️ نعمل Logout من جوجل بعد التسجيل عشان ما يعملش مشاكل في حالة الدخول العادي
      await _auth.signOut();

      Navigator.pop(context); // العودة لصفحة الدخول
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إنشاء الحساب: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

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
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        backgroundColor: Colors.indigo,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🟢 خطوة 1: التحقق بالجيميل (تظهر دائمًا في البداية)
            if (_currentUser == null)
              Column(
                children: [
                  const Text(
                    'لتجنب تكرار تسجيل المحلات، يجب التحقق من هويتك أولاً باستخدام جيميل واحد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _isProcessing
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _signInWithGoogleAndCheck,
                          icon: const Icon(Icons.email, color: Colors.white),
                          label: const Text(
                            'التحقق من الهوية باستخدام الجيميل',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                ],
              )
            // 🟢 خطوة 2: ملء البيانات (تظهر بعد التحقق بالجيميل)
            else
              Column(
                children: [
                  Text(
                    'جارٍ إكمال بيانات المحل لـ: ${_currentUser!.email}',
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // حقول البيانات زي ما هي
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
                  _buildTextField(storeRegionController, 'المنطقة', Icons.map),
                  _buildTextField(phoneController, 'رقم التليفون', Icons.phone),
                  _buildTextField(
                    passwordController,
                    'كلمة السر',
                    Icons.lock,
                    obscureText: true,
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pickLogo,
                        child: const Text('اختيار اللوجو'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: (_logoImage != null && !_isUploadingLogo)
                            ? _uploadLogo
                            : null,
                        child: _isUploadingLogo
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('رفع اللوجو'),
                      ),
                      const SizedBox(width: 10),
                      _uploadedLogoUrl != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.upload, color: Colors.grey),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pickLocation,
                        child: const Text('تحديد الموقع'),
                      ),
                      const SizedBox(width: 10),
                      _selectedLocation != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.location_pin, color: Colors.grey),
                    ],
                  ),

                  const SizedBox(height: 20),
                  _isProcessing
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _createAccount,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text('إنشاء الحساب'),
                        ),
                ],
              ),

            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'رجوع لصفحة الدخول',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
