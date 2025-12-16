// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreOrdersPage extends StatefulWidget {
  final String storeId;
  const StoreOrdersPage({super.key, required this.storeId});

  @override
  State<StoreOrdersPage> createState() => _StoreOrdersPageState();
}

class _StoreOrdersPageState extends State<StoreOrdersPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _previousOrdersCount = 0;

  // دالة لمعرفة لون الحالة (كما هي)
  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade600;
      case 'accepted':
        return Colors.blue.shade600;
      case 'ready':
        return Colors.green.shade600;
      case 'canceled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // دالة لمعرفة أيقونة الحالة (كما هي)
  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'ready':
        return Icons.done_all;
      case 'canceled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  // تشغيل صوت التنبيه (كما هي)
  Future<void> _playOrderSound() async {
    await _audioPlayer.play(AssetSource('sounds/new_order_sound.mp3'));
  }

  // تحديث حالة الطلب
  // لاحظ: تم تعديل الـstatus هنا. لو كان 'pending' هيتنقل لـ'accepted' بشكل آلي
  void _updateOrderStatus(
    String orderId,
    String status,
    BuildContext context,
  ) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('orders')
          .doc(orderId);

      Map<String, dynamic> updateData = {'status': status};

      if (status == 'accepted') {
        updateData.addAll({
          'agentName': 'احمد عزب',
          'agentPhone': '01500083403',
          'assignedAgentPhone': '01500083403',
          'agentId': '01500083403',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      } else if (status == 'completed') {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      }

      await orderRef.update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب إلى: $status'),
          backgroundColor: status == 'completed'
              ? Colors.green
              : status == 'accepted'
              ? Colors.blue
              : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء التحديث: $e')));
    }
  }

  // دالة جديدة لإظهار مربع حوار التأكيد
  void _confirmCancellation(String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'تأكيد إلغاء الطلب',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.',
            textAlign: TextAlign.right,
          ),
          actions: <Widget>[
            // ❌ زر التراجع (Cancel)
            TextButton(
              child: const Text(
                'تراجع',
                style: TextStyle(color: Colors.blueGrey),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // إغلاق مربع الحوار
              },
            ),
            // ✅ زر التأكيد
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // 1. إغلاق مربع الحوار أولاً
                Navigator.of(context).pop();
                // 2. تحديث حالة الطلب لـ 'canceled'
                _updateOrderStatus(orderId, 'canceled', context);
              },
              child: const Text('نعم، إلغاء الطلب'),
            ),
          ],
        );
      },
    );
  }

  // إجراء مكالمة هاتفية (كما هي)
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن الاتصال بهذا الرقم.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'طلبات المتجر',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.green.shade50),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('stores')
              .doc(widget.storeId)
              .collection('orders')
              .where('status', whereIn: ['pending', 'accepted', 'ready'])
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'حدث خطأ في جلب البيانات: ${snapshot.error}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snapshot.data?.docs ?? [];

            // تشغيل صوت التنبيه للطلبات الجديدة (كما هي)
            if (orders.isNotEmpty && orders.length > _previousOrdersCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _playOrderSound();
              });
            }
            _previousOrdersCount = orders.length;

            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'لا توجد طلبات حالياً.',
                      style: TextStyle(color: Colors.black54, fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final orderDoc = orders[index];
                final orderData = orderDoc.data() as Map<String, dynamic>?;

                if (orderData == null) {
                  return const SizedBox.shrink();
                }

                // استخراج البيانات مع تأمين ضد الـnull
                final items =
                    (orderData['items'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];

                final timestamp =
                    (orderData['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                final status = orderData['status'] as String? ?? 'pending';
                final customerName =
                    orderData['customerName'] as String? ?? 'غير معروف';
                final customerPhone =
                    orderData['customerPhone'] as String? ?? 'غير معروف';
                final orderNumber =
                    orderData['orderNumber']?.toString() ?? orderDoc.id;
                final orderId = orderDoc.id;

                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: _statusColor(
                        status,
                      ).withAlpha((0.5 * 255).toInt()),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- رأس الطلب (الحالة والإجمالي ورقم الطلب) ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 1. رقم الطلب والحالة
                            Flexible(
                              child: Row(
                                children: [
                                  Icon(
                                    _statusIcon(status),
                                    color: _statusColor(status),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'طلب رقم: ${orderNumber.length > 5 ? orderNumber.substring(0, 5) : orderNumber}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 2. الإجمالي
                            Text(
                              '${(orderData['totalStorePayout'] as num?)?.toStringAsFixed(2) ?? '0.00'} ج.م',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, thickness: 1),

                        // --- معلومات العميل (كما هي) ---
                        // --- معلومات العميل + ملاحظات ---
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.person,
                            color: Colors.blueGrey,
                          ),
                          title: Text(
                            'العميل: $customerName',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('رقم الهاتف: $customerPhone'),
                              if ((orderData['customerNotes'] as String?) !=
                                      null &&
                                  (orderData['customerNotes'] as String)
                                      .trim()
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 5.0),
                                  child: Text(
                                    'ملاحظات: ${orderData['customerNotes']}',
                                    style: const TextStyle(
                                      color: Colors.deepPurple,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            onPressed: () => _makePhoneCall(customerPhone),
                            icon: const Icon(Icons.phone, color: Colors.red),
                            tooltip: 'اتصل بالعميل',
                          ),
                        ),

                        const Divider(height: 10),

                        // --- تفاصيل المنتجات ---
                        const Text(
                          'تفاصيل الأصناف:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: items.map<Widget>((item) {
                            // التعامل الآمن مع بيانات الصنف
                            final name =
                                item['name'] as String? ?? 'منتج غير معروف';
                            final quantity =
                                (item['quantity'] as num?)?.toInt() ?? 1;
                            // final price = (item['priceOriginal'] as num?)?.toDouble() ?? 0.0; // تم إخفاء السعر

                            final imageUrl =
                                item['imageUrl'] as String? ??
                                'https://via.placeholder.com/150';
                            // جلب الحجم والإضافات
                            final size = item['size'] as String?;
                            final addons =
                                (item['addons'] as List?)
                                    ?.cast<Map<String, dynamic>>() ??
                                [];
                            final hasSizeOrAddons =
                                size != null || addons.isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                        child: Image.network(
                                          imageUrl,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    width: 50,
                                                    height: 50,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8.0,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      size: 25,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                          loadingBuilder:
                                              (
                                                BuildContext context,
                                                Widget child,
                                                ImageChunkEvent?
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null) {
                                                  return child;
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
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4.0,
                                              ),
                                              child: Text(
                                                'الوصف: ${orderData['description'] ?? ''}',
                                                style: const TextStyle(
                                                  color: Colors.teal,
                                                  fontStyle: FontStyle.italic,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            Text(
                                              'الكمية: $quantity',
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // --- عرض الحجم والإضافات الجديدة (كما هي) ---
                                  if (hasSizeOrAddons)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 60.0,
                                        top: 5,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // عرض الحجم
                                          if (size != null && size.isNotEmpty)
                                            Text(
                                              'الحجم: ${size.trim()}',
                                              style: TextStyle(
                                                color: Colors.blueGrey.shade700,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          // عرض الإضافات
                                          if (addons.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 5.0,
                                              ),
                                              child: Text(
                                                'الإضافات: ${addons.map((addon) => addon['name']).join(', ')}',
                                                style: TextStyle(
                                                  color: Colors.purple.shade700,
                                                  fontSize: 13,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  const Divider(
                                    height: 10,
                                    color: Colors.black12,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const Divider(height: 20),

                        // --- التاريخ والأزرار ---
                        Text(
                          'تم الطلب في: ${DateFormat('yyyy-MM-dd – kk:mm').format(timestamp)}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // أزرار التحكم
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 📦 زر تم التجهيز
                            // ✅ دلوقتي الزر ده هيظهر لو pending أو accepted
                            if (status != 'ready' && status != 'canceled')
                              // 📦 زر جاهز للتسليم (لما تكون الحالة ready)
                              if (status == 'ready')
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: null, // Disabled
                                    icon: const Icon(Icons.done_all),
                                    label: const Text('جاهز للتسليم'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),

                            // مسافة بين الأزرار
                            if (status != 'canceled' && status != 'ready')
                              const SizedBox(width: 10),

                            // ❌ زر إلغاء الطلب
                            if (status != 'canceled' && status != 'ready')
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _confirmCancellation(
                                    orderId,
                                  ), // 👈 تم التعديل هنا
                                  icon: const Icon(Icons.cancel),
                                  label: const Text('إلغاء الطلب'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
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
        ),
      ),
    );
  }
}
