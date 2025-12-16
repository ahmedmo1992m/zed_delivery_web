// ignore_for_file: use_build_context_synchronously
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart'; // مهم للـ combineLatest2 في العداد
import 'package:url_launcher/url_launcher.dart'; // لإجراء المكالمات
import 'privacy_policy_page.dart';

import 'mandoob_login_page.dart';
import 'agent_wallet_screen.dart';
import 'mandoob_profile_page.dart';
import 'in_delivery_orders_page.dart';
import 'completed_orders_page.dart';

class MandoobHomePage extends StatefulWidget {
  final String agentName;
  final String agentPhone;
  final void Function() onOrderDelivered;
  final void Function(bool status)? onStatusToggle; // ← أضف هذا
  final VoidCallback onLogout;
  final bool hasActiveOrder;

  const MandoobHomePage({
    super.key,
    required this.agentName,
    required this.onOrderDelivered,
    required this.agentPhone,
    this.onStatusToggle, // ← أضف هذا
    required this.onLogout,
    required this.hasActiveOrder,
  });

  @override
  State<MandoobHomePage> createState() => _MandoobHomePageState();
}

class _MandoobHomePageState extends State<MandoobHomePage> {
  final Logger _logger = Logger();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationUpdateTimer;
  String _locationStatusMessage = 'جاري التحقق من حالة الموقع...';

  Map<String, dynamic>? _agentData;
  StreamSubscription<DocumentSnapshot>? _agentDataSubscription;

  int _inDeliveryOrdersCount = 0;
  StreamSubscription<int>?
  _inDeliveryOrdersSubscription; // تغيرت نوع الـ Stream

  @override
  void initState() {
    super.initState();

    _listenToAgentData();
    _startLocationTracking();
    _startPeriodicLocationUpdate();
    _saveRiderToken();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setOnlineIfLoggedIn();
    });

    _listenToInDeliveryOrders();
  }

  Future<void> _setOnlineIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      _updateAgentOnlineStatus(true);
    }
  }

  Future<void> _saveRiderToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('agents')
            .doc(widget.agentPhone)
            .update({'fcmToken': token});
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('agents')
            .doc(widget.agentPhone)
            .update({'fcmToken': newToken});
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  @override
  void dispose() {
    _agentDataSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _inDeliveryOrdersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateAgentOnlineStatus(bool isOnline) async {
    try {
      Map<String, dynamic> updateData = {'isOnline': isOnline};

      if (!isOnline) {
        // لو بيعمل أوفلاين/لوج أوت: بنمسح التوكن
        updateData['fcmToken'] = FieldValue.delete();
        // ممكن نحط isOnline: false تاني هنا عشان الـ Firestore يقراها صح
        updateData['isOnline'] = false;
      } else {
        // لو بيعمل أونلاين: بنتأكد إن التوكن موجود أو نجيبه
        String? currentToken = await FirebaseMessaging.instance.getToken();
        if (currentToken != null) {
          updateData['fcmToken'] = currentToken;
        }

        // 💡 إضافة الحقول دي بقيمة null كقيمة مبدئية لو مش موجودة،
        // أو هتفضل بقيمتها الحالية لو موجودة بسبب merge: true
        updateData['latitude'] = null;
        updateData['longitude'] = null;
        // دي عشان نضمن إن الـ Firestore يعرف إن في حقل اسمه latitude/longitude
      }

      // ⭐️ هذا هو السطر البديل الصحيح
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentPhone)
          .set(updateData, SetOptions(merge: true)); // 👈 استخدم هذا السطر فقط

      _logger.i(
        'Agent ${widget.agentPhone} online status updated to Firestore: $isOnline',
      );

      // تحديث أي مكان مرتبط بحالة المندوب
      widget.onStatusToggle?.call(isOnline);
    } catch (e) {
      _logger.e('Error updating agent online status: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    setState(() {
      _locationStatusMessage = 'جاري التحقق من خدمة الموقع...';
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'خدمة الموقع غير مفعلة. الرجاء تفعيلها للمتابعة.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _locationStatusMessage = 'خدمة الموقع غير مفعلة';
      });
      return;
    }

    setState(() {
      _locationStatusMessage = 'جاري طلب إذن الموقع...';
    });
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم رفض إذن الموقع. لا يمكن تتبع موقعك.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _locationStatusMessage = 'تم رفض إذن الموقع';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.w(
        'Location permission permanently denied for agent ${widget.agentPhone}.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'أذونات الموقع مرفوضة بشكل دائم. لتفعيل التتبع، افتح الإعدادات.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 7),
          action: SnackBarAction(
            label: 'فتح الإعدادات',
            textColor: Colors.white,
            onPressed: () {
              Geolocator.openAppSettings();
            },
          ),
        ),
      );
      setState(() {
        _locationStatusMessage = 'إذن الموقع مرفوض بشكل دائم';
      });
      return;
    }

    setState(() {
      _locationStatusMessage = 'الموقع نشط: جاري جلب الإحداثيات...';
    });
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (Position position) {
            setState(() {
              _currentPosition = position;
              _locationStatusMessage =
                  'الموقع نشط: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
            });
            _updateAgentLocationInFirestore(position);
          },
          onError: (e) {
            _logger.e(
              'Error in location stream for agent ${widget.agentPhone}: $e',
            );
            if (mounted) {
              setState(() {
                _locationStatusMessage = 'خطأ في تتبع الموقع: $e';
              });
            }
          },
        );
  }
  // ... الكود الأصلي للدالة

  Future<void> _updateAgentLocationInFirestore(Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentPhone)
          // 💡 التعديل هنا: استخدام set مع merge: true
          .set(
            {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'lastLocationUpdateAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          ); // 💡 وده بيضمن إنشاء المستند لو مش موجود وتحديثه لو موجود
    } catch (e) {
      _logger.e(
        'Error updating agent location in Firestore for ${widget.agentPhone}: $e',
      );
      if (mounted) {
        setState(() {
          _locationStatusMessage = 'خطأ في تحديث الموقع على السيرفر: $e';
        });
      }
    }
  }

  void _startPeriodicLocationUpdate() {
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      if (_currentPosition != null) {
        _updateAgentLocationInFirestore(_currentPosition!);
      } else {
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          setState(() {
            _currentPosition = position;
            _locationStatusMessage =
                'الموقع نشط: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          });
          _updateAgentLocationInFirestore(position);
        } catch (e) {
          _logger.e(
            'Error getting current position for periodic update for ${widget.agentPhone}: $e',
          );
          if (mounted) {
            setState(() {
              _locationStatusMessage = 'خطأ في جلب الموقع الدوري: $e';
            });
          }
        }
      }
    });
  }

  void _listenToAgentData() {
    _agentDataSubscription = FirebaseFirestore.instance
        .collection('agents')
        .doc(widget.agentPhone)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              setState(() {
                _agentData = snapshot.data() as Map<String, dynamic>;
              });
              _checkAgentStatusAndDues();
            }
          },
          onError: (error) {
            _logger.e(
              'Error listening to agent data for ${widget.agentPhone}: $error',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('خطأ في تحميل بيانات المندوب: $error')),
              );
            }
          },
        );
  }

  void _listenToInDeliveryOrders() {
    final storeOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'accepted')
        .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
        .snapshots();

    final clientOrdersStream = FirebaseFirestore.instance
        .collection('client_orders')
        .where('status', isEqualTo: 'accepted')
        .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
        .snapshots();

    _inDeliveryOrdersSubscription =
        Rx.combineLatest2(storeOrdersStream, clientOrdersStream, (
          QuerySnapshot storeSnap,
          QuerySnapshot clientSnap,
        ) {
          return storeSnap.docs.length + clientSnap.docs.length;
        }).listen(
          (value) async {
            setState(() {
              _inDeliveryOrdersCount = value;
            });

            try {
              // تحديث الحقل داخل agents حسب agentPhone
              final snapshot = await FirebaseFirestore.instance
                  .collection('agents')
                  .where('agentPhone', isEqualTo: widget.agentPhone)
                  .limit(1)
                  .get();

              if (snapshot.docs.isNotEmpty) {
                final bool hasActiveOrders = value > 0;
                final String newStatus = hasActiveOrders
                    ? 'delivering'
                    : 'idle'; // نحدد الحالة الجديدة

                await snapshot.docs.first.reference.update({
                  'active_orders_count': value,
                  // 💡 التعديل: تحديث حقلين الحالة كمان
                  'hasActiveOrder': hasActiveOrders,
                  'status':
                      newStatus, // لو في أوردرات active_orders_count > 0 تبقى delivering
                });
              }
            } catch (e) {
              _logger.e('Error updating active_orders_count: $e');
            }
          },
          onError: (error) {
            _logger.e('Error listening to in-delivery orders count: $error');
          },
        );
  }

  void _checkAgentStatusAndDues() {
    if (_agentData == null) return;

    bool isActive = _agentData!['isActive'] ?? true;
    double currentDues = (_agentData!['currentDues'] is num)
        ? _agentData!['currentDues'].toDouble()
        : 0.0;
    double duesLimit = (_agentData!['duesLimit'] is num)
        ? _agentData!['duesLimit'].toDouble()
        : 500.0;

    if (!isActive) {
      _logout(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إيقاف حسابك. الرجاء التواصل مع الإدارة.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } else if (currentDues >= duesLimit) {
      FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentPhone)
          .update({'isActive': false})
          .then((_) {
            _logout(force: true);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'لقد وصلت للحد الأقصى للمستحقات ($duesLimit جنيه). تم إيقاف حسابك.',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          })
          .catchError((e) {
            _logger.e('Error updating agent isActive status: $e');
          });
    } else if (currentDues >= (duesLimit * 0.8)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تنبيه: لقد قاربت الحد الأقصى للمستحقات ($duesLimit جنيه). يرجى السداد قريباً.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _logout({bool force = false}) async {
    bool? confirmLogout = force;

    if (!force) {
      confirmLogout =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('تأكيد تسجيل الخروج'),
              content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (confirmLogout == true) {
      // 👈🏼 نقلنا استخراج الـ ID هنا عشان نستخدمه في الفحص والتحديث
      final prefs = await SharedPreferences.getInstance();
      final agentId = prefs.getString('agentId');

      // 💡💡 فحص الأوردرات النشطة باستخدام Firebase (الكود الجديد) 💡💡
      if (agentId != null) {
        final DocumentSnapshot agentDoc = await FirebaseFirestore.instance
            .collection('agents')
            .doc(agentId)
            .get();

        final int activeOrdersCount =
            (agentDoc.data() as Map<String, dynamic>)['active_orders_count'] ??
            0;

        if (activeOrdersCount > 0) {
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('⚠️ لا يمكن تسجيل الخروج'),
              content: Text(
                'لا يمكن تسجيل الخروج بوجود $activeOrdersCount أوردر قيد التسليم. يرجى إنهاء تسليم الطلبات أولاً.', // رسالة مخصصة بالعدد
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('موافق'),
                ),
              ],
            ),
          );
          return; // 🛑 نوقف تنفيذ الدالة هنا
        }
      }
      // --------------------------------------------------------

      // ⭐⭐⭐ الكود بتاع تحديث حالة الأوفلاين بيبدأ هنا ⭐⭐⭐
      if (agentId != null) {
        try {
          // 1. تحديث حالة المندوب إلى "أوفلاين" في Firestore مباشرةً
          await FirebaseFirestore.instance
              .collection('agents')
              .doc(agentId)
              .update({'isOnline': false, 'fcmToken': null});
          debugPrint('✅ Agent status updated to offline in Firestore.');
        } catch (e) {
          debugPrint(
            '⚠️ Error updating agent status in Firestore on logout: $e',
          );
        }
      }

      _positionStreamSubscription?.cancel();
      _locationUpdateTimer?.cancel();
      _inDeliveryOrdersSubscription?.cancel();

      // مسح SharedPreferences
      await prefs.clear();

      // التنقل للصفحة الرئيسية بدون إمكانية العودة
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MandoobLoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<bool> _updateAgentOrderStateInFirestore({
    required String agentId,
    required String orderId,
    required bool hasActiveOrder,
  }) async {
    try {
      Map<String, dynamic> updateData = {'hasActiveOrder': hasActiveOrder};

      // لو المندوب خد أوردر جديد (hasActiveOrder = true)، بنسجل الـorderId
      if (hasActiveOrder) {
        updateData['activeOrderId'] = orderId;
      } else {
        // لو الأوردر خلص (hasActiveOrder = false)، بنمسح الـorderId
        updateData['activeOrderId'] = FieldValue.delete();
      }

      // ⭐ تحديث مباشر لملف المندوب في Firestore
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(agentId)
          .update(updateData);

      debugPrint(
        '✅ Agent active order state updated in Firestore: $hasActiveOrder',
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ Error updating agent active order state in Firestore: $e');
      return false;
    }
  }

  Future<void> _acceptOrder({
    required String orderId,
    required String collectionName,
    required BuildContext context,
    required Map<String, dynamic> orderData,
  }) async {
    if (_inDeliveryOrdersCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن قبول المزيد من الأوردرات. قم بتسليم الأوردرات قيد التوصيل أولاً (الحد الأقصى 4).',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // جلب أحدث موقع للمندوب قبل قبول الأوردر
    Position? agentCurrentLocation;
    try {
      agentCurrentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      _logger.e('Error getting agent current position: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء جلب موقعك الحالي: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool confirmAccept =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد قبول الأوردر'),
            content: const Text('هل أنت متأكد أنك تريد قبول هذا الأوردر؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'قبول',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmAccept) {
      try {
        // 🎯 حساب الوقت المتوقع للتسليم (45 دقيقة من وقت القبول)
        const int deliveryMinutes = 45;
        final DateTime expectedTime = DateTime.now().add(
          const Duration(minutes: deliveryMinutes),
        );

        final Map<String, dynamic> updateData = {
          'status': 'accepted',
          'assignedAgentPhone': widget.agentPhone,
          'agentId': widget.agentPhone,
          'agentName': widget.agentName,
          'agentPhone': widget.agentPhone,
          'acceptedAt': FieldValue.serverTimestamp(),
          'agentLocationAtAccept_latitude': agentCurrentLocation.latitude,
          'agentLocationAtAccept_longitude': agentCurrentLocation.longitude,
          'expectedDeliveryTime': expectedTime, // 👈 الحقل المطلوب
        };

        final mainOrderRef = FirebaseFirestore.instance
            .collection(collectionName)
            .doc(orderId);

        final storeId =
            orderData['store_id']; // 👈 تأكد الاسم نفسه الموجود في الداتا

        final batch = FirebaseFirestore.instance.batch();
        batch.update(mainOrderRef, updateData);

        if (storeId != null && storeId.toString().isNotEmpty) {
          final storeOrderRef = FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .collection('orders')
              .doc(orderId);

          batch.update(storeOrderRef, updateData);
        }

        await batch.commit();

        // 💡💡 الإضافة المطلوبة: النداء على دالة تحديث حالة الأوردر النشط 💡💡
        final bool statusUpdated = await _updateAgentOrderStateInFirestore(
          agentId:
              widget.agentPhone, // أو widget.agentId لو بتستخدمه في مكان تاني
          orderId: orderId,
          hasActiveOrder: true,
        );

        if (!statusUpdated) {
          // ممكن هنا تسجل خطأ مهم أو تدي تنبيه للمندوب
          debugPrint('⚠️ فشل في تحديث حالة الأوردر النشط للمندوب في السيرفر!');
        }
        // 💡💡 نهاية الإضافة المطلوبة 💡💡

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم قبول الأوردر بنجاح! سينتقل لصفحة "قيد التوصيل".',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _logger.e('Error accepting order $orderId from $collectionName: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء قبول الأوردر: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Card تصميم خاص بأوردرات المحلات (تم تعديل المحتوى المعروض)
  Widget _buildStoreOrderCard(QueryDocumentSnapshot doc, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final String orderId = doc.id;

    final String storeRegion = data['storeRegion'] ?? 'غير محددة';

    final String customerAddress =
        data['customerAddress'] ?? 'عنوان التسليم غير متوفر';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ' مكان الاستلام: $storeRegion',
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(221, 88, 116, 209),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 10),

            // 3. عرض مكان التسليم بدلاً من التفاصيل والإجمالي
            Text(
              'مكان التسليم: $customerAddress', // 👈 تم إضافة مكان التسليم
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(255, 85, 92, 151),
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(height: 20), // فاصل

            const Divider(),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // خليناها في النص عشان زرار واحد
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptOrder(
                      orderId: orderId,
                      collectionName: 'orders',
                      context: context,
                      orderData: data,
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'قبول الأوردر', // غيرنا النص عشان يبقى أوضح
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(
                        double.infinity,
                        50,
                      ), // عشان يبقى شكله كويس
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Card تصميم خاص بأوردرات العملاء (تم تعديل المحتوى المعروض)
  Widget _buildClientOrderCard(
    QueryDocumentSnapshot doc,
    BuildContext context,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final String orderId = doc.id;

    // معلومات الأوردر اللي هتظهر بس
    final String pickupLocation =
        data['storeAddress'] ??
        'مكان الاستلام غير متوفر'; // كان: pickupLocation

    final String clientAddress =
        data['customerAddress'] ??
        'عنوان التسليم غير متوفر'; // كان: clientAddress
    // final double deliveryPrice = (data['deliveryPrice'] is num)
    // ? data['deliveryPrice'].toDouble()
    // : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مكان الاستلام: $pickupLocation',
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(221, 76, 97, 216),
                fontWeight: FontWeight.bold, // ضفنا الـ bold عشان يبقى واضح
              ),
            ),
            const SizedBox(height: 8),

            // 👈 مكان التسليم (اللي كان عنوان العميل بس غيرنا العنوان)
            Text(
              'مكان التسليم: $clientAddress',
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(
                  255,
                  2,
                  101,
                  150,
                ), // غيرنا اللون عشان يبقى مختلف عن الاستلام
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20), // فاصل
            const SizedBox(height: 8),

            const Divider(),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // خليناها في النص عشان زرار واحد
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptOrder(
                      orderId: orderId,
                      collectionName: 'client_orders',
                      context: context,
                      orderData: data,
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'قبول الأوردر', // غيرنا النص عشان يبقى أوضح
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(
                        double.infinity,
                        50,
                      ), // عشان يبقى شكله كويس
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAgentActive = _agentData?['isActive'] ?? true;

    return WillPopScope(
      onWillPop: () async => false,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'أهلاً بك يا ${widget.agentName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.blue,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Builder(
                builder: (BuildContext builderContext) {
                  return IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      Scaffold.of(builderContext).openEndDrawer();
                    },
                    tooltip: 'القائمة',
                  );
                },
              ),
            ],
          ),
          endDrawer: Drawer(
            width: MediaQuery.of(context).size.width * 0.75,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_pin_circle,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.agentName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.agentPhone,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isAgentActive
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAgentActive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAgentActive ? Icons.check_circle : Icons.cancel,
                          color: isAgentActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isAgentActive
                                ? 'حسابك نشط وجاهز لاستقبال الطلبات.'
                                : 'حسابك غير نشط حالياً. يرجى التواصل مع الإدارة.',
                            style: TextStyle(
                              color: isAgentActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'المحفظة',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AgentWalletScreen(agentPhone: widget.agentPhone),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white70, height: 20),
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.white),
                    title: const Text(
                      'تعديل بياناتي',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MandoobProfilePage(agentId: widget.agentPhone),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white70, height: 20),
                  ListTile(
                    leading: const Icon(Icons.history, color: Colors.white),
                    title: const Text(
                      'الأوردرات المكتملة',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompletedOrdersPage(
                            agentPhone: widget.agentPhone,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.blueGrey, height: 30),

                  // ===== الدعم والمساعدة =====
                  ListTile(
                    leading: const Icon(
                      Icons.support_agent,
                      color: Colors.orange,
                      size: 26,
                    ),
                    title: const Text(
                      'الدعم والمساعدة',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      final phone = '0201556798005';
                      final Uri whatsappUri = Uri.parse('https://wa.me/$phone');

                      if (await canLaunchUrl(whatsappUri)) {
                        await launchUrl(
                          whatsappUri,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لا يمكن فتح واتساب على هذا الجهاز'),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(color: Colors.blueGrey, height: 30),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip, color: Colors.grey),
                    title: const Text(
                      'السياسات والخصوصية',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.blueGrey, height: 30),
                  ListTile(
                    leading: Icon(
                      _locationStatusMessage.contains('نشط')
                          ? Icons.location_on
                          : Icons.location_off,
                      color: _locationStatusMessage.contains('نشط')
                          ? Colors.lightGreenAccent
                          : Colors.orangeAccent,
                    ),
                    title: Text(
                      _locationStatusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color: _locationStatusMessage.contains('نشط')
                            ? Colors.lightGreenAccent
                            : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(color: Colors.white70, height: 20),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white),
                    title: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                  ),
                  const Divider(color: Colors.blueGrey, height: 30),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10,
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            InDeliveryOrdersPage(agentPhone: widget.agentPhone),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.delivery_dining,
                    color: Colors.white,
                    size: 28,
                  ),
                  label: Text(
                    'أوردرات قيد التوصيل ($_inDeliveryOrdersCount)',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 8,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.blue,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.blue,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: 'أوردرات زد'),
                    Tab(text: 'أوردرات توصيل'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('خطأ: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('لا توجد أوردرات محلات معلقة حالياً.'),
                          );
                        }

                        final relevantDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          // تم إزالة التحقق من hiddenOrderIds
                          return data.containsKey('storeName');
                        }).toList();

                        if (relevantDocs.isEmpty) {
                          return const Center(
                            child: Text(
                              'لا توجد أوردرات محلات معلقة لك حالياً.',
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: relevantDocs.length,
                          itemBuilder: (context, index) {
                            return _buildStoreOrderCard(
                              relevantDocs[index],
                              context,
                            );
                          },
                        );
                      },
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('client_orders')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('خطأ: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('لا توجد أوردرات عملاء معلقة حالياً.'),
                          );
                        }

                        final relevantDocs = snapshot.data!.docs;

                        if (relevantDocs.isEmpty) {
                          return const Center(
                            child: Text(
                              'لا توجد أوردرات عملاء معلقة لك حالياً.',
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: relevantDocs.length,
                          itemBuilder: (context, index) {
                            return _buildClientOrderCard(
                              relevantDocs[index],
                              context,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
