import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'marketplace_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ClientAuthScreen extends StatefulWidget {
  const ClientAuthScreen({super.key});

  @override
  State<ClientAuthScreen> createState() => _LoginPageState();
}

class _LoginPageState extends State<ClientAuthScreen> {
  final _formKey = GlobalKey<FormState>();

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.redAccent,
      textColor: Colors.white,
    );
  }

  Future<LatLng?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorToast('❌ خدمة تحديد الموقع (GPS) غير مُفعّلة.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorToast('❌ تم رفض إذن الوصول للموقع.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorToast('❌ تم رفض إذن الوصول للموقع بشكل دائم.');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      _showErrorToast('⚠️ لا يمكن تحديد موقعك.');
      return null;
    }
  }

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showErrorToast('🌐 لا يوجد اتصال بالإنترنت.');
      return false;
    }
    return true;
  }

  Future<void> _signInWithGoogle() async {
    if (!await _checkInternetConnection()) return;

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // 🌐 ويب
        userCredential = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } else {
        // 📱 موبايل
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      final userDoc = FirebaseFirestore.instance
          .collection('clients')
          .doc(userCredential.user!.uid);

      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName ?? 'مستخدم جديد',
          'points': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userType', 'client');
      await prefs.setString('customer_id', userCredential.user!.uid);
      await prefs.setBool('isLoggedIn', true);

      final location = await _getCurrentLocation();
      _navigateToHome(location);
    } catch (e) {
      _showErrorToast('فشل تسجيل الدخول');
    }
  }

  void _navigateToHome(LatLng? location) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MarketplacePage(userLocation: location),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ألوان الهوية
    const Color brandRed = Color(0xFFFF3B30); // اللون الرئيسي
    const Color brandRedLight = Color(0xFFFF6A5E); // درجة أفتح

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            brandRed, // أعلى
            brandRedLight, // منتصف
            Colors.white, // أسفل
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'تسجيل الدخول',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A0000), // تباين مناسب
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  Column(
                    children: const [
                      Text(
                        'أهلاً بك في زد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color.fromARGB(255, 248, 246, 246),
                        ),
                      ),
                      SizedBox(height: 6),
                      Icon(
                        Icons.emoji_emotions_rounded,
                        color: Color.fromARGB(255, 241, 218, 5),
                        size: 46,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    'كل اللي عايزه يوصلك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 12, 3, 3),
                    ),
                  ),

                  const SizedBox(height: 60),

                  Container(
                    height: 65,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: Image.asset('assets/google_logo.png', height: 28),
                      label: const Text(
                        'اضغط هنا للدخول',
                        style: TextStyle(
                          fontSize: 18,
                          color: brandRed, // لون مطابق للهوية
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        side: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
