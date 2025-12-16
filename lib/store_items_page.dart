// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'cart_page.dart';
import '../services/cart_provider.dart';

class StoreItemsPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String storeAddress;
  final String storeRegion;
  final double profitPercentage;
  final String storePhone;

  const StoreItemsPage({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    required this.storeRegion,
    required this.profitPercentage,
    required this.storePhone,
  });

  @override
  State<StoreItemsPage> createState() => _StoreItemsPageState();
}

class _StoreItemsPageState extends State<StoreItemsPage> {
  // Maps kept at parent level (no setState when children update them)
  final Map<String, String?> _selectedSizes = {};
  final Map<String, List<Map<String, dynamic>>> _selectedAddons = {};
  final Map<String, double> _itemTotalPrices = {};
  final Map<String, bool> _expandedItems = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // kept as before, used by children via callback
  double _calculateItemPrice(
    String itemId,
    double basePrice,
    List<Map<String, dynamic>> sizes,
    List<Map<String, dynamic>> addons,
  ) {
    double adjustedBasePrice = basePrice * (1 + widget.profitPercentage);

    if (_selectedSizes[itemId] != null && sizes.isNotEmpty) {
      final selectedSizeData = sizes.firstWhere(
        (s) => s['name'] == _selectedSizes[itemId],
        orElse: () => {'price': basePrice},
      );
      double sizePrice = 0.0;
      if (selectedSizeData['price'] is num) {
        sizePrice = (selectedSizeData['price'] as num).toDouble();
      } else {
        sizePrice =
            double.tryParse(selectedSizeData['price']?.toString() ?? '') ?? 0.0;
      }
      adjustedBasePrice = sizePrice * (1 + widget.profitPercentage);
    }

    final addonsList = _selectedAddons[itemId] ?? [];
    final addonsPrice = addonsList.fold(0.0, (total, addon) {
      final priceValue = (addon['price'] is num)
          ? (addon['price'] as num).toDouble()
          : double.tryParse(addon['price']?.toString() ?? '') ?? 0.0;
      return total + priceValue * (1 + widget.profitPercentage);
    });

    return adjustedBasePrice + addonsPrice;
  }

  // image zoomer kept
  void _showZoomableImage(String imageUrl, String itemName) {
    if (imageUrl.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black.withAlpha(217),
            appBar: AppBar(
              title: Text(
                itemName,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 4.0,
                clipBehavior: Clip.none,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 245, 57, 0), // برتقالي غامق
                Color.fromARGB(255, 250, 65, 52), // برتقالي فاتح
                Color.fromARGB(255, 241, 95, 69), // برتقالي غامق
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          widget.storeName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 245, 57, 0), // برتقالي غامق
              Color.fromARGB(255, 250, 65, 52), // برتقالي فاتح
              Color.fromARGB(255, 241, 95, 69), // برتقالي غامق
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن صنف...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // items list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('store_items')
                    .where('store_id', isEqualTo: widget.storeId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fastfood, size: 80, color: Colors.grey),
                            SizedBox(height: 20),
                            Text(
                              'لا توجد أصناف متاحة في هذا المتجر حاليًا.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = snap.data!.docs
                      .map(
                        (doc) => {
                          ...(doc.data() as Map<String, dynamic>),
                          'id': doc.id,
                        },
                      )
                      .toList();

                  final filteredDocs = docs.where((data) {
                    final itemName =
                        data['name']?.toString().toLowerCase() ?? '';
                    return _searchQuery.isEmpty ||
                        itemName.contains(_searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد نتائج بحث مطابقة.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    key: const PageStorageKey('store_items_list'),
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index];
                      final itemId = data['id']?.toString() ?? '';

                      if (!(data['available'] ?? true)) {
                        return const SizedBox.shrink();
                      }

                      // ensure parent maps have entries
                      _selectedSizes.putIfAbsent(itemId, () => null);
                      _selectedAddons.putIfAbsent(itemId, () => []);
                      _expandedItems.putIfAbsent(itemId, () => false);

                      final sizes = (data['sizes'] is List)
                          ? List<Map<String, dynamic>>.from(data['sizes'])
                          : <Map<String, dynamic>>[];
                      final addons = (data['addons'] is List)
                          ? List<Map<String, dynamic>>.from(data['addons'])
                          : <Map<String, dynamic>>[];
                      final img = data['image']?.toString() ?? '';
                      final basePrice = (data['price'] is num)
                          ? (data['price'] as num).toDouble()
                          : double.tryParse(data['price']?.toString() ?? '') ??
                                0.0;

                      // set initial totalPrice in parent map (children will update it when selection changes)
                      final initialPrice = _calculateItemPrice(
                        itemId,
                        basePrice,
                        sizes,
                        addons,
                      );
                      _itemTotalPrices[itemId] = initialPrice;

                      // Return the separated card widget
                      return StoreItemCard(
                        key: ValueKey(itemId),
                        itemId: itemId,
                        data: data,
                        img: img,
                        basePrice: basePrice,
                        sizes: sizes,
                        addons: addons,
                        profitPercentage: widget.profitPercentage,
                        // references to parent maps (children update them directly; parent doesn't call setState)
                        parentSelectedSizes: _selectedSizes,
                        parentSelectedAddons: _selectedAddons,
                        parentItemTotalPrices: _itemTotalPrices,
                        calculatePriceCallback: _calculateItemPrice,
                        showZoomableImage: _showZoomableImage,
                        storeId: widget.storeId,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // floating cart button
      floatingActionButton: Builder(
        builder: (context) {
          final cart = Provider.of<CartProvider>(context);
          return cart.itemCount > 0
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final firstStoreId = cart.currentStoreId;
                    if (firstStoreId == null) return;

                    final doc = await FirebaseFirestore.instance
                        .collection('stores')
                        .doc(firstStoreId)
                        .get();

                    if (!mounted) return;
                    final data = doc.data();
                    double storeLat = 0.0;
                    double storeLng = 0.0;

                    if (data?['location'] != null) {
                      final location =
                          data!['location'] as Map<String, dynamic>;
                      storeLat = (location['lat'] ?? 0.0).toDouble();
                      storeLng = (location['lng'] ?? 0.0).toDouble();
                    }

                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartPage(
                          storeLatitude: storeLat,
                          storeLongitude: storeLng,
                          storeName: widget.storeName,
                          storeAddress: widget.storeAddress,
                          storeRegion: widget.storeRegion,
                          profitPercentage: widget.profitPercentage,
                          storePhone: widget.storePhone,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  label: Text(
                    'السلة (${cart.itemCount}) - ${cart.totalAmount.toStringAsFixed(2)} جنيه',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color.fromARGB(255, 47, 161, 57),
                )
              : const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

///
/// منفصل: كارت المنتج المستقل. كل حالة داخله لا تؤثر على إعادة بناء الصفحة الأم.
///
class StoreItemCard extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> data;
  final String img;
  final double basePrice;
  final List<Map<String, dynamic>> sizes;
  final List<Map<String, dynamic>> addons;
  final double profitPercentage;
  final Map<String, String?> parentSelectedSizes;
  final Map<String, List<Map<String, dynamic>>> parentSelectedAddons;
  final Map<String, double> parentItemTotalPrices;
  final double Function(
    String,
    double,
    List<Map<String, dynamic>>,
    List<Map<String, dynamic>>,
  )
  calculatePriceCallback;
  final void Function(String, String) showZoomableImage;
  final String storeId;

  const StoreItemCard({
    super.key,
    required this.itemId,
    required this.data,
    required this.img,
    required this.basePrice,
    required this.sizes,
    required this.addons,
    required this.profitPercentage,
    required this.parentSelectedSizes,
    required this.parentSelectedAddons,
    required this.parentItemTotalPrices,
    required this.calculatePriceCallback,
    required this.showZoomableImage,
    required this.storeId,
  });

  @override
  State<StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends State<StoreItemCard> {
  bool _expanded = false;
  String? _localSelectedSize;
  late List<Map<String, dynamic>> _localSelectedAddons;
  late double _currentTotalPrice;

  @override
  void initState() {
    super.initState();
    // initialize local selections from parent maps (if any)
    _localSelectedSize = widget.parentSelectedSizes[widget.itemId];
    _localSelectedAddons = List<Map<String, dynamic>>.from(
      widget.parentSelectedAddons[widget.itemId] ?? [],
    );
    _currentTotalPrice = widget.calculatePriceCallback(
      widget.itemId,
      widget.basePrice,
      widget.sizes,
      widget.addons,
    );
    // keep parent map price in sync initially
    widget.parentItemTotalPrices[widget.itemId] = _currentTotalPrice;
  }

  void _updatePriceAndParent() {
    // write local selections into parent maps WITHOUT calling parent setState
    widget.parentSelectedSizes[widget.itemId] = _localSelectedSize;
    widget.parentSelectedAddons[widget.itemId] =
        List<Map<String, dynamic>>.from(_localSelectedAddons);

    // recalc price using parent's calculation function
    final newPrice = widget.calculatePriceCallback(
      widget.itemId,
      widget.basePrice,
      widget.sizes,
      widget.addons,
    );

    _currentTotalPrice = newPrice;
    widget.parentItemTotalPrices[widget.itemId] = newPrice;
  }

  void _onSelectSize(String sizeName) {
    setState(() {
      _localSelectedSize = sizeName;
      _updatePriceAndParent();
    });
  }

  void _onToggleAddon(String addonName, double addonPrice) {
    setState(() {
      final exists = _localSelectedAddons.any((a) => a['name'] == addonName);
      if (exists) {
        _localSelectedAddons.removeWhere((a) => a['name'] == addonName);
      } else {
        _localSelectedAddons.add({'name': addonName, 'price': addonPrice});
      }
      _updatePriceAndParent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final itemName = widget.data['name']?.toString() ?? 'منتج بدون اسم';

    return Card(
      key: widget.key,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_expanded ? 1.02 : 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: ListTile(
                leading: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.showZoomableImage(widget.img, itemName),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedScale(
                      scale: _expanded ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: widget.img.isNotEmpty
                          ? Image.network(
                              widget.img,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.fastfood,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                ),
                title: Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'السعر : ${_currentTotalPrice.toStringAsFixed(2)} جنيه',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 235, 14, 7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween(
                  begin: const Offset(0, -0.05),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: _expanded
                  ? Padding(
                      key: ValueKey('${widget.itemId}_expanded'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((widget.data['description']?.toString() ?? '')
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                widget.data['description']!.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          // sizes
                          if (widget.sizes.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'اختر الحجم:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: widget.sizes.map((s) {
                                    final sizeName =
                                        s['name']?.toString() ?? '';
                                    final sizePrice = (s['price'] is num)
                                        ? (s['price'] as num).toDouble()
                                        : double.tryParse(
                                                s['price']?.toString() ?? '',
                                              ) ??
                                              0.0;
                                    final finalPrice =
                                        (sizePrice *
                                                (1 + widget.profitPercentage))
                                            .toStringAsFixed(2);
                                    final isSelected =
                                        _localSelectedSize == sizeName;

                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                      transform: Matrix4.identity()
                                        ..scale(isSelected ? 1.08 : 1.0),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color.fromARGB(
                                                255,
                                                184,
                                                143,
                                                153,
                                              )
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color.fromARGB(
                                                    255,
                                                    165,
                                                    119,
                                                    130,
                                                  ).withValues(alpha: 0.4),

                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _onSelectSize(sizeName),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            '$sizeName ($finalPrice ج)',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),

                          // addons
                          if (widget.addons.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                const Text(
                                  'اختر الإضافات:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                ...widget.addons.map((a) {
                                  final addonName = a['name']?.toString() ?? '';
                                  final addonPrice = (a['price'] is num)
                                      ? (a['price'] as num).toDouble()
                                      : double.tryParse(
                                              a['price']?.toString() ?? '',
                                            ) ??
                                            0.0;
                                  final isSelected = _localSelectedAddons.any(
                                    (addon) => addon['name'] == addonName,
                                  );

                                  return CheckboxListTile(
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      '$addonName (${(addonPrice * (1 + widget.profitPercentage)).toStringAsFixed(2)}جنيه)',
                                    ),
                                    value: isSelected,
                                    onChanged: (_) =>
                                        _onToggleAddon(addonName, addonPrice),
                                  );
                                }),
                              ],
                            ),

                          // add to cart button
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'أضف إلى السلة',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    5,
                                    126,
                                    35,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  if (widget.sizes.isNotEmpty &&
                                      (_localSelectedSize == null ||
                                          _localSelectedSize!.isEmpty)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '❗ من فضلك اختر الحجم أولاً',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  final selectedAddonsCopy =
                                      _localSelectedAddons
                                          .map(
                                            (addon) =>
                                                Map<String, dynamic>.from(
                                                  addon,
                                                ),
                                          )
                                          .toList();
                                  final selectedSizeCopy = _localSelectedSize;

                                  final cartItem = CartItem(
                                    id: widget.itemId,
                                    name:
                                        widget.data['name']?.toString() ??
                                        'منتج بدون اسم',
                                    price: _currentTotalPrice,
                                    imageUrl: widget.img,
                                    storeId: widget.storeId,
                                    size: selectedSizeCopy,
                                    addons: selectedAddonsCopy,
                                  );

                                  if (cart.itemCount > 0 &&
                                      cart.currentStoreId != widget.storeId) {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("تغيير المتجر"),
                                        content: const Text(
                                          "السلة تحتوي على منتجات من متجر آخر.\nهل تريد مسح السلة وإضافة هذا المنتج؟",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text("إلغاء"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text(
                                              "نعم، امسح السلة",
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    cart.clearCart();
                                  }

                                  cart.addItem(cartItem);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ تمت إضافة المنتج إلى السلة',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
