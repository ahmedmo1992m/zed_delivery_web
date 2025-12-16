// ignore_for_file: use_build_context_synchronously
import 'package:photo_view/photo_view.dart' as photo_view;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 💡 لازم تضيفها في pubspec.yaml
import '../services/cart_provider.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:zed/order_tracking_page.dart';

// صفحة السلة الاحترافية مع حساب التوصيل ورسالة تأكيد
class CartPage extends StatefulWidget {
  final double storeLatitude;
  final double storeLongitude;
  final String storeName;
  final String storeAddress;
  final String storeRegion;
  final double profitPercentage;
  final String storePhone; // 👈 لازم تكون موجودة هنا

  const CartPage({
    super.key,
    required this.storeLatitude,
    required this.storeLongitude,
    required this.storeName,
    required this.storeAddress,
    required this.storeRegion,
    required this.profitPercentage,
    required this.storePhone,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  int clientPoints = 0;
  bool usePoints = false;

  ValueNotifier<latlong.LatLng?> selectedLocation =
      ValueNotifier<latlong.LatLng?>(null);
  final _couponController = TextEditingController();
  double couponDiscount = 0.0;
  bool couponApplied = false;

  @override
  void initState() {
    super.initState();
    _loadClientPoints();
  }

  Future<void> _loadClientPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()!.containsKey('points')) {
      setState(() {
        clientPoints = doc['points'];
      });
    }
  }

  @override
  void dispose() {
    selectedLocation.dispose(); // ✨ ما تنساش تنظفه
    super.dispose();
  }

  double? _deliveryFee;

  Future<double> _calculateDeliveryFee(latlong.LatLng? customerLocation) async {
    try {
      // 💡 الحصول على موقع العميل الحالي (المرحلة الأولى في الحساب)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 💡 حساب المسافة الكلية بالكيلومتر
      double distanceInMeters = Geolocator.distanceBetween(
        widget.storeLatitude,
        widget.storeLongitude,
        position.latitude,
        position.longitude,
      );
      double distanceInKm = distanceInMeters / 1000;

      // 🚦 بدء الحساب بناءً على الشرائح الجديدة 🚦
      double fee = 0;
      double remainingDistance = distanceInKm;

      // 1. أول كيلو متر (20 جنيه)
      if (remainingDistance > 0) {
        fee += 20;
        remainingDistance -= 1;
      }

      // 2. من بعد 1 كم لحد 3 كم (بزيادة 2 جنيه لكل كيلو)
      if (remainingDistance > 0) {
        // الحد الأقصى للمرحلة دي 2 كيلو (من 1 كم لحد 3 كم)
        double segmentDistance = remainingDistance.clamp(0, 2);
        // التقريب لأعلى هو اللي بيضمن إن 1.1 كم تتحسب 2 كم إضافي
        fee += segmentDistance.ceil() * 3;
        remainingDistance -= segmentDistance;
      }

      // 3. من بعد 3 كم لحد 7 كم (بزيادة 3 جنيه لكل كيلو)
      if (remainingDistance > 0) {
        double segmentDistance = remainingDistance.clamp(0, 7);
        fee += segmentDistance.ceil() * 3;
        remainingDistance -= segmentDistance;
      }

      // 4. بعد 7 كم (بزيادة 8 جنيه لكل كيلو)
      if (remainingDistance > 0) {
        // كل المسافة اللي فاضلة بتتحسب بـ 8 جنيه لكل كيلو
        fee += remainingDistance.ceil() * 15;
      }

      return fee;
    } catch (e) {
      debugPrint('Delivery fee calculation failed: $e');
      return 20;
    }
  }

  Future<int> _getNextOrderNumber() async {
    final counterRef = FirebaseFirestore.instance
        .collection('metadata')
        .doc('order_counter');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int currentNumber = 100; // البداية من 100
      if (snapshot.exists && snapshot.data()!.containsKey('lastNumber')) {
        currentNumber = snapshot['lastNumber'] as int;
      }

      final nextNumber = currentNumber + 1;
      transaction.set(counterRef, {'lastNumber': nextNumber});

      return nextNumber;
    });
  }

  // 📌 الدالة الجديدة: لعرض الصورة بملء الشاشة مع الزوم
  void _showZoomableImage(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return; // لو مفيش صورة مفيش حاجة هتحصل

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'تفاصيل الصورة',
              style: TextStyle(color: Colors.white),
            ),
          ),
          // 💡 هنا استخدمنا PhotoView لعرض الصورة مع إمكانية الزوم
          body: photo_view.PhotoView(
            imageProvider: NetworkImage(imageUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: photo_view.PhotoViewComputedScale.contained * 0.8,
            maxScale: photo_view.PhotoViewComputedScale.covered * 2,
            initialScale: photo_view.PhotoViewComputedScale.contained,
            heroAttributes: photo_view.PhotoViewHeroAttributes(tag: imageUrl),
          ),
        ),
      ),
    );
  }

  Future<void> _sendOrder(BuildContext context, CartProvider cart) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("جاري إرسال الطلب..."),
            ],
          ),
        );
      },
    );

    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك.'),
          ),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('من فضلك سجل الدخول أولاً.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('صلاحية الموقع مرفوضة.')),
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('صلاحية الموقع مرفوضة بشكل دائم.')),
        );
      }
      return;
    }
    _deliveryFee = await _calculateDeliveryFee(selectedLocation.value);
    if (!mounted) {
      Navigator.pop(context);
      return;
    }

    // ✨ شرط جديد: لو سعر التوصيل ما اتحسبش (طلعت قيمته null)
    if (_deliveryFee == null) {
      if (context.mounted) {
        Navigator.pop(context); // قفل الـLoading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم يتمكن التطبيق من حساب سعر التوصيل. يرجى المحاولة لاحقاً.',
            ),
          ),
        );
      }
      return; // إلغاء إرسال الطلب
    }

    final Map<String, dynamic>? userData = await _showOrderDetailsDialog(
      context,
    );
    if (context.mounted) Navigator.pop(context);

    if (userData == null ||
        userData['name'] == null ||
        userData['phone'] == null ||
        userData['address'] == null ||
        userData['location'] == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال جميع البيانات المطلوبة.')),
        );
      }
      return;
    }

    if (userData['saveData'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_name', userData['name']);
      await prefs.setString('customer_phone', userData['phone']);
      await prefs.setString('customer_address', userData['address']);

      await prefs.setString('customer_notes', userData['notes']);
    }

    double pointsDiscount = 0;
    if (usePoints && clientPoints > 0) {
      pointsDiscount = clientPoints.toDouble();
      if (pointsDiscount > cart.totalAmount) {
        pointsDiscount = cart.totalAmount;
      }
    }

    final double finalTotal =
        cart.totalAmount - pointsDiscount - couponDiscount + _deliveryFee!;

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تأكيد الطلب'),
            content: Text(
              'سعر التوصيل: ${_deliveryFee!.toStringAsFixed(2)} جنيه\n'
              'خصم النقاط: ${pointsDiscount.toStringAsFixed(2)} جنيه\n'
              'خصم الكوبون: ${couponDiscount.toStringAsFixed(2)} جنيه\n'
              'الإجمالي النهائي: ${finalTotal.toStringAsFixed(2)} جنيه\n'
              'هل تريد تأكيد الطلب؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final orderItems = cart.items.values.map((item) {
      return {
        'id': item.id,
        'name': item.name,
        'priceOriginal': item.price,
        'quantity': item.quantity,
        'size': item.size,
        'addons': item.addons,
        'subtotal': item.price * item.quantity,
        'imageUrl': item.imageUrl, // ✅ هنا ضفنا رابط الصورة
      };
    }).toList();

    double lat = 0.0, lng = 0.0;
    final loc = userData['location'];
    if (loc is latlong.LatLng) {
      lat = loc.latitude;
      lng = loc.longitude;
    } else if (loc is Map) {
      lat = (loc['latitude'] ?? 0.0).toDouble();
      lng = (loc['longitude'] ?? 0.0).toDouble();
    }

    // ✅ الحساب الجديد
    final double totalProducts = cart.totalAmount; // اجمالي المنتجات
    pointsDiscount = 0;

    if (usePoints && clientPoints > 0) {
      // كل نقطة = 1 جنيه
      pointsDiscount = clientPoints.toDouble();

      // منع الخصم من تجاوز إجمالي المنتجات
      if (pointsDiscount > totalProducts) {
        pointsDiscount = totalProducts;
      }
    }

    final int earnedPoints = usePoints ? 0 : (totalProducts ~/ 100);

    final double totalStorePayout =
        totalProducts / (1 + widget.profitPercentage);

    final double grandTotal =
        totalProducts - pointsDiscount - couponDiscount + _deliveryFee!;
    final orderNumber = await _getNextOrderNumber();

    final orderData = {
      'orderNumber': orderNumber,
      'earnedPoints': earnedPoints,
      'usedPoints': pointsDiscount.toInt(),

      'store_id': cart.currentStoreId,
      'items': orderItems,
      'totalStorePayout': totalStorePayout,
      'usedCoupon': couponApplied ? _couponController.text.trim() : null,
      'couponDiscount': couponDiscount,
      // 🟢 الاجمالي للعميل (منتجات + توصيل)
      'grandTotal': grandTotal,

      // 🟢 توثيق
      'totalItemsPrice': totalProducts, // ✨ حقل جديد بديل لـ totalProducts
      'profitPercentage': widget.profitPercentage,
      'deliveryFee': _deliveryFee!,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
      'customer_id': user.uid,
      'customerName': userData['name'],
      'customerPhone': userData['phone'],
      'customerAddress': userData['address'],
      'customerLocation': GeoPoint(lat, lng),
      'storeLocation': GeoPoint(widget.storeLatitude, widget.storeLongitude),
      'customerNotes': userData['notes'] ?? '',
      'storeName': widget.storeName,
      'storeAddress': widget.storeAddress,
      'storeRegion': widget.storeRegion,
      'storePhone': widget.storePhone, // ⬅️ إضافة هذا السطر
    };

    try {
      final newOrderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);
      if (couponApplied) {
        final couponRef = FirebaseFirestore.instance
            .collection('coupons')
            .doc(_couponController.text.trim());
        await couponRef.update({
          'usedBy': FieldValue.arrayUnion([user.uid]),
        });
      }

      if (usePoints && pointsDiscount > 0) {
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(user.uid)
            .update({'points': clientPoints - pointsDiscount.toInt()});
      }

      final storeOrdersCollection = FirebaseFirestore.instance
          .collection('stores')
          .doc(cart.currentStoreId)
          .collection('orders');

      await storeOrdersCollection.doc(newOrderRef.id).set(orderData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_order_id', newOrderRef.id);
      await prefs.setString('active_store_id', cart.currentStoreId ?? '');

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OrderTrackingPage(orderId: newOrderRef.id),
          ),
        );
      }
      cart.clearCart();
    } catch (e) {
      if (context.mounted) {
        String errorMessage = 'حدث خطأ غير معروف: $e';
        if (e is FirebaseException) {
          if (e.code == 'permission-denied') {
            errorMessage = 'لا يوجد لديك صلاحية لإرسال الطلب.';
          } else if (e.code == 'unavailable') {
            errorMessage = 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى.';
          } else {
            errorMessage = 'حدث خطأ في قاعدة البيانات: ${e.message}';
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('coupons')
          .doc(code)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final discount = data['discount'] ?? 0;

        // التحقق من انتهاء الصلاحية
        final expiry = data['expiry'] as Timestamp?;
        if (expiry != null && expiry.toDate().isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الكوبون منتهي الصلاحية')),
          );
          return;
        }

        // التحقق من عدد الاستخدامات
        final maxUses = data['maxUses'] ?? 0;
        final usedBy = List<String>.from(data['usedBy'] ?? []);
        if (maxUses > 0 && usedBy.length >= maxUses) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استخدام الكوبون بالكامل')),
          );
          return;
        }

        // كل شيء تمام: طبق الخصم
        setState(() {
          couponDiscount = discount.toDouble();
          couponApplied = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تطبيق الكوبون! خصم $couponDiscount جنيه')),
        );
      } else {
        setState(() {
          couponDiscount = 0;
          couponApplied = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('الكوبون غير صالح')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تطبيق الكوبون: $e')));
    }
  }

  // 📌 الكود الخاص بالنافذة المنبثقة لبيانات العميل
  Future<Map<String, dynamic>?> _showOrderDetailsDialog(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final nameController = TextEditingController(
      text: prefs.getString('customer_name') ?? '',
    );
    final phoneController = TextEditingController(
      text: prefs.getString('customer_phone') ?? '',
    );
    final addressController = TextEditingController(
      text: prefs.getString('customer_address') ?? '',
    );
    final notesController = TextEditingController(
      text: prefs.getString('customer_notes') ?? '',
    );

    // ✅ الكود بعد التعديل: هيجيب موقع الجهاز الحالي فقط

    latlong.LatLng? location;
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      location = latlong.LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }

    final saveDetails = ValueNotifier(prefs.getBool('save_details') ?? false);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('أدخل بياناتك'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان بالتفصيل',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    hintText: 'اكتب أي ملاحظات تريد إضافتها للطلب',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: saveDetails,
                  builder: (context, isChecked, child) {
                    return Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          onChanged: (bool? value) async {
                            await prefs.setBool('save_details', value ?? false);
                            saveDetails.value = value ?? false;
                          },
                        ),
                        const Text('حفظ البيانات في كل طلب؟'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context, null),
            ),
            ElevatedButton(
              child: const Text('تأكيد'),
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty &&
                    addressController.text.isNotEmpty &&
                    location != null) {
                  Navigator.pop(context, {
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'address': addressController.text,
                    'location': location,
                    'saveData': saveDetails.value,
                    'notes': notesController.text.trim(),
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء ملء جميع البيانات')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // في ملف CartPage.dart
  // ... (كل الـ imports والـ classes والـ functions زي ما هي)

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF3B30)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'كل اللي عايزه يوصلك',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: Color.fromARGB(255, 239, 240, 241),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete,
              color: Color.fromARGB(255, 247, 244, 244),
            ),
            tooltip: 'مسح السلة',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'تأكيد المسح',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    'هل أنت متأكد أنك تريد مسح جميع محتويات السلة؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(
                        Icons.delete,
                        color: Color.fromARGB(255, 250, 250, 250),
                      ),
                      label: const Text('مسح'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final cart = Provider.of<CartProvider>(context, listen: false);
                cart.clearCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.white),
                        SizedBox(width: 8),
                        Text('تم مسح السلة بالكامل'),
                      ],
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),

      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 245, 69, 0), // برتقالي غامق
              Colors.white, // أبيض
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: cart.items.isEmpty
              ? const Center(
                  child: Text(
                    'السلة فارغة. أضف بعض المنتجات!',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: cart.items.length,
                        itemBuilder: (context, index) {
                          final item = cart.items.values.toList()[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                            child: ListTile(
                              leading: GestureDetector(
                                // ⬅️ إضافة الـ GestureDetector
                                onTap: () {
                                  _showZoomableImage(context, item.imageUrl);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.imageUrl.isNotEmpty
                                      ? Image.network(
                                          item.imageUrl,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          // 💡 إضافة Hero tag عشان الـAnimation يبقى شكله حلو
                                          // الـtag لازم يكون فريد، عشان كدة استخدمنا رابط الصورة
                                          // ولو الصورة مش موجودة، مش هنحط الـHero
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return Hero(
                                                tag: item
                                                    .imageUrl, // الـTag الفريد
                                                child: child,
                                              );
                                            }
                                            return SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  value:
                                                      loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                      : null,
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.fastfood,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.size != null &&
                                      item.size!.isNotEmpty)
                                    Text(
                                      "الحجم: ${item.size}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  if (item.addons != null &&
                                      item.addons!.isNotEmpty)
                                    Text(
                                      "إضافات: ${item.addons!.map((a) => a['name']).join(', ')}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color.fromARGB(255, 221, 7, 7),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "السعر: ${item.price.toStringAsFixed(2)} × ${item.quantity} = ${(item.price * item.quantity).toStringAsFixed(2)} جنيه",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => cart.updateQuantity(
                                      item.uniqueId,
                                      item.quantity - 1,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => cart.updateQuantity(
                                      item.uniqueId,
                                      item.quantity + 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    _buildTotalsCard(context, cart),
                  ],
                ),
        ),
      ),
    );
  }

  // 📌 الكود الجديد اللي هيضاف في CartPage.dart
  // ✨  نفس الكود اللي في الإجابة اللي فاتت
  Widget _buildTotalsCard(BuildContext context, CartProvider cart) {
    return ValueListenableBuilder<latlong.LatLng?>(
      valueListenable: selectedLocation,
      builder: (context, location, child) {
        return Card(
          margin: const EdgeInsets.all(16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي المنتجات',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      '${cart.totalAmount.toStringAsFixed(2)} جنيه',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<double?>(
                  future: _calculateDeliveryFee(location),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return const Text(
                        'تعذر حساب رسوم التوصيل. تحقق من الشبكة والموقع.',
                        style: TextStyle(color: Colors.red),
                      );
                    }

                    final deliveryFee = snapshot.data!;
                    double pointsDiscountUI = 0;

                    if (usePoints && clientPoints > 0) {
                      pointsDiscountUI = clientPoints.toDouble();
                      if (pointsDiscountUI > cart.totalAmount) {
                        pointsDiscountUI = cart
                            .totalAmount; // ما تخليش الخصم أكبر من إجمالي السلة
                      }
                    }

                    final finalTotal =
                        cart.totalAmount -
                        pointsDiscountUI -
                        couponDiscount +
                        deliveryFee;

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'رسوم التوصيل',
                              style: TextStyle(fontSize: 16),
                            ),
                            if (pointsDiscountUI > 0) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'خصم النقاط',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    '-${pointsDiscountUI.toStringAsFixed(0)} جنيه',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            Text(
                              '${deliveryFee.toStringAsFixed(2)} جنيه',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'الإجمالي النهائي',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${finalTotal.toStringAsFixed(2)} جنيه',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        if (pointsDiscountUI > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'وفّرت ${pointsDiscountUI.toStringAsFixed(0)} جنيه بنقاطك 🎉',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                if (clientPoints > 0)
                  Row(
                    children: [
                      Checkbox(
                        value: usePoints,
                        onChanged: (val) {
                          setState(() {
                            usePoints = val ?? false;
                          });
                        },
                      ),
                      Text('استخدم نقاطي ($clientPoints نقطة)'),
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        decoration: InputDecoration(
                          labelText: 'كود الخصم',
                          prefixIcon: const Icon(Icons.card_giftcard),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFE8F5E9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _applyCoupon,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'تطبيق ',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                if (couponApplied)
                  Text(
                    'تم تطبيق الكوبون! خصم $couponDiscount جنيه',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () => _sendOrder(context, cart),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'إرسال الطلب',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
