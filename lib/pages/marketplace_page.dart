// marketplace_page.dart
// ignore_for_file: use_build_context_synchronously
import '../profile_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../cart_page.dart';
import '../../store_items_page.dart';
import 'package:latlong2/latlong.dart'
    as latlong; // 💡 ضيف هنا كلمة 'as latlong'
import '../../services/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'recent_orders_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../all_offers_screen.dart';
import 'package:zed/login_page.dart';
import 'package:photo_view/photo_view.dart';

class ItemCard extends StatefulWidget {
  final Item item;

  const ItemCard({super.key, required this.item});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard>
    with AutomaticKeepAliveClientMixin {
  int selectedSizeIndex = -1;
  final Set<int> selectedAddons = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // مهم مع KeepAlive

    double currentPrice = widget.item.price;
    if (selectedSizeIndex >= 0) {
      currentPrice = widget.item.sizes[selectedSizeIndex].price;
    }

    return Card(
      child: Column(
        children: [
          Text(widget.item.name),
          Text('${currentPrice.toStringAsFixed(2)} جنيه'),
          Wrap(
            spacing: 8,
            children: List.generate(widget.item.sizes.length, (i) {
              final size = widget.item.sizes[i];
              return ChoiceChip(
                label: Text(size.name),
                selected: selectedSizeIndex == i,
                onSelected: (_) {
                  setState(() {
                    selectedSizeIndex = i;
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class BannerData {
  final dynamic item;
  final Store? store;

  BannerData({required this.item, this.store});
}

class Store {
  final String id;
  final String storeName;
  final String storeRegion;
  final String logoUrl;
  final double latitude;
  final double longitude;
  final double averageRating;
  final int ratingsCount;
  final bool isOpen;
  final double profitPercentage; // 👈 بقت اختيارية
  final String phone;
  final String address; // ✅ ضيف ده
  // 👈 بقت اختيارية

  Store({
    required this.id,
    required this.storeName,
    required this.storeRegion,
    required this.logoUrl,
    required this.latitude,
    required this.longitude,
    required this.averageRating,
    required this.ratingsCount,
    required this.isOpen,
    this.profitPercentage = 0.0, // 👈 قيمة افتراضية
    this.phone = '', // 👈 قيمة افتراضية
    required this.address, // ✅ ضيف هنا
  });

  factory Store.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Store(
      id: doc.id,
      storeName: data['storeName']?.toString() ?? 'محل غير معروف',
      storeRegion: data['storeRegion']?.toString() ?? '',
      address: data['address'] ?? '',
      logoUrl: data['logoUrl']?.toString() ?? '',
      latitude: _toDouble(data['location']?['lat']),
      longitude: _toDouble(data['location']?['lng']),
      averageRating: _toDouble(data['averageRating']),
      ratingsCount: data['ratingsCount'] is int ? data['ratingsCount'] : 0,
      isOpen: data['isOpen'] == true,
      profitPercentage: _toDouble(data['profitPercentage']),
      phone: data['phone']?.toString() ?? '',
    );
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class SizeOption {
  final String name;
  final double price;
  SizeOption({required this.name, required this.price});
  factory SizeOption.fromMap(Map<String, dynamic> m) {
    return SizeOption(
      name: (m['name'] ?? '').toString(),
      price: _toDouble(m['price']),
    );
  }
}

class AddonOption {
  final String name;
  final double price;
  AddonOption({required this.name, required this.price});
  factory AddonOption.fromMap(Map<String, dynamic> m) {
    return AddonOption(
      name: (m['name'] ?? '').toString(),
      price: _toDouble(m['price']),
    );
  }
}

class Item {
  final String id;
  final String storeId;
  final String name;
  final String description;
  final double price; // base price
  final double? discount;
  final String? quantity;
  final String? priceUnit;
  final List<String> image;
  final List<AddonOption> addons;
  final List<SizeOption> sizes;
  final String category;
  final bool available; // ← ضيف الحقل هنا

  Item({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.price,
    this.discount,
    this.quantity,
    this.priceUnit,
    required this.image,
    required this.addons,
    required this.sizes,
    required this.category,
    required this.available, // ← هنا كمان
  });

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // images
    final images = data?['image'];
    List<String> imageList = [];
    if (images is String && images.isNotEmpty) {
      imageList = [images];
    } else if (images is List) {
      imageList = images.whereType<String>().toList();
    }

    // sizes
    List<SizeOption> sizesList = [];
    final rawSizes = data?['sizes'];
    if (rawSizes is List) {
      for (var e in rawSizes) {
        if (e is Map) {
          sizesList.add(SizeOption.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    // addons
    List<AddonOption> addonsList = [];
    final rawAddons = data?['addons'];
    if (rawAddons is List) {
      for (var e in rawAddons) {
        if (e is Map) {
          addonsList.add(AddonOption.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    return Item(
      id: doc.id,
      storeId: data?['store_id'] as String? ?? '',
      name: data?['name'] as String? ?? 'منتج غير معروف',
      description: data?['description'] as String? ?? '',
      price: _toDouble(data?['price']),
      discount: (data?['discount'] != null)
          ? _toDouble(data?['discount'])
          : null,
      quantity: data?['quantity'] as String?,
      priceUnit: data?['priceUnit'] as String? ?? 'جنيه',
      image: imageList,
      addons: addonsList,
      sizes: sizesList,
      category: data?['category_id'] as String? ?? '',
      available: data?['available'] ?? false,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String imageUrl;

  Category({required this.id, required this.name, required this.imageUrl});

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Category(
      id: doc.id,
      name: data?['name'] ?? 'قسم غير معروف',
      imageUrl: data?['image'] ?? '',
    );
  }
}

class Offer {
  final String id;
  final String storeId;
  final String title; // حقل جديد
  final String description; // حقل جديد
  final String? imageUrl; // حقل جديد
  final bool active; // حقل جديد
  final DateTime? startDate;
  final DateTime? endDate;

  Offer({
    required this.id,
    required this.storeId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.active,
    this.startDate,
    this.endDate,
  });

  factory Offer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final startDateTimestamp = data?['start_date'] as Timestamp?;
    final endDateTimestamp = data?['end_date'] as Timestamp?;

    return Offer(
      id: doc.id,
      storeId: data?['store_id'] ?? '',
      title: data?['title'] ?? 'عرض خاص',
      description: data?['description'] ?? '',
      imageUrl: data?['image_url'],
      active: data?['active'] ?? false,
      startDate: startDateTimestamp?.toDate(),
      endDate: endDateTimestamp?.toDate(),
    );
  }
}

// ====================================================
// واجهة المستخدم (UI)
// ====================================================

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key, this.userLocation});
  final latlong.LatLng? userLocation;

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage>
    with AutomaticKeepAliveClientMixin {
  String? customerId;
  String? userType;
  bool isLoggedIn = false;

  String? expandedItemId;

  double? userLat;
  double? userLng;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  // تعديل: متغير جديد لتخزين الـID بتاع القسم المختار
  String? _selectedCategoryId;
  final PageController _pageController = PageController();
  Timer? _timer;

  Map<String, Store> storesMap = {};

  @override
  void initState() {
    super.initState();
    _loadUserData(); // ✅ بدّل مكان _checkLoginStatus

    if (widget.userLocation != null) {}
    _startBannerAutoScroll();
    _getUserLocation();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    final prefs = await SharedPreferences.getInstance();

    if (user != null) {
      customerId = user.uid; // 👈 استخدام الـUID من Firebase مباشرةً
    } else {
      customerId = prefs.getString('customer_id'); // كـFallback
    }

    userType = prefs.getString('userType');

    if (mounted) {
      setState(() {});
    }

    ('Customer ID: $customerId, User Type: $userType');
  }
  // Future<void> _checkLoginStatus() async {
  //  final prefs = await SharedPreferences.getInstance();
  //  final loggedIn = prefs.getBool('isLoggedIn') ?? false;
  //  if (!loggedIn) {
  //    if (!mounted) return;
  //   Navigator.pushReplacement(
  //    context,
  //    MaterialPageRoute(builder: (_) => ClientAuthScreen()),
  //  );
  //  }
  // }

  Future<List<BannerData>> _fetchBannersData() async {
    if (userLat == null || userLng == null) {
      await _getUserLocation();
    }

    if (userLat == null || userLng == null) {
      return []; // مفيش لوكيشن، نرجع فاضي
    }

    final customerLat = userLat!;
    final customerLng = userLng!;

    // ✅ جلب العروض الفعالة
    final offersSnapshot = await FirebaseFirestore.instance
        .collection('offers')
        .orderBy('createdAt', descending: true) // لازم يكون عندك createdAt
        .limit(30)
        .get();

    final offers = offersSnapshot.docs
        .map((doc) => Offer.fromFirestore(doc))
        .where(
          (offer) =>
              offer.active &&
              offer.startDate != null &&
              offer.endDate != null &&
              offer.endDate!.isAfter(DateTime.now()) &&
              offer.startDate!.isBefore(DateTime.now()),
        )
        .toList();

    // ✅ جلب المحلات
    final storesSnapshot = await FirebaseFirestore.instance
        .collection('stores')
        .orderBy('createdAt', descending: true) // نفس الكلام
        .limit(30)
        .get();

    final storesMap = {
      for (var doc in storesSnapshot.docs) doc.id: Store.fromFirestore(doc),
    };

    List<BannerData> banners = [];

    // دمج العروض مع المحلات
    for (var offer in offers) {
      final store = storesMap[offer.storeId];
      if (store != null) {
        final distance =
            Geolocator.distanceBetween(
              customerLat,
              customerLng,
              store.latitude,
              store.longitude,
            ) /
            1000; // بالكيلومتر

        if (distance <= 7) {
          banners.add(BannerData(item: offer, store: store));
        }
      }
    }

    // المحلات اللي مالهاش عروض
    final storeIdsWithOffers = offers.map((o) => o.storeId).toSet();
    final storesWithoutOffers = storesMap.values.where(
      (s) => !storeIdsWithOffers.contains(s.id),
    );

    for (var store in storesWithoutOffers) {
      final distance =
          Geolocator.distanceBetween(
            customerLat,
            customerLng,
            store.latitude,
            store.longitude,
          ) /
          1000;

      if (distance <= 7) {
        banners.add(BannerData(item: store));
      }
    }

    // ✅ رجع أحدث 10 فقط
    return banners.take(10).toList();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // التأكد إن GPS مفعل
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // ممكن تحذر المستخدم
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    setState(() {
      userLat = position.latitude;
      userLng = position.longitude;
    });
  }

  void _startBannerAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        final int nextPage = (_pageController.page ?? 0).round() + 1;
        _pageController
            .animateToPage(
              nextPage,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeIn,
            )
            .catchError((e) {
              debugPrint("Error animating banner: $e");
            });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  DateTime? lastBackPressed; // ضيف ده فوق build مباشرة في State

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    super.build(context);

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (lastBackPressed == null ||
            now.difference(lastBackPressed!) > const Duration(seconds: 2)) {
          lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اضغط مرة ثانية للخروج'),
              duration: Duration(seconds: 2),
            ),
          );
          return false; // تمنع الإغلاق
        }
        return true; // لو ضغط مرتين بسرعة يخرج
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 245, 48, 48), // برتقالي غامق
                Colors.white, // أبيض
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildSearchField(),
                _buildBannersSection(),
                _buildActionButtons(context),
                _buildCategoriesSection(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
        floatingActionButton: cart.itemCount > 0
            ? Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: FloatingActionButton.extended(
                    onPressed: () async => await _goToCart(cart),
                    heroTag: 'cart_tag',
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: Text(
                      'السلة (${cart.itemCount}) - ${cart.totalAmount.toStringAsFixed(2)} جنيه',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green[700],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Color.fromRGBO(245, 49, 0, 1), // برتقالي غامق

      elevation: 0,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '   طلباتك أوامر ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25,
              color: Color.fromRGBO(228, 230, 231, 1),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      centerTitle: true,

      actions: [
        IconButton(
          icon: const Icon(
            Icons.account_circle,
            color: Color.fromARGB(255, 43, 43, 44),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث عن محل أو صنف...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      // تعديل: بنمسح اختيار القسم لما نعمل بحث جديد
                      _selectedCategoryId = null;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
            // تعديل: بنمسح اختيار القسم لما نكتب في البحث
            _selectedCategoryId = null;
          });
        },
      ),
    );
  }
  // ... جوة الكلاس _MarketplacePageState

  // دالة جديدة لعرض رسالة خارج نطاق التغطية
  Widget _buildNoStoresMessage(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: Color(0xFF006400), size: 70),
            const SizedBox(height: 20),
            const Text(
              'نطاق التغطية حالياً محدود، يا فندم! 🌍',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'خدمة (زد)  متوفرة حالياً ولكن لاتوجد محلات قريبه منك كن أول المستفيدين من (زد) في منطقتك وأضف محلك الجديد ٍ .',
              style: TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              '! قريبا ان شاء الله سنغطي جميع المحافظات شكرا لتفهمكم 🚀',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF006400),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ... بعد كده كمل بدالة _buildBannersSection() اللي موجودة عندك ...
  Widget _buildBannersSection() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchBannersData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          debugPrint('Error loading banners: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final banners = snapshot.data!;

        return Column(
          children: [
            SizedBox(
              height: 150,
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: banners.length * 1000,
                      itemBuilder: (context, index) {
                        final item = banners[index % banners.length];
                        if (item is BannerData && item.item is Offer) {
                          return _buildOfferCard(item);
                        } else if (item is BannerData && item.item is Store) {
                          return _buildStoreBanner(item.item);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: banners.length,
                    effect: const WormEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: Colors.green,
                      dotColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // زر أضف محلك
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                elevation: 6,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.storefront, color: Colors.white, size: 20),
              label: const Text(
                'أضف محلك',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // زر عاوز مندوب
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent.shade400,
                elevation: 6,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ميزة المشاوير',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: const [
                            Icon(Icons.medical_services, color: Colors.blue),
                            SizedBox(width: 10),
                            Expanded(child: Text('حجز عند دكتور')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.train, color: Colors.green),
                            SizedBox(width: 10),
                            Expanded(child: Text('حجز قطارات أو فنادق')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.shopping_bag, color: Colors.orange),
                            SizedBox(width: 10),
                            Expanded(child: Text('شراء أي منتج من أي متجر')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.delivery_dining,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 10),
                            Expanded(child: Text('توصيل أي شيء من أي مكان')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.send, color: Colors.purple),
                            SizedBox(width: 10),
                            Expanded(child: Text('إرسال أي شيء لأي شخص')),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlueAccent.shade400,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(context); // يغلق الـ Bottom Sheet
                              String phoneNumber = '201556798005';
                              String message =
                                  'اكتب هنا الطلب او المشوار اللي حضرتك عاوزه    ';
                              String whatsappUrl =
                                  'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}';

                              if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                                await launchUrl(Uri.parse(whatsappUrl));
                              }
                            },
                            child: const Text('التالي'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.delivery_dining,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'مشاويرك',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // زر تتبع طلبك
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                elevation: 6,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final customerId = prefs.getString('customer_id');
                if (customerId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          RecentOrdersPage(customerId: customerId),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("لم يتم العثور على هوية العميل"),
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.track_changes,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'بيان بطلبك',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // زر العروض
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                elevation: 6,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllOffersScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.local_offer,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'العروض',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreBanner(Store store) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoreItemsPage(
            storeId: store.id,
            storeName: store.storeName,
            storeAddress: store.address,
            storeRegion: store.storeRegion,
            profitPercentage: store.profitPercentage,
            storePhone: store.phone,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.green[400],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.2 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: store.logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: store.logoUrl,
                        fit: BoxFit.cover,
                        cacheKey:
                            store.logoUrl, // 🟢 يخزن الصورة مؤقتاً حسب الرابط
                        memCacheHeight: 600, // 🟢 يقلل استهلاك الذاكرة
                        memCacheWidth: 600,
                        maxWidthDiskCache: 800, // 🟢 يخزن الصورة على القرص
                        maxHeightDiskCache: 800,
                        useOldImageOnUrlChange:
                            true, // 🟢 يخلي الصورة القديمة تظهر أثناء التحميل
                        fadeInDuration: const Duration(milliseconds: 300),
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.red),
                        ),
                      )
                    : Container(color: Colors.grey[300]),
              ),
            ),
            // 🔥 طبقة تظليل أسود شفاف لإظهار الكتابة بوضوح
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.25, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 💡 التعديل هنا: استخدم Positioned لتثبيت المحتوى في الأسفل
            Positioned(
              bottom: 0, // ثبت المحتوى عند القاع تماماً
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  // mainAxisSize: MainAxisSize.min, // مش ضرورية مع Positioned اللي واخد bottom: 0
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // **1. تقليل سطر العنوان من 2 لـ 1 لو مفيش داعي للسطرين**
                    Text(
                      store.storeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      // نزلها لـ 1 سطر عشان توفر مساحة (اختياري، بس بيضمن)
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // **2. تقليل المسافة من 4 لـ 2**
                    const Text(
                      'جربنا الآن 🍔🔥',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // **3. تقليل المسافة من 4 لـ 2**
                    Text(
                      store.storeRegion,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4), // **4. تقليل المسافة من 6 لـ 4**
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          store.averageRating.toStringAsFixed(
                            1,
                          ), // 👈 من الحقل averageRating
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "(${store.ratingsCount} تقييم)", // 👈 من الحقل ratingsCount
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // الدالة الجديدة
  Widget _buildOfferCard(BannerData bannerData) {
    final offer = bannerData.item as Offer;
    final store = bannerData.store; // 💡 دلوقتي نقدر نوصل لبيانات المحل

    return GestureDetector(
      onTap: () async {
        // الكود بتاع onTap زي ما هو
        if (store == null) return;
        if (!store.isOpen) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('نأسف، المحل مغلق حالياً')),
          );
          return;
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                // ✅ السطر اللي هتعدله
                StoreItemsPage(
                  storeId: store.id,
                  storeName: store.storeName,
                  storeAddress: store.address,
                  storeRegion: store.storeRegion,
                  profitPercentage: store.profitPercentage,
                  storePhone: store.phone,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.green[400],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.2 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          image: offer.imageUrl != null && offer.imageUrl!.isNotEmpty
              ? DecorationImage(
                  image: CachedNetworkImageProvider(
                    offer.imageUrl!,
                    cacheKey:
                        offer.imageUrl!, // تأكيد استخدام نفس المفتاح للكاش
                  ),

                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withAlpha((0.4 * 255).round()),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            if (offer.imageUrl == null)
              const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 60,
                  color: Colors.white54,
                ),
              ),
            // 🚀 الكود الجديد اللي هيضيف لوجو المحل
            if (store != null && store.logoUrl.isNotEmpty)
              Positioned(
                top: 12,
                right: 12, // 💡 غيرنا دي لـ right عشان تظهر على اليمين
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: store.logoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error_outline),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (store != null)
                    Text(
                      store.storeName,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return; // تأمين لو الرابط كان فاضي

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black, // خلفية سوداء تليق بعرض الصور
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'عرض الصورة',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale:
                  PhotoViewComputedScale.covered * 2.5, // سماحية تكبير أكبر
              initialScale: PhotoViewComputedScale.contained,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) {
                if (event == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  );
                }
                return Center(
                  child: SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      value:
                          event.cumulativeBytesLoaded /
                          (event.expectedTotalBytes ??
                              event.cumulativeBytesLoaded),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .where((cat) => cat.id.isNotEmpty && cat.name.isNotEmpty)
            .toList();

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              // تعديل: بنستخدم الـID بدل الـname
              final isSelected = category.id == _selectedCategoryId;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    // تعديل: بنحفظ الـID
                    _selectedCategoryId = isSelected ? null : category.id;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.green[700]
                              : Colors.grey[200],
                          border: isSelected
                              ? Border.all(color: Colors.green, width: 3)
                              : null,
                          image: category.imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(category.imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: category.imageUrl.isEmpty
                            ? Icon(
                                Icons.category,
                                color: isSelected ? Colors.white : Colors.black,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.green[700]
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _goToCart(CartProvider cart) async {
    final firstStoreId = cart.currentStoreId;
    if (!mounted) return;

    if (firstStoreId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('السلة فارغة.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(firstStoreId)
          .get();

      if (!mounted) return;
      Navigator.of(context).pop();

      if (doc.exists) {
        final store = Store.fromFirestore(doc);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CartPage(
              storeLatitude: store.latitude,
              storeLongitude: store.longitude,
              // ✅ ضيف المتغيرات دي هنا
              storeName: store.storeName,
              storeAddress: store.address,
              storeRegion: store.storeRegion,
              profitPercentage: store.profitPercentage,
              storePhone: store.phone,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('المحل غير موجود.')));
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('حصل خطأ، حاول مرة أخرى.')));
    }
  }

  Widget _buildContent() {
    if (userLat == null || userLng == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    // 1. جلب بيانات المحلات والأصناف في نفس الوقت
    return FutureBuilder<List<dynamic>>(
      future:
          Future.wait([
            FirebaseFirestore.instance.collection('stores').get(),
            FirebaseFirestore.instance.collection('store_items').get(),
          ]).catchError((e) {
            debugPrint("Error fetching data: $e");
            return <QuerySnapshot<Map<String, dynamic>>>[];
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('عذراً، لم نتمكن من جلب البيانات حالياً.'),
          );
        }

        final storesSnapshot = snapshot.data![0] as QuerySnapshot;
        final itemsSnapshot = snapshot.data![1] as QuerySnapshot;

        final allStores = storesSnapshot.docs
            .map((doc) => Store.fromFirestore(doc))
            .where((store) => store.id.isNotEmpty)
            .toList();
        final storesMap = {for (var store in allStores) store.id: store};

        final allItems = itemsSnapshot.docs
            .map((doc) => Item.fromFirestore(doc))
            .where((item) => item.id.isNotEmpty)
            .toList();

        // ----------------------------------------------------
        // 2. الفلترة الأساسية على نطاق 10 كم (لكل الأوضاع)
        // ----------------------------------------------------

        // ✅ فلترة المحلات القريبة فقط (مفتوحة أو مغلقة) - لعرض GridView
        final nearbyStoresForGrid = allStores.where((store) {
          final distance = _calculateDistance(
            userLat!,
            userLng!,
            store.latitude,
            store.longitude,
          );
          return distance <= 7; // 🎯 النطاق الموحد 10 كم
        }).toList();

        // ✅ تحديد المحلات المفتوحة والقريبة (للفلترة على الأصناف)
        final Set<String> nearbyOpenStoreIds = allStores
            .where((store) {
              final distance = _calculateDistance(
                userLat!,
                userLng!,
                store.latitude,
                store.longitude,
              );
              // المحل لازم يكون قريب (10 كم) ومفتوح
              return distance <= 7 && store.isOpen; // 🎯 النطاق الموحد 10 كم
            })
            .map((s) => s.id)
            .toSet();

        // ✅ فلترة الأصناف بناءً على المحلات المفتوحة والقريبة فقط
        final nearbyItems = allItems.where((item) {
          return item.available && nearbyOpenStoreIds.contains(item.storeId);
        }).toList();

        // ----------------------------------------------------
        // 3. وضعية البحث
        // ----------------------------------------------------
        if (_searchQuery.isNotEmpty) {
          // فلترة المحلات: تطابق الاسم + نطاق 10 كم
          final matchingStores = allStores.where((store) {
            final distance = _calculateDistance(
              userLat!,
              userLng!,
              store.latitude,
              store.longitude,
            );
            return store.storeName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) &&
                distance <= 7;
          }).toList();

          // فلترة الأصناف: تطابق الاسم + محل في نطاق 10 كم ومفتوح (باستخدام nearbyOpenStoreIds)
          final matchingItems = allItems
              .where(
                (item) =>
                    item.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) &&
                    nearbyOpenStoreIds.contains(item.storeId),
              )
              .toList();

          // 🎯 الفرز: ترتيب الأصناف حسب القرب من العميل
          matchingItems.sort((a, b) {
            final storeA = storesMap[a.storeId];
            final storeB = storesMap[b.storeId];

            final distanceA = _calculateDistance(
              userLat!,
              userLng!,
              storeA!.latitude,
              storeA.longitude,
            );
            final distanceB = _calculateDistance(
              userLat!,
              userLng!,
              storeB!.latitude,
              storeB.longitude,
            );
            return distanceA.compareTo(distanceB);
          });

          if (matchingStores.isEmpty && matchingItems.isEmpty) {
            return const Center(
              child: Text('لا يوجد نتائج مطابقة قريبة منك   .'),
            );
          }
          return _buildResultsList(matchingStores, matchingItems, allStores);
        }
        // ----------------------------------------------------
        // 4. وضعية فلترة الأقسام
        // ----------------------------------------------------
        else if (_selectedCategoryId != null) {
          // فلترة الأصناف حسب القسم (باستخدام nearbyItems اللي هي في نطاق 10 كم ومفتوحة)
          final filteredItems = nearbyItems
              .where((item) => item.category == _selectedCategoryId)
              .toList();

          // 🎯 الفرز: ترتيب الأصناف حسب القرب من العميل
          filteredItems.sort((a, b) {
            final storeA = storesMap[a.storeId];
            final storeB = storesMap[b.storeId];

            final distanceA = _calculateDistance(
              userLat!,
              userLng!,
              storeA!.latitude,
              storeA.longitude,
            );
            final distanceB = _calculateDistance(
              userLat!,
              userLng!,
              storeB!.latitude,
              storeB.longitude,
            );
            return distanceA.compareTo(distanceB);
          });

          if (filteredItems.isEmpty) {
            return const Center(
              child: Text('لا توجد أصناف في هذا القسم قريبة منك    .'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filteredItems.length,
            itemBuilder: (_, index) {
              final item = filteredItems[index];
              final store =
                  storesMap[item.storeId] ??
                  Store(
                    id: '',
                    storeName: 'محل غير معروف',
                    storeRegion: '',
                    address: '',
                    profitPercentage: 0.0,
                    logoUrl: '',
                    latitude: 0.0,
                    longitude: 0.0,
                    averageRating: 0.0,
                    ratingsCount: 0,
                    isOpen: false,
                    phone: '',
                  );
              return _buildItemCard(context, item, store);
            },
          );
        }
        // ----------------------------------------------------
        // 5. الوضعية الافتراضية (عرض السوق)
        // ----------------------------------------------------
        else {
          // 🎯 الفرز: ترتيب المحلات القريبة من الأقرب للأبعد
          nearbyStoresForGrid.sort((a, b) {
            final distanceA = _calculateDistance(
              userLat!,
              userLng!,
              a.latitude,
              a.longitude,
            );
            final distanceB = _calculateDistance(
              userLat!,
              userLng!,
              b.latitude,
              b.longitude,
            );
            return distanceA.compareTo(distanceB);
          });

          // 🎯 رسالة الاعتذار الاحترافية
          if (nearbyStoresForGrid.isEmpty) {
            return _buildNoStoresMessage(context); // رسالة لطيفة
          }

          // عرض المحلات القريبة المفرزة في GridView
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // يجبر FutureBuilder يعيد التحميل
            },
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: nearbyStoresForGrid.length,
              itemBuilder: (_, index) {
                return _buildStoreCard(
                  nearbyStoresForGrid[index],
                  userLat!,
                  userLng!,
                );
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildResultsList(
    List<Store> matchingStores,
    List<Item> matchingItems,
    List<Store> allStores, // المحلات كلها
  ) {
    // لازم نعرف الـ storesMap تاني لو مش معرفة كـ Field في الكلاس
    final storesMap = {for (var store in allStores) store.id: store};

    // 1. فلترة الأصناف المطابقة للبحث مرة تانية عشان نتأكد إن محلها قريب ومفتوح
    final visibleItems = matchingItems.where((item) {
      final store = storesMap[item.storeId];
      // نتأكد إن المحل موجود أصلاً
      if (store == null) return false;

      // ✅ حساب المسافة والتأكد من الفتح للمحلات اللي ظهرت في نتائج البحث
      final distance = _calculateDistance(
        userLat!,
        userLng!,
        store.latitude,
        store.longitude,
      );

      return distance <= 7 && item.available && store.isOpen;
    }).toList();

    // 🎯 الخطوة الجديدة 1: فرز الأصناف من الأقرب للأبعد
    visibleItems.sort((a, b) {
      // المحلات موجودة بسبب الفلترة المسبقة
      final storeA = storesMap[a.storeId]!;
      final storeB = storesMap[b.storeId]!;

      final distanceA = _calculateDistance(
        userLat!,
        userLng!,
        storeA.latitude,
        storeA.longitude,
      );
      final distanceB = _calculateDistance(
        userLat!,
        userLng!,
        storeB.latitude,
        storeB.longitude,
      );

      return distanceA.compareTo(distanceB);
    });

    // 2. فلترة المحلات: مطابقة الاسم + نطاق 10 كم
    final visibleStores = matchingStores.where((store) {
      final distance = _calculateDistance(
        userLat!,
        userLng!,
        store.latitude,
        store.longitude,
      );
      return distance <= 7;
    }).toList();

    // 🎯 الخطوة الجديدة 2: فرز المحلات من الأقرب للأبعد
    visibleStores.sort((a, b) {
      final distanceA = _calculateDistance(
        userLat!,
        userLng!,
        a.latitude,
        a.longitude,
      );
      final distanceB = _calculateDistance(
        userLat!,
        userLng!,
        b.latitude,
        b.longitude,
      );

      return distanceA.compareTo(distanceB);
    });

    // 3. عرض النتائج المفرزة
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ------------------------------------
        // عرض المحلات المفرزة
        // ------------------------------------
        if (visibleStores.isNotEmpty)
          // عنوان لفصل المحلات
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0, top: 8.0),
            child: Text(
              'المحلات المطابقة:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ...visibleStores.map((store) {
          if (userLat == null || userLng == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildStoreCard(store, userLat!, userLng!),
          );
        }),

        // ------------------------------------
        // عرض الأصناف المفرزة
        // ------------------------------------
        if (visibleItems.isNotEmpty)
          // عنوان لفصل الأصناف
          Padding(
            padding: EdgeInsets.only(
              bottom: 8.0,
              top: visibleStores.isNotEmpty
                  ? 20.0
                  : 8.0, // لو فيه محلات، نزود مسافة فاصلة
            ),
            child: const Text(
              'الأصناف المطابقة:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ...visibleItems.map((item) {
          final store =
              storesMap[item.storeId] ??
              Store(
                id: '',
                storeName: 'محل غير معروف',
                storeRegion: '',
                address: '',
                profitPercentage: 0.0,
                logoUrl: '',
                // لازم تكمل باقي الـ fields
                latitude: 0.0,
                longitude: 0.0,
                averageRating: 0.0,
                ratingsCount: 0,
                isOpen: false,
                phone: '',
              );
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildItemCard(context, item, store),
          );
        }),
      ],
    );
  }

  Widget _buildStoreCard(Store store, double userLat, double userLng) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!store.isOpen) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('نأسف، المحل مغلق حالياً'),
                duration: Duration(seconds: 2),
              ),
            );
            return; // يمنع التنقل
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  // ✅ السطر اللي هتعدله
                  StoreItemsPage(
                    storeId: store.id,
                    storeName: store.storeName,
                    storeAddress: store.address,
                    storeRegion: store.storeRegion,
                    profitPercentage: store.profitPercentage,
                    storePhone: store.phone,
                  ),
            ),
          );
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // الصورة + Banner الحالة
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: store.logoUrl.isNotEmpty
                      ? Image.network(
                          store.logoUrl,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.store, size: 60),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 120,
                          color: Colors.grey[200],
                          child: const Icon(Icons.store, size: 60),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: store.isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      store.isOpen ? "مفتوح" : "مغلق",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المحل
                  Text(
                    store.storeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // المنطقة + المسافة
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        // بدل Expanded
                        child: Text(
                          "${store.storeRegion} - ${_calculateDistance(userLat, userLng, store.latitude, store.longitude).toStringAsFixed(1)} كم",
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // التقييم
                  if (store.ratingsCount > 0)
                    Row(
                      children: [
                        _buildRatingStars(store.averageRating),
                        const SizedBox(width: 4),
                        Text(
                          store.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          // بدل Expanded
                          child: Text(
                            "(${store.ratingsCount})",
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة حساب المسافة بالكيلومتر
  double _calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double radiusEarth = 6371;
    final double dLat = _degToRad(endLat - startLat);
    final double dLng = _degToRad(endLng - startLng);
    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(startLat)) *
            cos(_degToRad(endLat)) *
            (sin(dLng / 2) * sin(dLng / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radiusEarth * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  Widget _buildRatingStars(double rating) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    int emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);
    List<Widget> stars = [];
    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, color: Colors.amber, size: 16));
    }
    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 16));
    }
    for (int i = 0; i < emptyStars; i++) {
      stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 16));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  Widget _buildItemCard(BuildContext context, Item item, Store store) {
    final cart = context.read<CartProvider>();
    final img = item.image.isNotEmpty ? item.image.first : '';
    bool isExpanded = false; // متغير فتح/غلق التفاصيل
    int selectedSizeIndex = item.sizes.isNotEmpty ? 0 : -1;
    final Set<int> selectedAddons = {};
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      shadowColor: Colors.green.withAlpha((0.5 * 255).toInt()),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: StatefulBuilder(
          builder: (context, setStateCard) {
            double applyProfit(double basePrice, double profitPercentage) {
              return basePrice * (1 + profitPercentage);
            }

            double selectedBasePrice() => selectedSizeIndex >= 0
                ? applyProfit(
                    item.sizes[selectedSizeIndex].price,
                    store.profitPercentage,
                  )
                : applyProfit(item.price, store.profitPercentage);

            double addonsSum() => selectedAddons.fold(
              0.0,
              (s, i) =>
                  s + applyProfit(item.addons[i].price, store.profitPercentage),
            );

            double totalPrice() => selectedBasePrice() + addonsSum();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (img.isNotEmpty) {
                      _showFullScreenImage(context, img);
                    } else {
                      setStateCard(() {
                        isExpanded = !isExpanded;
                      });
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: img.isNotEmpty
                        ? Image.network(
                            img, // هذا هو الرابط
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 140,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.fastfood,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            height: 140,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.fastfood,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'من محل: ${store.storeName}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),

                // تفاصيل الأحجام والإضافات تظهر فقط لو Expanded
                if (item.sizes.isNotEmpty) ...[
                  const Text(
                    'الأحجام:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: List.generate(item.sizes.length, (i) {
                      final s = item.sizes[i];
                      return ChoiceChip(
                        label: Text(
                          '${s.name}  ${applyProfit(s.price, store.profitPercentage).toStringAsFixed(2)} ${item.priceUnit ?? ''}',
                        ),
                        selected: selectedSizeIndex == i,
                        onSelected: (_) =>
                            setStateCard(() => selectedSizeIndex = i),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                if (item.addons.isNotEmpty) ...[
                  const Text(
                    'الإضافات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: List.generate(item.addons.length, (i) {
                      final a = item.addons[i];
                      return FilterChip(
                        label: Text(
                          '${a.name} +${applyProfit(a.price, store.profitPercentage).toStringAsFixed(2)}',
                        ),
                        selected: selectedAddons.contains(i),
                        onSelected: (sel) => setStateCard(() {
                          if (sel) {
                            selectedAddons.add(i);
                          } else {
                            selectedAddons.remove(i);
                          }
                        }),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                // السعر النهائي
                Text(
                  'السعر: ${totalPrice().toStringAsFixed(2)} ${item.priceUnit ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                // زر إضافة للسلة
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // باقي كود إضافة السلة زي ما هو تمامًا
                      if (cart.currentStoreId != null &&
                          cart.currentStoreId != item.storeId) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('السلة ليست فارغة'),
                              content: const Text(
                                'لا يمكن إضافة منتجات من محلين مختلفين. هل تريد مسح السلة الحالية وإضافة هذا المنتج؟',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('إلغاء'),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                TextButton(
                                  child: const Text('نعم، مسح السلة'),
                                  onPressed: () {
                                    cart.clearCart();
                                    Navigator.of(context).pop();

                                    final selectedAddonsData = selectedAddons
                                        .map(
                                          (i) => {
                                            'name': item.addons[i].name,
                                            'price': applyProfit(
                                              item.addons[i].price,
                                              store.profitPercentage,
                                            ),
                                          },
                                        )
                                        .toList();

                                    final cartItem = CartItem(
                                      id: item.id,
                                      name: item.name,
                                      price: totalPrice(),
                                      imageUrl: img,
                                      storeId: item.storeId,
                                      size: selectedSizeIndex >= 0
                                          ? item.sizes[selectedSizeIndex].name
                                          : null,
                                      addons: selectedAddonsData,
                                      quantity: 1,
                                    );
                                    cart.addItem(cartItem);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '✅ تمت إضافة المنتج إلى السلة بنجاح!',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        final selectedAddonsData = selectedAddons
                            .map(
                              (i) => {
                                'name': item.addons[i].name,
                                'price': applyProfit(
                                  item.addons[i].price,
                                  store.profitPercentage,
                                ),
                              },
                            )
                            .toList();

                        final cartItem = CartItem(
                          id: item.id,
                          name: item.name,
                          price: totalPrice(),
                          imageUrl: img,
                          storeId: item.storeId,
                          size: selectedSizeIndex >= 0
                              ? item.sizes[selectedSizeIndex].name
                              : null,
                          addons: selectedAddonsData,
                          quantity: 1,
                        );
                        cart.addItem(cartItem);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✅ تمت إضافة المنتج إلى السلة بنجاح!',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('أضف للسلة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700], // لون الخلفية
                      foregroundColor: Colors.white, // لون النص والآيقونة
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
