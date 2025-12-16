import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math'; // لإستخدام دالة min عند حساب المسافة

// لازم تكون مستورد صفحة StoreItemsPage هنا عشان تعرف تستخدمها
// لاحظ ان اسم الملف ده مفترض يكون في نفس مسار ملف StoreItemsPage او تستورد مساره الصح
import 'store_items_page.dart'; // 🆕 استيراد الصفحة الجديدة

// ----------------------------------------------------
// 1. Models and Helper Functions
// ----------------------------------------------------

// موديل الأصناف المشاركة في العرض (بدون تغيير)
class StoreItem {
  final String id;
  final String name;
  final String imageUrl;
  final double priceOriginal;

  StoreItem.fromFirestore(Map<String, dynamic> data, this.id)
    : name = data['name'] ?? 'صنف غير معروف',
      priceOriginal = (data['price'] is num
          ? (data['price'] as num).toDouble()
          : double.tryParse(data['price']?.toString() ?? '0') ?? 0.0),
      imageUrl = data['image'] ?? 'https://via.placeholder.com/60';
}

// موديل العروض (بدون تغيير)
class Offer {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String storeId;
  final double price;
  final String offerTypeDisplay;

  Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.storeId,
    required this.price,
    required this.offerTypeDisplay,
  });

  Offer copyWith({double? price}) {
    return Offer(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      storeId: storeId,
      price: price ?? this.price,
      offerTypeDisplay: offerTypeDisplay,
    );
  }

  factory Offer.fromFirestore(Map<String, dynamic> data, String id) {
    double calculatedPrice = 0.0;
    if (data['details'] != null && data['details']['price'] != null) {
      calculatedPrice = (data['details']['price'] as num?)?.toDouble() ?? 0.0;
    }

    return Offer(
      id: id,
      title: data['title'] ?? 'عرض مميز',
      description: data['description'] ?? 'لا يوجد وصف',
      imageUrl: data['image_url'] ?? 'https://via.placeholder.com/150',
      storeId: data['store_id'] ?? '',
      price: calculatedPrice,
      offerTypeDisplay: data['offer_type_display'] ?? 'عرض خاص',
    );
  }
}

// موديل المحلات
class Store {
  final String id;
  final String name;
  final String logoUrl;
  final String address;
  final GeoPoint location;
  final double profitPercentage; // نسبة ربح التطبيق
  final String storeRegion; // 🆕 تم الإضافة
  final String storePhone; // 🆕 تم الإضافة

  Store({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.address,
    required this.location,
    required this.profitPercentage,
    required this.storeRegion, // 🆕
    required this.storePhone, // 🆕
  });

  factory Store.fromFirestore(Map<String, dynamic> data, String id) {
    return Store(
      id: id,
      name: data['storeName'] ?? 'محل غير معروف',
      logoUrl: data['logoUrl'] ?? 'https://via.placeholder.com/60',
      address: data['address'] ?? 'لا يوجد عنوان',
      location: data['location'] != null
          ? GeoPoint(
              (data['location']['lat'] as num?)?.toDouble() ?? 0.0,
              (data['location']['lng'] as num?)?.toDouble() ?? 0.0,
            )
          : const GeoPoint(0, 0),
      profitPercentage: (data['profitPercentage'] as num?)?.toDouble() ?? 0.0,
      storeRegion: data['storeRegion'] ?? 'غير معروف', // 🆕 استخراج الحقل
      storePhone:
          data['phone'] ??
          'لا يوجد هاتف', // 🆕 استخراج الحقل (افتراض أن اسمه 'phone')
    );
  }
}

// موديل تجميع البيانات للـ FutureBuilder (بدون تغيير)
class CombinedOfferData {
  final Offer offer;
  final Store store;
  final List<StoreItem> items;

  CombinedOfferData({
    required this.offer,
    required this.store,
    required this.items,
  });
}

// دالة مساعدة لحساب السعر النهائي للعميل (بإضافة نسبة الربح) (بدون تغيير)
double calculateClientPrice(double originalPrice, double profitPercentage) {
  if (originalPrice <= 0) return 0.0;

  final double rate = (profitPercentage > 1.0)
      ? (profitPercentage / 100.0)
      : profitPercentage;

  final double clientPrice = originalPrice * (1.0 + rate);
  return double.parse(clientPrice.toStringAsFixed(2));
}

// ----------------------------------------------------
// 2. All Offers Screen
// ----------------------------------------------------

class AllOffersScreen extends StatelessWidget {
  const AllOffersScreen({super.key});

  // دوال جلب العروض (بدون تغيير)
  Stream<List<Offer>> getActiveOffers() {
    final now = Timestamp.now(); // الوقت الحالي

    return FirebaseFirestore.instance
        .collection('offers')
        .where('active', isEqualTo: true)
        .where('end_date', isGreaterThan: now) // ✅ تجاهل العروض المنتهية
        .orderBy('end_date', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Offer.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // دالة جلب تفاصيل المحل (تم تحديثها لجلب البيانات الجديدة)
  Future<Store> getStoreDetails(String storeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();
    if (doc.exists && doc.data() != null) {
      return Store.fromFirestore(doc.data()!, doc.id);
    }
    // حالة الـ Store المحذوف (تم إضافة البيانات الجديدة هنا أيضاً)
    return Store(
      id: storeId,
      name: 'محل محذوف',
      logoUrl: 'https://via.placeholder.com/60',
      address: 'عنوان غير معروف',
      location: const GeoPoint(0, 0),
      profitPercentage: 0.0,
      storeRegion: 'غير معروفة', // 🆕
      storePhone: '0000', // 🆕
    );
  }

  // باقي الدوال المساعدة (بدون تغيير)
  Future<GeoPoint> getCurrentClientLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          "صلاحيات الموقع مرفوضة. الرجاء السماح للتطبيق بالوصول إلى موقعك.",
        );
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      throw Exception("فشل في تحديد موقعك الحالي: تأكد من تشغيل GPS.");
    }
  }

  double calculateDistance(GeoPoint start, GeoPoint end) {
    double distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    return distanceInMeters / 1000.0;
  }

  double calculateDeliveryFee(double distanceInKm) {
    if (distanceInKm <= 1.0) {
      return 20.0;
    } else {
      final double extraKm = distanceInKm - 1.0;
      final double extraFee = extraKm * 2.0;
      return 20.0 + extraFee;
    }
  }

  String getCurrentCustomerId() {
    return "K4glDgdH8cNjoLmByrTiLBDH1GK2";
  }

  Future<List<StoreItem>> getOfferItemsDetails(
    String storeId,
    Map<String, dynamic>? offerDetails,
  ) async {
    List<dynamic>? itemsList;
    if (offerDetails == null) return [];

    if (offerDetails.containsKey('bundle')) {
      itemsList = offerDetails['bundle'] as List<dynamic>?;
    } else if (offerDetails.containsKey('buy')) {
      List<dynamic> buyItems = offerDetails['buy'] as List<dynamic>? ?? [];
      List<dynamic> freeItems =
          offerDetails['get_free'] as List<dynamic>? ?? [];
      itemsList = [...buyItems, ...freeItems];
    }

    if (itemsList == null || itemsList.isEmpty) return [];

    List<String> itemIds = itemsList
        .map((item) => item['item_id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (itemIds.isEmpty) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('store_items')
        .where(
          FieldPath.documentId,
          whereIn: itemIds.sublist(0, min(itemIds.length, 10)),
        )
        .get();

    return snapshot.docs
        .map((doc) => StoreItem.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<CombinedOfferData> getCombinedOfferData(Offer offer) async {
    final store = await getStoreDetails(offer.storeId);
    final offerDoc = await FirebaseFirestore.instance
        .collection('offers')
        .doc(offer.id)
        .get();
    final offerDetails = offerDoc.data()?['details'] as Map<String, dynamic>?;

    final items = await getOfferItemsDetails(offer.storeId, offerDetails);

    return CombinedOfferData(offer: offer, store: store, items: items);
  }

  // ----------------------------------------------------
  // 3. دالة إظهار ديالوج الطلب (بدون تغيير)
  // ----------------------------------------------------

  void showOrderDialog(
    BuildContext context,
    Offer originalOffer,
    double clientOfferPrice,
    Store store,
  ) async {
    final customerNameController = TextEditingController(
      text: 'اسم العميل الحالي',
    );
    final customerAddressController = TextEditingController();
    final customerPhoneController = TextEditingController();
    final customerNotesController = TextEditingController();

    GeoPoint clientLocation;
    double distanceInKm = 0.0;
    double deliveryFee = 0.0;

    try {
      clientLocation = await getCurrentClientLocation();
      distanceInKm = calculateDistance(clientLocation, store.location);
      deliveryFee = calculateDeliveryFee(distanceInKm);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'عفواً، لا يمكن إتمام الطلب: ${e.toString().split(':')[1].trim()}',
            ),
          ),
        );
      }
      return;
    }

    final double clientGrandTotal = clientOfferPrice + deliveryFee;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('تأكيد طلب: ${originalOffer.title}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سعر العرض (للعميل): ${clientOfferPrice.toStringAsFixed(2)} جنيه',
                    ),
                    Text(
                      'رسوم التوصيل: ${deliveryFee.toStringAsFixed(2)} جنيه',
                    ),
                    const Divider(),
                    Text(
                      'الاجمالي + التوصيل: ${clientGrandTotal.toStringAsFixed(2)} جنيه',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                    const Divider(),
                    TextField(
                      controller: customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسمك الكريم',
                      ),
                    ),
                    TextField(
                      controller: customerPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم التليفون',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: customerAddressController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان التسليم بالتفصيل',
                      ),
                    ),
                    TextField(
                      controller: customerNotesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (customerAddressController.text.isNotEmpty) {
                      _sendOfferAsOrder(
                        context,
                        originalOffer.price,
                        clientOfferPrice,
                        clientGrandTotal,
                        store,
                        clientLocation,
                        deliveryFee,
                        customerNameController.text,
                        customerPhoneController.text,
                        customerAddressController.text,
                        customerNotesController.text,
                        originalOffer.id,
                        originalOffer.title,
                        originalOffer.imageUrl,
                        originalOffer.description,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الرجاء إدخال عنوان التسليم.'),
                        ),
                      );
                    }
                  },
                  child: const Text('تأكيد الطلب'),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // ----------------------------------------------------
  // 4. دالة إرسال الطلب (بدون تغيير)
  // ----------------------------------------------------

  Future<void> _sendOfferAsOrder(
    BuildContext context,
    double storeBasePrice,
    double clientOfferPrice,
    double clientGrandTotal,
    Store store,
    GeoPoint clientLocation,
    double deliveryFee,
    String name,
    String phone,
    String address,
    String notes,
    String offerId,
    String offerTitle,
    String offerImageUrl,
    String offerDescription,
  ) async {
    final double totalStorePayout = storeBasePrice;

    Map<String, dynamic> orderData = {
      'customerName': name,
      'customerPhone': phone,
      'customerAddress': address,
      'customerNotes': notes,
      'customer_id': getCurrentCustomerId(),
      'customerLocation': clientLocation,
      'store_id': store.id,
      'storeName': store.name,
      'storeAddress': store.address,
      'storeLocation': store.location,
      'storeRegion': store.storeRegion, // ✅ أضف هذا
      'storePhone': store.storePhone, // ✅ وأضف هذا
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
      'description': offerDescription,
      'totalItemsPrice': clientOfferPrice,
      'totalItemsPriceOriginal': storeBasePrice,
      'totalStorePayout': totalStorePayout,
      'deliveryFee': deliveryFee,
      'grandTotal': clientGrandTotal,
      'items': [
        {
          'id': offerId,
          'name': offerTitle,
          'imageUrl': offerImageUrl,
          'priceOriginal': clientOfferPrice,
          'quantity': 1,
          'subtotal': clientOfferPrice,
        },
      ],
      'orderNumber': 0,
      'totalDiscount': 0,
    };

    try {
      final DocumentReference orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(store.id)
          .collection('orders')
          .doc(orderRef.id)
          .set(orderData);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلبك بنجاح! المحل يجهز الطلب الآن.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ في إرسال الطلب: ${e.toString()}')),
        );
      }
    }
  }

  // ----------------------------------------------------
  // 5. Build Method (شكل الواجهة)
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'كل العروض ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<Offer>>(
          stream: getActiveOffers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حصل خطأ: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'مفيش عروض متاحة حالياً.',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            final offers = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];

                return FutureBuilder<CombinedOfferData>(
                  future: getCombinedOfferData(offer),
                  builder: (context, combinedSnapshot) {
                    if (combinedSnapshot.connectionState !=
                        ConnectionState.done) {
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 150,
                          child: Center(
                            child: Text('جاري تحميل تفاصيل عرض ${offer.title}'),
                          ),
                        ),
                      );
                    }

                    if (!combinedSnapshot.hasData ||
                        combinedSnapshot.hasError) {
                      return const SizedBox.shrink();
                    }

                    final data = combinedSnapshot.data!;
                    final store = data.store;
                    final double storeOfferPrice = data.offer.price;

                    final double clientOfferPrice = calculateClientPrice(
                      storeOfferPrice,
                      store.profitPercentage,
                    );

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    offer.imageUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.image_not_supported,
                                              size: 100,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        offer.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'من: ${store.name}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        offer.description,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // تم حذف Divider مكرر هنا
                            // const Divider(height: 20),
                            Text(
                              'سعر العرض: ${clientOfferPrice.toStringAsFixed(2)} جنيه',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),

                            const SizedBox(height: 12),
                            // الأزرار
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // 🚀 الكود المحدث لزرار "شاهد المحل"
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StoreItemsPage(
                                            storeId: store.id,
                                            storeName: store.name,
                                            storeAddress: store.address,
                                            storeRegion: store
                                                .storeRegion, // 🚀 استخدمنا البيانات من موديل Store
                                            profitPercentage:
                                                store.profitPercentage,
                                            storePhone: store
                                                .storePhone, // 🚀 استخدمنا البيانات من موديل Store
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.storefront,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'شاهد المحل',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade200,
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      showOrderDialog(
                                        context,
                                        data.offer,
                                        clientOfferPrice,
                                        store,
                                      );
                                    },
                                    icon: const Icon(Icons.flash_on, size: 18),
                                    label: const Text(
                                      'احصل عليه الآن',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
