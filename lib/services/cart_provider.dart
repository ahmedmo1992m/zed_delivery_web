import 'package:flutter/material.dart';

// صنف يمثل منتج في السلة مع الكمية
class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String storeId;
  final String? size;
  final List<Map<String, dynamic>>? addons;
  int quantity;
  final String uniqueId; // ✨ السطر الجديد

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.storeId,
    this.size,
    this.addons,
    this.quantity = 1,
  }) : uniqueId = _generateUniqueId(id, size, addons);

  // ✨ الدالة الجديدة اللي بتولّد مفتاح فريد
  static String _generateUniqueId(
    String itemId,
    String? size,
    List<Map<String, dynamic>>? addons,
  ) {
    String addonString = addons != null
        ? addons.map((a) => a['name']).join(',')
        : '';
    return '$itemId-${size ?? ''}-$addonString';
  }
}

// مزود البيانات للسلة
// تعديل كلاس CartProvider
class CartProvider with ChangeNotifier {
  // 💡 تغيير نوع المفتاح عشان يستقبل الـ uniqueId
  final Map<String, CartItem> _items = {};
  String? _currentStoreId;

  Map<String, CartItem> get items => {..._items};

  // 💡 هنا هنعدل الـ fold عشان يحسب الإجمالي من الكميات الفردية
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0, (sum, item) => sum + (item.price * item.quantity));

  String? get currentStoreId => _currentStoreId;

  void addItem(CartItem item) {
    // لو المنتج من متجر مختلف، امسح السلة
    if (_currentStoreId != null && _currentStoreId != item.storeId) {
      _items.clear();
      _currentStoreId = item.storeId;
    }

    // 💡 استخدام uniqueId بدل id
    if (_items.containsKey(item.uniqueId)) {
      _items.update(
        item.uniqueId,
        (existingItem) => CartItem(
          id: existingItem.id,
          name: existingItem.name,
          price: existingItem.price,
          imageUrl: existingItem.imageUrl,
          storeId: existingItem.storeId,
          size: existingItem.size,
          addons: existingItem.addons,
          quantity: existingItem.quantity + 1,
        ),
      );
    } else {
      _items[item.uniqueId] = item;
      _currentStoreId = item.storeId;
    }
    notifyListeners();
  }

  void removeItem(String uniqueId) {
    // 💡 تغيير المتغير إلى uniqueId
    _items.remove(uniqueId);
    if (_items.isEmpty) {
      _currentStoreId = null;
    }
    notifyListeners();
  }

  void updateQuantity(String uniqueId, int newQuantity) {
    // 💡 تغيير المتغير إلى uniqueId
    if (_items.containsKey(uniqueId)) {
      if (newQuantity > 0) {
        _items.update(
          uniqueId,
          (existingItem) => CartItem(
            id: existingItem.id,
            name: existingItem.name,
            price: existingItem.price,
            imageUrl: existingItem.imageUrl,
            storeId: existingItem.storeId,
            size: existingItem.size,
            addons: existingItem.addons,
            quantity: newQuantity,
          ),
        );
      } else {
        removeItem(uniqueId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _currentStoreId = null;
    notifyListeners();
  }
}
