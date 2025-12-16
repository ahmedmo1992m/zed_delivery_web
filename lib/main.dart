import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'order_page.dart';
import 'pages/marketplace_page.dart';
import 'pages/client_auth_screen.dart';
import 'services/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 💡 تم الإضافة

// **********************************************
// 💡 الإضافات الجديدة لـ Local Notifications
// **********************************************

// تهيئة الـ Plugin الخاص بـ Local Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// تعريف القناة (Channel) لإشعارات الأندرويد
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id: مهم إنك تستخدمه في الـ Backend لما تبعت الإشعار
  'إشعارات الطلبات الهامة', // title
  description: 'القناة الخاصة بالإشعارات المهمة للطلبات الجديدة في تطبيق زد.',
  importance: Importance.max,
);

// **********************************************
// **********************************************

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // **********************************************
  // 💡 إضافة: تهيئة Local Notifications والقناة على Android
  // **********************************************

  // 1. إنشاء القناة على الأندرويد
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // 2. تهيئة إعدادات Local Notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // أيقونة التطبيق

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    // iOS: أضف هنا: ios: DarwinInitializationSettings(), لو بتدعم iOS
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // **********************************************
  // **********************************************

  Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ); // تأكيد تهيئة Firebase
    // هنا ممكن تعمل أي حاجة مع الرسالة، زي طباعة بياناتها
    debugPrint(
      'رسالة في الخلفية: ${message.messageId}',
    ); // تم تعديل ('...') لـ debugPrint
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(create: (_) => CartProvider(), child: const MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _initialPage = const SplashScreen();

  String? storeId;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _previousOrdersCount = 0;
  StreamSubscription<QuerySnapshot>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // طلب إذن الإشعارات (خصوصًا على iOS)
    messaging.requestPermission(alert: true, badge: true, sound: true);

    // استقبال الرسائل أثناء تشغيل التطبيق (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // 💡 التعديل هنا: استخدام Local Notifications لعرض الإشعار بدلاً من SnackBar
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        // عرض الإشعار باستخدام Local Notifications
        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android
                    .smallIcon, // ممكن تستخدم أي أيقونة موجودة في drawable
              ),
            ),
            // payload: ممكن تبعت هنا البيانات الإضافية لو حبيت تعمل إجراء عند الضغط على الإشعار
          );
        }

        // تشغيل الصوت اللي حضرتك مجهزه (بدون تغيير)
        _playOrderSound();

        // ❌ تم حذف ScaffoldMessenger.of().showSnackBar() لمنع ظهورها مع الإشعار الجديد
      }
    });
  }

  void _setupStoreOrdersListener(String currentStoreId) {
    _orderSubscription?.cancel();

    _orderSubscription = FirebaseFirestore.instance
        .collection('stores')
        .doc(currentStoreId)
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          final newOrdersCount = snapshot.docs.length;
          if (newOrdersCount > _previousOrdersCount) {
            _playOrderSound();
          }
          _previousOrdersCount = newOrdersCount;
        });
  }

  Future<void> _playOrderSound() async {
    await _audioPlayer.play(AssetSource('sounds/new_order_sound.mp3'));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _orderSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 1));

    Widget nextPage = const ClientAuthScreen(); // افتراضي جديد

    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType');

      if (userType == 'store') {
        final storedStoreId = prefs.getString('storeId') ?? '';

        // ✅ التعديل هنا: هنضيف شرط عشان نتأكد إن الـ ID مش فاضي قبل ما نعمل أي حاجة
        if (storedStoreId.isNotEmpty) {
          final storeName = prefs.getString('storeName') ?? 'المحل';
          final address = prefs.getString('address') ?? '';
          final phone = prefs.getString('phone') ?? '';
          final storeRegion = prefs.getString('storeRegion') ?? '';
          final logoUrl =
              prefs.getString('logoUrl') ??
              'https://ik.imagekit.io/daprl5lfp/stores_logos/default_logo.png';
          final lat = prefs.getDouble('lat') ?? 0.0;
          final lng = prefs.getDouble('lng') ?? 0.0;
          final averageRating = prefs.getDouble('averageRating') ?? 0.0;
          final createdAt = prefs.getString('createdAt') ?? '';
          final isOpen = prefs.getBool('isOpen') ?? false;
          final totalRating = prefs.getInt('totalRating') ?? 0;

          nextPage = OrderPage(
            storeId: storedStoreId,
            storeName: storeName,
            address: address,
            phone: phone,
            storeRegion: storeRegion,
            lat: lat,
            lng: lng,
            averageRating: averageRating,
            createdAt: createdAt,
            isOpen: isOpen,
            logoUrl: logoUrl,
            totalRating: totalRating.toDouble(),
            isGuest: false,
          );

          _setupStoreOrdersListener(storedStoreId);
          FirebaseMessaging.instance.getToken().then((token) {
            if (token != null) {
              // 💡 ظهور التوكن هنا في الـ Terminal تأكيد على أن google-services.json مربوط بنجاح
              debugPrint('FCM Token for Store $storedStoreId: $token');
              FirebaseFirestore.instance
                  .collection('stores')
                  .doc(storedStoreId)
                  .update({'fcmToken': token});
            }
          });

          // لمتابعة أي تحديث للـ token
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
            FirebaseFirestore.instance
                .collection('stores')
                .doc(storedStoreId)
                .update({'fcmToken': newToken});
          });
        }
      } else if (userType == 'client') {
        final user = FirebaseAuth.instance.currentUser;
        nextPage = (user != null)
            ? const MarketplacePage()
            : const ClientAuthScreen();
      }
    } catch (e, st) {
      debugPrint('Error in _checkLoginStatus: $e\n$st');
    }

    if (!mounted) return;
    setState(() {
      _initialPage = nextPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'زد',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Cairo',
      ),
      home: _initialPage,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFFFF3B30),
      end: Colors.white,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) => Scaffold(
        body: Container(
          color: _colorAnimation.value,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ZED',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 14, 5, 0),
                  ),
                ),
                SizedBox(height: 1), // مسافة بين الكلمتين
                Text(
                  'Delivery',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: Color.fromARGB(255, 14, 5, 0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
