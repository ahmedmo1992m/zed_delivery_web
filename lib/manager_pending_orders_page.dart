// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:zed/agent_map_screen.dart'; // تأكد إن المسار ده صح عندك

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
    } else if (widget.status == 'rejected' || widget.status == 'canceled') {
      // تم تعديل 'cancelled' إلى 'canceled' لتتناسب مع الكود
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
      // 'rejected', 'canceled' أو أي حالة أخرى غير نشطة
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

class ManagerPendingOrdersPage extends StatefulWidget {
  final String managerId;

  const ManagerPendingOrdersPage({super.key, required this.managerId});

  @override
  State<ManagerPendingOrdersPage> createState() =>
      _ManagerPendingOrdersPageState();
}

class _ManagerPendingOrdersPageState extends State<ManagerPendingOrdersPage> {
  // دالة لجلب عدد الطلبات بناءً على المجموعة والحالة
  Stream<int> _buildOrderCountStream(String collection, String status) {
    return FirebaseFirestore.instance
        .collection(collection)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Widget مساعد لعرض العداد في التبويب
  Widget _buildTabWithCount(String title, String collection, String status) {
    return StreamBuilder<int>(
      stream: _buildOrderCountStream(collection, status),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        // الألوان والتصميم
        final color = count > 0 ? Colors.yellow.shade200 : Colors.white;
        final textColor = count > 0 ? Colors.black : Colors.white70;

        return Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (count > 0)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  final Logger _logger = Logger();
  final TextEditingController _searchAgentController = TextEditingController();
  String _currentAgentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchAgentController.addListener(() {
      setState(() {
        _currentAgentSearchQuery = _searchAgentController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchAgentController.dispose();
    super.dispose();
  }

  Future<void> _assignOrderToAgent(
    String orderId,
    String orderCollection,
    String newAgentId, // تم تغيير الاسم لتوضيح أنه الجديد
    String newAgentName,
    String newAgentPhone,
  ) async {
    try {
      DocumentReference orderRef = FirebaseFirestore.instance
          .collection(orderCollection)
          .doc(orderId);
      DocumentSnapshot orderSnapshot = await orderRef.get();

      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw Exception('بيانات الطلب غير موجودة أو غير صالحة.');
      }

      final orderData = orderSnapshot.data() as Map<String, dynamic>;
      final String? oldAgentId =
          orderData['agentId']; // 1. بنجيب الـ ID بتاع المندوب القديم

      WriteBatch batch = FirebaseFirestore.instance.batch();

      if (oldAgentId != null && oldAgentId != newAgentId) {
        DocumentReference oldAgentRef = FirebaseFirestore.instance
            .collection('agents')
            .doc(oldAgentId);
        batch.update(oldAgentRef, {
          'active_orders_count': FieldValue.increment(-1),
        });
      }

      batch.update(orderRef, {
        'status': 'accepted',
        'agentId': newAgentId,
        'agentName': newAgentName,
        'agentPhone': newAgentPhone,
        'assignedAgentPhone': newAgentPhone,
        'acceptedAt': FieldValue.serverTimestamp(),
        'isManagerAssigned': true,
      });

      DocumentReference newAgentRef = FirebaseFirestore.instance
          .collection('agents')
          .doc(newAgentId);
      batch.update(newAgentRef, {
        'active_orders_count': FieldValue.increment(1),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم إسناد الطلب بنجاح للمندوب $newAgentName!'),
        ),
      );
    } catch (e) {
      _logger.e('Error assigning order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إسناد الطلب: $e')),
      );
    }
  }

  // دالة جديدة لإلغاء الطلب
  Future<void> _cancelOrder(String orderId, String orderCollection) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection(orderCollection)
            .doc(orderId)
            .update({
              'status': 'canceled',
              'canceledAt': FieldValue.serverTimestamp(),
            });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إلغاء الطلب بنجاح!')),
        );
      } catch (e) {
        _logger.e('Error canceling order: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ حدث خطأ أثناء إلغاء الطلب: $e')),
        );
      }
    }
  }

  void _showAssignAgentDialog(
    String orderId,
    String orderCollection,
    String orderTitle,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(
                'إسناد الطلب: $orderTitle',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchAgentController,
                      decoration: InputDecoration(
                        labelText:
                            'ابحث عن مندوب بالاسم أو رقم الهاتف أو الـ ID',
                        hintText: 'اكتب اسم أو رقم أو ID المندوب',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _currentAgentSearchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('agents')
                            .where('manager_id', isEqualTo: widget.managerId)
                            .where('isOnline', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'خطأ في تحميل المناديب: ${snapshot.error}',
                              ),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('لا يوجد مناديب متاحون حالياً.'),
                            );
                          }

                          final filteredAgents = snapshot.data!.docs.where((
                            doc,
                          ) {
                            final agentData =
                                doc.data() as Map<String, dynamic>;
                            final agentName = (agentData['agentName'] ?? '')
                                .toLowerCase();
                            final agentPhone = (agentData['agentPhone'] ?? '')
                                .toLowerCase();
                            final agentId = doc.id.toLowerCase();

                            return agentName.contains(
                                  _currentAgentSearchQuery,
                                ) ||
                                agentPhone.contains(_currentAgentSearchQuery) ||
                                agentId.contains(_currentAgentSearchQuery);
                          }).toList();

                          if (filteredAgents.isEmpty) {
                            return const Center(
                              child: Text('لا يوجد مناديب مطابقون للبحث.'),
                            );
                          }

                          return ListView.builder(
                            itemCount: filteredAgents.length,
                            itemBuilder: (context, index) {
                              var agent = filteredAgents[index];
                              var agentData =
                                  agent.data() as Map<String, dynamic>;
                              String agentName =
                                  agentData['agentName'] ?? 'غير معروف';
                              String agentPhone =
                                  agentData['agentPhone'] ?? 'غير متاح';
                              bool isOnline = agentData['isOnline'] ?? false;
                              // ⚠️ التعديل هنا: قراءة العداد الجديد
                              final int activeOrdersCount =
                                  (agentData['active_orders_count'] as num?)
                                      ?.toInt() ??
                                  0;
                              // bool hasActiveOrder = agentData['hasActiveOrder'] ?? false; // ❌ ما بقتش محتاجينها

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                elevation: 2,
                                child: ListTile(
                                  title: Text(
                                    '$agentName (ID: ${agent.id})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('رقم الهاتف: $agentPhone'),
                                      // ⚠️ التعديل هنا: عرض عدد الأوردرات النشطة
                                      Text(
                                        'الحالة: ${isOnline ? 'متصل' : 'غير متصل'} ${isOnline ? (activeOrdersCount > 0 ? '(أوردرات نشطة: $activeOrdersCount)' : '(بدون أوردر)') : ''}',
                                        style: TextStyle(
                                          color: isOnline
                                              ? (activeOrdersCount > 0
                                                    ? Colors
                                                          .orange // برتقالي لو معاه أوردرات
                                                    : Colors
                                                          .green) // أخضر لو بدون أوردر
                                              : Colors.red, // أحمر لو غير متصل
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    bool confirmAssign =
                                        await showDialog<bool>(
                                          context: context,
                                          builder: (confirmCtx) => AlertDialog(
                                            title: const Text(
                                              'تأكيد إسناد الطلب',
                                            ),
                                            content: Text(
                                              'هل أنت متأكد من إسناد الطلب هذا للمندوب $agentName؟',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  confirmCtx,
                                                  false,
                                                ),
                                                child: const Text('إلغاء'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  confirmCtx,
                                                  true,
                                                ),
                                                child: const Text('تأكيد'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;

                                    if (confirmAssign) {
                                      await _assignOrderToAgent(
                                        orderId,
                                        orderCollection,
                                        agent.id,
                                        agentName,
                                        agentPhone,
                                      );
                                      if (!mounted) return;
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('إغلاق'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // دالة مساعدة جديدة لعمل الـ SingleChildScrollView لكل تبويب
  Widget _buildTabContent(
    String collection,
    String status,
    String titlePrefix, {
    bool showAgent = false,
  }) {
    // تحديد العنوان بناءً على نوع الطلب وحالته
    String sectionTitle;
    if (collection == 'orders') {
      sectionTitle = (status == 'pending') ? ' زد المعلقة' : ' زد المقبولة';
    } else {
      sectionTitle = (status == 'pending')
          ? ' التوصيل المعلقة'
          : ' التوصيل المقبولة';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF673AB7),
              ),
            ),
            const SizedBox(height: 10),
            // هنا بنستخدم _buildOrderList بدون الخصائص اللي بتمنع الـ scrolling
            _buildOrderList(
              collection,
              status,
              titlePrefix,
              showAgent: showAgent,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. استخدام DefaultTabController للتبويب الأفقي
    return DefaultTabController(
      length: 4, // 4 تبويبات
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة الطلبات ',
            style: TextStyle(color: Color.fromARGB(255, 221, 67, 67)),
          ),
          backgroundColor: const Color.fromARGB(255, 27, 102, 4),
          actions: [
            IconButton(
              icon: const Icon(Icons.map, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AgentMapScreen(managerId: widget.managerId),
                  ),
                );
              },
              tooltip: 'عرض المناديب على الخريطة',
            ),
          ],
          // 2. إضافة الـ TabBar في أسفل الـ AppBar
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color.fromARGB(255, 28, 6, 155),
            labelColor: const Color.fromARGB(255, 255, 255, 255),
            unselectedLabelColor: Colors.white70,
            tabs: [
              // ✅ التعديل هنا: استخدام الدالة المساعدة الجديدة
              _buildTabWithCount('زد - معلقة ⏳', 'orders', 'pending'),
              _buildTabWithCount('زد - مقبولة 🛵', 'orders', 'accepted'),
              _buildTabWithCount('توصيل - معلقة ⏳', 'client_orders', 'pending'),
              _buildTabWithCount(
                'توصيل - مقبولة 🛵',
                'client_orders',
                'accepted',
              ),
            ],
          ),
        ),
        // 3. إضافة الـ TabBarView في الـ body
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: TabBarView(
            children: [
              // التبويب الأول: طلبات المحلات المعلقة
              _buildTabContent('orders', 'pending', 'من محل: '),
              // التبويب الثاني: طلبات المحلات المقبولة
              _buildTabContent(
                'orders',
                'accepted',
                'من محل: ',
                showAgent: true,
              ),
              // التبويب الثالث: طلبات العملاء المعلقة (زي ما هي)
              _buildTabContent('client_orders', 'pending', 'من عميل: '),
              // التبويب الرابع: طلبات العملاء المقبولة (زي ما هي)
              _buildTabContent(
                'client_orders',
                'accepted',
                'من عميل: ',
                showAgent: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة جديدة لتقليل تكرار الكود (تم تعديلها لتناسب الـ TabBarView)
  Widget _buildOrderList(
    String collection,
    String status,
    String titlePrefix, {
    bool showAgent = false,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ في تحميل الطلبات: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('لا توجد طلبات $status حاليًا.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var order = snapshot.data!.docs[index];
            var orderData = order.data() as Map<String, dynamic>;

            // المتغيرات العامة
            String title;
            double deliveryPrice;
            String sourceName;
            String sourceAddress;
            String sourceRegion;
            String sourcePhone = 'غير متاح';
            List<Widget> destinationsWidgets = [];
            DateTime? createdAt = (orderData['timestamp'] as Timestamp?)
                ?.toDate();
            DateTime? acceptedAt = (orderData['acceptedAt'] as Timestamp?)
                ?.toDate();
            String orderStatus = orderData['status'] ?? 'pending';

            if (collection == 'orders') {
              // طلبات المحلات
              sourceName = orderData['storeName'] ?? 'غير معروف';
              sourceAddress = orderData['storeAddress'] ?? 'غير معروف';
              sourceRegion = orderData['storeRegion'] ?? 'غير معروف';
              sourcePhone = orderData['storePhone'] ?? 'غير متاح';

              List<dynamic> orderItems = orderData['items'] ?? [];
              deliveryPrice = (orderData['deliveryFee'] is num)
                  ? orderData['deliveryFee'].toDouble()
                  : 0.0;

              title = '$titlePrefix$sourceName - $sourceRegion';

              // بيانات العميل
              destinationsWidgets.add(
                ExpansionTile(
                  title: const Text(
                    'بيانات العميل',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Text(
                      'اسم العميل: ${orderData['customerName'] ?? 'غير معروف'}',
                    ),
                    Text(
                      'رقم الهاتف: ${orderData['customerPhone'] ?? 'غير متاح'}',
                    ),
                    Text(
                      'عنوان التوصيل: ${orderData['customerAddress'] ?? 'غير محدد'}',
                    ),
                  ],
                ),
              );

              // المنتجات
              destinationsWidgets.add(
                ExpansionTile(
                  title: const Text(
                    'المنتجات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: orderItems.map<Widget>((item) {
                    if (item is Map<String, dynamic> &&
                        item.containsKey('name')) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          ' - ${item['name']} (${item['quantity'] ?? 1}x) - السعر: ${item['subtotal'].toStringAsFixed(2)}',
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),
                ),
              );
            } else {
              // طلبات التوصيل
              String orderDescription =
                  orderData['orderDescription'] ?? 'لا يوجد وصف';
              String customerAddress =
                  orderData['customerAddress'] ?? 'غير معروف';
              sourceName = orderDescription;
              sourceAddress = orderData['storeAddress'] ?? 'غير معروف';
              sourceRegion = 'غير محدد';
              deliveryPrice = (orderData['deliveryPrice'] is num)
                  ? orderData['deliveryPrice'].toDouble()
                  : 0.0;

              title = '$titlePrefix$orderDescription';

              destinationsWidgets.add(
                ExpansionTile(
                  title: const Text(
                    'تفاصيل الطلب',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Text('وصف الطلب: $orderDescription'),
                    Text('عنوان التوصيل: $customerAddress'),
                  ],
                ),
              );
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () =>
                    _showAssignAgentDialog(order.id, collection, title),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ExpansionTile(
                        title: const Text(
                          'بيانات المحل',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: [
                          Text('اسم المحل: $sourceName'),
                          Text('عنوان المحل: $sourceAddress'),
                          Text('المنطقة: $sourceRegion'),
                          Text('رقم الهاتف: $sourcePhone'),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (showAgent)
                        Text(
                          'تم الإسناد إلى: ${orderData['agentName'] ?? 'غير معروف'}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        'سعر التوصيل: ${deliveryPrice.toStringAsFixed(2)} جنيه',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (createdAt != null)
                        OrderCountdownWidget(
                          createdAt: createdAt,
                          acceptedAt: acceptedAt,
                          status: orderStatus,
                        ),
                      const SizedBox(height: 10),
                      ...destinationsWidgets,
                      Align(
                        alignment: Alignment.center,
                        child: ElevatedButton.icon(
                          onPressed: () => _cancelOrder(order.id, collection),
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.white,
                          ),
                          label: const Text('إلغاء الطلب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
