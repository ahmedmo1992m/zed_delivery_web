// ignore_for_file: use_build_context_synchronously
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:zed/pages/client_auth_screen.dart';

import 'dart:async'; // تم إضافة الاستيراد ده للـ Timer
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // لإجراء المكالمات
import 'privacy_policy_page.dart';
import 'add_items_page.dart'; // لو في نفس المجلد
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:badges/badges.dart' as badges;
import 'package:zed/store_orders_page.dart';
import 'package:audioplayers/audioplayers.dart'; // استيراد مكتبة audioplayers
import 'add_offer_page.dart'; // تأكد إن المسار صحيح بالنسبة لمجلد lib

class _EditableField extends StatefulWidget {
  final String initialValue;
  final String label;
  final Function(String) onSave;
  final TextInputType keyboardType;
  final bool isLoading;
  final double fontSize;
  final FontWeight fontWeight;

  const _EditableField({
    required this.initialValue,
    required this.label,
    required this.onSave,
    this.keyboardType = TextInputType.text,
    required this.isLoading,
    this.fontSize = 22,
    this.fontWeight = FontWeight.bold,
  });

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _EditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_isEditing) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _toggleEdit(context);
    }
  }

  void _toggleEdit(BuildContext context) {
    if (_isEditing) {
      if (_controller.text.trim() != widget.initialValue.trim() &&
          _controller.text.trim().isNotEmpty) {
        widget.onSave(_controller.text.trim());
      }
    }
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        FocusScope.of(context).requestFocus(_focusNode);
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: widget.isLoading ? null : () => _toggleEdit(context),
          icon: widget.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                )
              : Icon(
                  _isEditing ? Icons.check_circle : Icons.edit,
                  color: Colors.white70,
                  size: 20,
                ),
        ),
        Expanded(
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            readOnly: !_isEditing,
            enabled: !widget.isLoading,
            keyboardType: widget.keyboardType,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
              color: _isEditing ? Colors.white : Colors.white70,
            ),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: widget.label,
              border: InputBorder.none,
              fillColor: _isEditing
                  ? Colors.white.withAlpha((0.1 * 255).round())
                  : Colors.transparent,
              filled: _isEditing,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
            ),
            onFieldSubmitted: (val) => _toggleEdit(context),
          ),
        ),
      ],
    );
  }
}

// Custom widget للعداد التنازلي لكل طلب
class OrderCountdownWidget extends StatefulWidget {
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String status;

  const OrderCountdownWidget({
    super.key,
    required this.createdAt,
    this.acceptedAt,
    required this.status,
  });

  @override
  State<OrderCountdownWidget> createState() => _OrderCountdownWidgetState();
}

class _OrderCountdownWidgetState extends State<OrderCountdownWidget> {
  Duration _remainingTime = Duration.zero;
  Timer? _timer;
  String _displayText = '';
  double _progress = 1.0; // للـ CircularProgressIndicator

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant OrderCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // لو أي بيانات للأوردر اتغيرت، بنعيد تشغيل العداد
    if (widget.createdAt != oldWidget.createdAt ||
        widget.acceptedAt != oldWidget.acceptedAt ||
        widget.status != oldWidget.status) {
      _timer?.cancel(); // بنوقف العداد القديم
      _startTimer(); // بنشغل عداد جديد
    }
  }

  void _startTimer() {
    // بنشغل العداد بس لو الأوردر لسه في حالة 'pending' أو 'accepted'
    if (widget.status == 'pending' || widget.status == 'accepted') {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel(); // بنلغي العداد لو الـ widget مش موجودة في الشجرة
          return;
        }
        _updateCountdown(); // بنحدث الوقت كل ثانية
      });
      _updateCountdown(); // بنحدث الوقت أول ما العداد يبدأ عشان يظهر على طول
    } else {
      _updateDisplayForFinalStatus(); // لو حالة الأوردر نهائية (زي تم التسليم)، بنعرض الرسالة المناسبة
    }
  }

  void _updateCountdown() {
    final now = DateTime.now();
    DateTime startTime;
    Duration totalDuration;

    if (widget.status == 'pending') {
      startTime = widget.createdAt;
      totalDuration = const Duration(minutes: 5); // 5 دقائق للقبول
      _displayText = 'لللقبول: ';
    } else if (widget.status == 'accepted' && widget.acceptedAt != null) {
      startTime = widget.acceptedAt!;
      totalDuration = const Duration(minutes: 25); // 25 دقيقة للتسليم
      _displayText = 'للتسليم: ';
    } else {
      // حالة مش متوقعة، بنوقف العداد
      _timer?.cancel();
      _displayText = 'انتهى';
      _progress = 0.0;
      setState(() {});
      return;
    }

    final endTime = startTime.add(totalDuration);
    if (now.isBefore(endTime)) {
      _remainingTime = endTime.difference(now);
      // بنحسب التقدم عشان الدايرة تقل تدريجيًا
      _progress = _remainingTime.inSeconds / totalDuration.inSeconds;
      setState(() {
        _displayText +=
            '${_remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      });
    } else {
      _timer?.cancel(); // بنوقف العداد لو الوقت خلص
      _displayText = 'انتهى';
      _progress = 0.0;
      setState(() {});
    }
  }

  void _updateDisplayForFinalStatus() {
    if (widget.status == 'completed') {
      _displayText = 'تم التسليم';
      _progress = 0.0;
    } else if (widget.status == 'rejected' || widget.status == 'cancelled') {
      _displayText = 'انتهى';
      _progress = 0.0;
    } else {
      // أي حالة تانية مش بتعد
      _displayText = 'انتهى';
      _progress = 0.0;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer
        ?.cancel(); // مهم جدًا نلغي العداد لما الـ widget تختفي عشان ما يحصلش مشاكل
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color countdownColor;
    Color progressColor;
    Widget leadingIcon;

    if (widget.status == 'pending') {
      countdownColor = Colors.orange;
      progressColor = Colors.orange;
      leadingIcon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: _progress,
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            _remainingTime.inSeconds <= 60 ? Colors.red : progressColor,
          ),
          backgroundColor: Colors.orange.shade100,
        ),
      );
    } else if (widget.status == 'accepted') {
      countdownColor = Colors.blueAccent;
      progressColor = Colors.blueAccent;
      leadingIcon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: _progress,
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            _remainingTime.inSeconds <= 60 ? Colors.red : progressColor,
          ),
          backgroundColor: Colors.blue.shade100,
        ),
      );
    } else if (widget.status == 'completed') {
      countdownColor = Colors.green;
      leadingIcon = const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 20,
      ); // أيقونة ✅
    } else {
      // 'rejected', 'cancelled' أو أي حالة أخرى غير نشطة
      countdownColor = Colors.grey;
      leadingIcon = const Icon(
        Icons.info_outline,
        color: Colors.grey,
        size: 20,
      ); // أيقونة معلومات
    }

    // هنا بنعرض العداد أو الحالة النهائية
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leadingIcon,
        const SizedBox(width: 8),
        Text(
          _displayText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: countdownColor,
          ),
        ),
      ],
    );
  }
}

class OrderPage extends StatefulWidget {
  final String storeName;
  final String address;
  final String phone; // <-- هنستخدمه كـ storeId
  final String storeRegion;
  final bool isGuest;
  final String storeId; // <-- أضف هذا
  final String? storeLogo; // ← هذا للوجو
  final double lat; // أضف السطر ده
  final double lng; // أضف السطر ده
  final double averageRating; // 🔔 أضف السطر ده
  final String createdAt; // 🔔 أضف السطر ده
  final bool isOpen; // 🔔 أضف السطر ده
  final String logoUrl; // 🔔 أضف السطر ده
  final double totalRating;
  const OrderPage({
    super.key,
    required this.storeId, // <--- مهم

    required this.storeName,
    required this.address,
    required this.phone,
    required this.storeRegion,
    this.storeLogo, // ← تضيف هنا
    required this.lat, // أضف السطر ده
    required this.lng, // أضف السطر ده
    required this.averageRating, // 🔔 أضف السطر ده
    required this.createdAt, // 🔔 أضف السطر ده
    required this.isOpen, // 🔔 أضف السطر ده
    required this.logoUrl, // 🔔 أضف السطر ده
    required this.totalRating, // 🔔 أضف السطر ده

    this.isGuest = false,
  });

  @override
  OrderPageState createState() => OrderPageState();
}

class OrderPageState extends State<OrderPage> {
  File? _storeLogoFile; // ملف الصورة بعد اختيارها
  final ImagePicker picker = ImagePicker();
  final _audioPlayer = AudioPlayer();
  int _previousOrdersCount = 0;
  bool isChatActive = false;
  bool _isStoreOpen = false; // هنا عرفنا المتغير

  @override
  void initState() {
    super.initState();
    _isStoreOpen = widget.isOpen; // نهيئه من قيمة المحل الحالية

    // ... الكود اللي كان موجود في initState
    _setupOrdersStream(); // ضيف السطر ده
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupOrdersStream() {
    FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
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

  Future<bool> _checkInternetConnection() async {
    // هتعمل Check على حالة الاتصال
    final connectivityResult = await (Connectivity().checkConnectivity());

    // لو أي نتيجة في القائمة مش (none) يبقى فيه اتصال
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet) ||
        connectivityResult.contains(ConnectivityResult.vpn) ||
        connectivityResult.contains(ConnectivityResult.bluetooth)) {
      return true;
    } else {
      return false; // لا يوجد اتصال
    }
  }

  Future<void> _playOrderSound() async {
    await _audioPlayer.play(AssetSource('sounds/new_order_sound.mp3'));
  }

  static const String imagekitPublicKey = 'public_DdZaQNVPnIkcdTeeu+GlqFVn1hM=';
  static const String imagekitUploadUrl =
      'https://upload.imagekit.io/api/v1/files/upload';
  static const String imagekitFolder = '/stores_logos';
  static const String imagekitPrivateKey =
      'private_XVb2nRDWt1k6eOf1UB306WjwIoY='; // **ده للتجربة فقط**

  Future<void> uploadLogoToImageKit() async {
    if (_storeLogoFile == null) return;

    try {
      final uri = Uri.parse(OrderPageState.imagekitUploadUrl);
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] =
          'Basic ${base64.encode(utf8.encode('${OrderPageState.imagekitPrivateKey}:'))}';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _storeLogoFile!.path,
          filename: _storeLogoFile!.path.split('/').last,
        ),
      );

      request.fields['publicKey'] = OrderPageState.imagekitPublicKey;
      request.fields['fileName'] = _storeLogoFile!.path.split('/').last;
      request.fields['folder'] = OrderPageState.imagekitFolder;

      final streamedResponse = await request.send();
      final resp = await http.Response.fromStream(streamedResponse);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(resp.body);
        final imageUrl = data['url'] as String?;
        if (imageUrl != null) {
          setState(() {});
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(widget.storeId) // استخدام storeId الصحيح
              .update({'logoUrl': imageUrl});

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('تم رفع لوجو المحل.')));
          }
        } else {
          throw Exception('رفع فشل: لم يرجع رابط الصورة.');
        }
      } else {
        throw Exception('خطأ أثناء الرفع: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع اللوجو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {}
  }

  bool isSending = false;
  final ordersCountController = TextEditingController();
  List<TextEditingController> destinationControllers = [];
  List<TextEditingController> priceControllers = [];

  // 💡 متغيرات لتخزين الموقع الحالي للمحل
  double? _currentLatitude;
  double? _currentLongitude;

  // ====== NEW: Helpers للربح/المدالية/المعرف ======
  String get _storeDocId => widget.storeId; // 👈 استبدله بالسطر ده

  String _medalForCount(int count) {
    if (count >= 100) return "🥇";
    if (count >= 50) return "🥈";
    if (count >= 1) return "🥉";
    return "⏳";
  }
  // ===============================================

  // --- وظائف عامة ---

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ClientAuthScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تسجيل الخروج: $e')));
    }
  }

  // --- وظائف حقول الإدخال والتحقق ---

  void generateFields() {
    int count = int.tryParse(ordersCountController.text.trim()) ?? 0;
    if (count == destinationControllers.length) {
      return;
    }
    for (var controller in destinationControllers) {
      controller.dispose();
    }
    for (var controller in priceControllers) {
      controller.dispose();
    }
    destinationControllers = List.generate(count, (index) {
      final controller = TextEditingController();
      controller.addListener(() {
        _updatePriceForDestination(controller.text, index);
      });
      return controller;
    });
    priceControllers = List.generate(count, (_) => TextEditingController());
    setState(() {});
  }

  void _updatePriceForDestination(String destinationAddress, int index) {
    if (destinationAddress.isEmpty) {
      priceControllers[index].text = '';
      setState(() {});
    }
  }

  // --- وظائف الطلبات (المعاينة، الإرسال، الحساب) ---

  Future<void> previewOrder() async {
    List<Map<String, String>> orders = [];
    for (int i = 0; i < destinationControllers.length; i++) {
      orders.add({
        'destination': destinationControllers[i].text.trim(),
        'price': priceControllers[i].text.trim(),
      });
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'معاينة الطلب',
          style: TextStyle(color: Colors.lightBlue),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اسم المحل: ${widget.storeName}'),
              Text('العنوان: ${widget.address}'),
              Text('المنطقة: ${widget.storeRegion}'),
              Text('الهاتف: ${widget.phone}'),
              if (_currentLatitude != null && _currentLongitude != null)
                Text(
                  'موقع المحل: ${_currentLatitude!.toStringAsFixed(4)}, ${_currentLongitude!.toStringAsFixed(4)}',
                )
              else
                const Text('موقع المحل: غير متاح حالياً'),
              const SizedBox(height: 10),
              const Text(
                'تفاصيل الطلب:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...orders.map(
                (e) => Text(
                  '    - الى: ${e['destination']} - السعر: ${e['price']} جنيه',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(color: Colors.lightBlue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sendOrder() async {
    // 1. التحقق من وجود اتصال بالإنترنت
    // التحقق من وجود اتصال بالإنترنت
    var connectivityResult = await Connectivity().checkConnectivity();
    // هنا بنستعمل .contains() عشان نشوف لو القائمة فيها ConnectivityResult.none
    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة.'),
        ),
      );
      return;
    }

    // 2. التحقق من وجود وجهات
    if (destinationControllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال وجهة واحدة على الأقل.')),
      );
      return;
    }

    // 3. نجهز تفاصيل المحل بالظبط زي ما هي عندك في Firebase
    Map<String, dynamic> storeDetails = {
      'address': widget.address,
      'averageRating': widget.averageRating,
      'createdAt': widget.createdAt, // ممكن تحتاج تحوله لـ String
      'isOpen': widget.isOpen,
      'location': {'lat': widget.lat, 'lng': widget.lng},
      'logoUrl': widget.logoUrl,
      'phone': widget.phone,
      'storeName': widget.storeName,
      'storeRegion': widget.storeRegion,
      'totalRating': widget.totalRating,
    };

    // 4. نلف على كل وجهة منفصلة ونبعتها كأوردر لوحده
    try {
      for (int i = 0; i < destinationControllers.length; i++) {
        String destination = destinationControllers[i].text.trim();
        String price = priceControllers[i].text.trim();

        if (destination.isNotEmpty && price.isNotEmpty) {
          Map<String, dynamic> orderData = {
            'destination': destination,
            'deliveryPrice': double.parse(price),
            'storeDetails': storeDetails, // نضيف كل تفاصيل المحل بالكامل
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('store_orders')
              .add(orderData);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال كل الطلبات بنجاح!')),
      );

      ordersCountController.clear();
      destinationControllers.clear();
      priceControllers.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حصل خطأ أثناء الإرسال: $e')));
    }
  }

  void calculateTotal() {
    double total = 0;
    for (var controller in priceControllers) {
      total += double.tryParse(controller.text.trim()) ?? 0;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'إجمالي سعر التوصيل',
          style: TextStyle(color: Colors.lightBlue),
        ),
        content: Text(
          'الإجمالي: ${total.toStringAsFixed(2)} جنيه',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(color: Colors.lightBlue),
            ),
          ),
        ],
      ),
    );
  }

  // --- وظائف إدارة الطلبات زد (عرض فقط) ---

  Future<void> _fetchPreviousOrders() async {
    if (!mounted) return;
    debugPrint('DEBUG: _fetchPreviousOrders started.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل الطلبات السابقة...'),
          ],
        ),
      ),
    );

    try {
      final completedOrdersQuery = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('orders')
          .where('status', whereIn: ['completed']) // ✅ الأوردرات المنتهية فقط
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // إغلاق نافذة التحميل

      List<Widget> orderWidgets = [];

      if (completedOrdersQuery.docs.isEmpty) {
        orderWidgets.add(
          const Text(
            'لا توجد طلبات سابقة مكتملة.',
            style: TextStyle(fontSize: 16),
          ),
        );
      } else {
        for (var doc in completedOrdersQuery.docs) {
          final data = doc.data();
          final orderNumber = data['orderNumber']?.toString() ?? doc.id;
          final customerName = data['customerName'] ?? 'غير معروف';
          final customerPhone = data['customerPhone'] ?? 'غير معروف';
          final timestamp =
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final totalItemsPrice =
              (data['totalItemsPrice'] as num?)?.toDouble() ?? 0.0;
          final profitPercentage =
              (data['profitPercentage'] as num?)?.toDouble() ?? 0.0;
          final originalTotal = totalItemsPrice > 0 && profitPercentage >= 0
              ? totalItemsPrice / (1 + profitPercentage)
              : totalItemsPrice;

          final items =
              (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          // كارت عرض الطلب
          orderWidgets.add(
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب رقم: ${orderNumber.length > 5 ? orderNumber.substring(0, 5) : orderNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'العميل: $customerName',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'رقم الهاتف: $customerPhone',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'إجمالي الطلب: ${originalTotal.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'التاريخ: ${DateFormat('yyyy-MM-dd – kk:mm').format(timestamp)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const Divider(height: 10),
                    const Text(
                      'تفاصيل الأصناف:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...items.map((item) {
                      final name = item['name'] ?? 'منتج غير معروف';
                      final quantity = item['quantity'] ?? 1;
                      return Text(
                        '- $name × $quantity',
                        style: const TextStyle(fontSize: 13),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'الطلبات السابقة المكتملة',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: orderWidgets,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('ERROR: Failed to fetch previous orders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل الطلبات السابقة: $e')),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final storeDocStream = FirebaseFirestore.instance
        .collection('stores')
        .doc(_storeDocId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isGuest
              ? 'الله أكبر ولله الحمد'
              : 'سبحان الله وبحمده سبحان الله العظيم',
          style: const TextStyle(color: Colors.lightBlue),
        ),
        backgroundColor: Colors.white,
        actions: [
          // السويتش مع نص
          Row(
            children: [
              Text(
                _isStoreOpen ? 'المحل مفتوح' : 'المحل مغلق',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isStoreOpen ? Colors.green : Colors.red,
                ),
              ),
              Switch(
                value: _isStoreOpen,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.red,
                onChanged: (value) async {
                  setState(() {
                    _isStoreOpen = value;
                  });
                  try {
                    await FirebaseFirestore.instance
                        .collection('stores')
                        .doc(widget.storeId)
                        .update({'isOpen': _isStoreOpen});
                  } catch (e) {
                    setState(() {
                      _isStoreOpen =
                          !_isStoreOpen; // لو حصل خطأ نرجع الحالة القديمة
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ في تحديث حالة المحل: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          // أيقونة الحساب
          Builder(
            builder: (BuildContext builderContext) {
              return IconButton(
                icon: const Icon(Icons.account_circle, color: Colors.blue),
                onPressed: () {
                  Scaffold.of(builderContext).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),

      // ====== Drawer بقراءة لايف من stores/{phone} ======
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: MediaQuery.of(context).size.height, // تعديل مهم للويب
            color: Colors.white.withAlpha(230),
            child: StreamBuilder<DocumentSnapshot>(
              stream: storeDocStream,
              builder: (context, snap) {
                int ordersCount = 0;
                String? logoUrl;
                String storeName = widget.storeName;
                String storeAddress = widget.address;
                String phone = widget.phone;
                Map<String, dynamic>? location;
                bool isLoading = false; // حالة التحميل

                if (snap.hasData && snap.data!.exists) {
                  final m = snap.data!.data() as Map<String, dynamic>;
                  ordersCount = (m['ordersCount'] as num?)?.toInt() ?? 0;
                  logoUrl = m['logoUrl'] as String?;
                  storeName = m['storeName'] ?? storeName;
                  storeAddress = m['address'] ?? storeAddress;
                  phone = m['phone'] ?? phone;
                  location = m['location'] as Map<String, dynamic>?;
                }

                final medal = _medalForCount(ordersCount);

                Future<void> updateField(String field, dynamic value) async {
                  setState(() => isLoading = true);
                  try {
                    await FirebaseFirestore.instance
                        .collection('stores')
                        .doc(widget.storeId)
                        .update({field: value});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم تحديث ${field == 'storeName'
                              ? 'اسم المتجر'
                              : field == 'address'
                              ? 'العنوان'
                              : 'رقم الهاتف'} بنجاح',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('حدث خطأ أثناء التحديث')),
                    );
                  } finally {
                    setState(() => isLoading = false);
                  }
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 25,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.lightBlue.shade400,
                              Colors.blueAccent.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.white,
                                  backgroundImage:
                                      logoUrl != null && logoUrl.isNotEmpty
                                      ? NetworkImage(logoUrl)
                                      : null,
                                  child: (logoUrl == null || logoUrl.isEmpty)
                                      ? const Icon(
                                          Icons.store,
                                          size: 40,
                                          color: Colors.blueAccent,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.white,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.edit, size: 18),
                                      color: Colors.blueAccent,
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'وظيفة تعديل اللوجو غير متاحة الآن',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            Text(
                              medal,
                              style: const TextStyle(
                                fontSize: 36,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),

                            _EditableField(
                              initialValue: storeName,
                              label: 'اسم المحل',
                              onSave: (val) => updateField('storeName', val),
                              isLoading: isLoading,
                            ),
                            const SizedBox(height: 4),

                            _EditableField(
                              initialValue: storeAddress,
                              label: 'العنوان',
                              onSave: (val) => updateField('address', val),
                              isLoading: isLoading,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                            const SizedBox(height: 4),

                            _EditableField(
                              initialValue: phone,
                              label: 'رقم الهاتف',
                              onSave: (val) => updateField('phone', val),
                              keyboardType: TextInputType.phone,
                              isLoading: isLoading,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(height: 15),

                      ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: Colors.blueGrey,
                        ),
                        title: Text(
                          'العنوان: $storeAddress',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.map, color: Colors.blueGrey),
                        title: Text(
                          'المنطقة: ${widget.storeRegion}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.phone,
                          color: Colors.blueGrey,
                        ),
                        title: Text(
                          'رقم الهاتف: $phone',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (location != null) ...[
                        ListTile(
                          leading: const Icon(
                            Icons.my_location,
                            color: Colors.blueGrey,
                          ),
                          title: Text(() {
                            final lat = (location?['lat'] as num?)?.toDouble();
                            final lng = (location?['lng'] as num?)?.toDouble();

                            return 'الموقع: ${lat?.toStringAsFixed(4) ?? ''}, ${lng?.toStringAsFixed(4) ?? ''}';
                          }(), style: const TextStyle(fontSize: 16)),
                        ),
                      ],

                      const Divider(color: Colors.blueGrey, height: 30),

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

                          const phone = '0201556798005';
                          final Uri whatsappUri = Uri.parse(
                            'https://wa.me/$phone',
                          );

                          if (await canLaunchUrl(whatsappUri)) {
                            await launchUrl(
                              whatsappUri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'لا يمكن فتح واتساب على هذا الجهاز',
                                ),
                              ),
                            );
                          }
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.history, color: Colors.blue),
                        title: const Text(
                          'الطلبات السابقة',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _fetchPreviousOrders();
                        },
                      ),
                      const Divider(color: Colors.blueGrey, height: 30),
                      ListTile(
                        leading: const Icon(
                          Icons.privacy_tip,
                          color: Colors.grey,
                        ),
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
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'تسجيل الخروج',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _logout();
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),

      // ====== /NEW Drawer ======
      body: Column(
        children: [
          // === الجزء العلوي: زرار الطلبات المطلوبة مع العداد ===
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Card(
              color: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 6,
              child: InkWell(
                onTap: () {
                  // الكود الأصلي لفتح صفحة الطلبات
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoreOrdersPage(storeId: widget.storeId),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.shopping_bag,
                        color: Colors.white,
                        size: 30,
                      ),
                      const Text(
                        'الطلبات المطلوبة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // الكود بتاع الـ StreamBuilder عشان يجيب عدد الطلبات
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('stores')
                            .doc(widget.storeId)
                            .collection('orders')
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox();
                          }
                          if (snapshot.hasError) {
                            return const Icon(Icons.error, color: Colors.red);
                          }
                          final docs = snapshot.data?.docs ?? [];
                          int ordersCount = docs.length;
                          return badges.Badge(
                            showBadge: ordersCount > 0,
                            badgeContent: Text(
                              ordersCount.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            child: const SizedBox(width: 0),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // === الجزء الأوسط: أزرار إضافة العروض والأصناف ===
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // زرار إضافة صنف
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: InkWell(
                      onTap: () {
                        // الكود الأصلي لفتح صفحة إضافة الأصناف
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddItemsPage(storeId: widget.storeId),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.add,
                              color: Colors.green,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'إضافة صنف',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // زرار إضافة عروض
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: InkWell(
                      onTap: () {
                        // الكود الأصلي لفتح صفحة إضافة العروض
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddOfferPage(
                              storeId: widget.storeId,
                              storeName: widget.storeName,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.local_offer,
                              color: Colors.purple,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'إضافة عروض',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // === أسفل الشاشة: زرار "عاوز مندوب توصيل" ===
          Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: ElevatedButton(
              // ✅ ده كود الـ onPressed بعد التغيير
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('اختار طريقة التواصل'),
                      content: const Text('هل تود الاتصال أم فتح واتساب؟'),
                      actions: [
                        TextButton.icon(
                          icon: const Icon(Icons.call, color: Colors.green),
                          label: const Text('اتصال'),
                          onPressed: () async {
                            const String phone = 'tel:+201556798005';
                            final Uri url = Uri.parse(phone);
                            Navigator.pop(context);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تعذر فتح تطبيق الاتصال.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            color: Colors.green,
                          ),
                          label: const Text('واتساب'),
                          onPressed: () async {
                            const String phoneNumber = '201556798005';
                            const String message =
                                'مرحباً، عاوز مندوب توصيل للمحل! برجاء التواصل لتحديد التفاصيل.';
                            final encodedMessage = Uri.encodeComponent(message);
                            final Uri url = Uri.parse(
                              'whatsapp://send?phone=$phoneNumber&text=$encodedMessage',
                            );

                            Navigator.pop(context);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'برجاء تثبيت تطبيق واتساب أولاً.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    );
                  },
                );
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'عاوز مندوب توصيل',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
        ],
      ), // الفاصلة هنا
    );
  }
}
