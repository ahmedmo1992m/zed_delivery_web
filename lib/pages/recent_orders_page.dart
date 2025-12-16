import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // 💡 لازم نضيف الباكيدج دي عشان نستخدم StreamSubscription
import '../order_tracking_page.dart';

class RecentOrdersPage extends StatefulWidget {
  final String customerId;
  const RecentOrdersPage({super.key, required this.customerId});

  @override
  State<RecentOrdersPage> createState() => _RecentOrdersPageState();
}

class _RecentOrdersPageState extends State<RecentOrdersPage> {
  final List<Map<String, dynamic>> _orders = [];
  // 🆕 متغير للتحكم في الـ Stream الحالي
  StreamSubscription? _ordersSubscription;
  // 🆕 متغير لحالة التحميل
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 💡 هنبدأ الـ Stream أول ما الصفحة تتفتح
    _startOrdersStream();
  }

  // 🆕 دالة بتبدأ الـ Stream أو بتعيد تشغيله (عشان زرار الريفريش)
  void _startOrdersStream() {
    // 1. نقفل الـ Stream القديم لو كان شغال
    _ordersSubscription?.cancel();

    // 2. نظبط حالة التحميل والـ UI
    setState(() {
      _isLoading = true;
      _orders.clear();
    });

    // 3. نفتح Stream جديد
    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customer_id', isEqualTo: widget.customerId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final List<Map<String, dynamic>> updatedOrders = [];
            for (var doc in snapshot.docs) {
              final data = doc.data();
              updatedOrders.add({...data, 'id': doc.id});
            }

            // خزن آخر 5 أوردرات فقط
            final lastFiveOrders = updatedOrders.take(5).toList();

            setState(() {
              _orders
                ..clear()
                ..addAll(lastFiveOrders);
              _isLoading = false; // 4. نوقف التحميل بعد ما البيانات توصل
            });
          },
          onError: (error) {
            // 💡 مهمة لمتابعة الأخطاء
            ("Firebase Stream Error: $error");
            setState(() {
              _isLoading = false;
            });
          },
        );
  }

  @override
  void dispose() {
    // 💡 مهم جداً: نقفل الـ Stream عند إغلاق الـ Widget لتجنب تسريب الذاكرة
    _ordersSubscription?.cancel();
    super.dispose();
  }

  // -------------------------
  // الدوال المساعدة زي ما هي
  // -------------------------

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.blue;
      case 'accepted':
      case 'on_the_way':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _mapStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'معلق';
      case 'accepted':
        return 'مقبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  String _safeText(dynamic value, {String fallback = 'غير متاح'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double _safeDouble(dynamic value, {double fallback = 0.0}) {
    try {
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  DateTime? _safeTimestamp(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأوردرات الأخيرة'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 🌟 هنا بنستدعي الدالة اللي بتعيد تشغيل الـ Stream
              _startOrdersStream();
            },
          ),
        ],
      ),

      body:
          _isLoading // 🌟 عرض شاشة التحميل
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('لا توجد أوردرات سابقة.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final data = _orders[index];
                final orderNumber = _safeText(
                  data['orderNumber'] ?? data['id'],
                );
                final storeName = _safeText(data['storeName']);
                final agentName = _safeText(data['agentName']);
                final status = _safeText(data['status'], fallback: 'غير معروف');
                final grandTotal = _safeDouble(data['grandTotal']);

                final ts = _safeTimestamp(data['timestamp']);
                final timeText = ts != null
                    ? DateFormat('yyyy-MM-dd – kk:mm').format(ts)
                    : '---';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getStatusColor(
                                status,
                              ).withAlpha((0.2 * 255).toInt()),
                              child: Icon(
                                Icons.receipt_long,
                                color: _getStatusColor(status),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'أوردر #$orderNumber',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  status,
                                ).withAlpha((0.1 * 255).toInt()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _mapStatusText(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _infoChip(Icons.store, 'المحل: $storeName'),
                            _infoChip(Icons.person, 'المندوب: $agentName'),
                            _infoChip(Icons.access_time, timeText),
                            _infoChip(
                              Icons.monetization_on,
                              'الإجمالي: ${grandTotal.toStringAsFixed(2)} ج.م',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderTrackingPage(orderId: data['id']),
                                ),
                              );
                            },
                            icon: const Icon(Icons.track_changes),
                            label: const Text("التفاصيل"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.teal),
      label: Text(
        text,
        style: const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
