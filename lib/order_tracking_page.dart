// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rating_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/marketplace_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OrderTrackingPage extends StatefulWidget {
  final String orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  bool _isOrderRated = false;
  bool _pointsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkRatingStatus();
  }

  Future<void> _addPointsIfCompleted(Map<String, dynamic> orderData) async {
    if (orderData['status'] == 'completed') {
      final clientId = orderData['customer_id'];
      final totalItemsPrice = (orderData['totalItemsPrice'] ?? 0.0).toDouble();
      final earnedPoints = totalItemsPrice ~/ 100;

      if (earnedPoints > 0) {
        final clientRef = FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId);

        // تحقق لو النقاط ما اتحسبتش قبل كده
        final doc = await clientRef.get();
        final lastOrderPoints =
            doc.data()?['lastOrderPointsAdded'] ??
            {}; // الأوردر اللي اتحسبت له نقاط

        if (!(lastOrderPoints as Map).containsKey(widget.orderId)) {
          await clientRef.update({
            'points': FieldValue.increment(earnedPoints),
            'lastOrderPointsAdded.${widget.orderId}': true,
          });
        }
      }
    }
  }

  Future<void> _checkRatingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ratedOrders = prefs.getStringList('rated_orders') ?? [];
    setState(() {
      _isOrderRated = ratedOrders.contains(widget.orderId);
    });
  }

  String _mapStatusToText(String status) {
    switch (status) {
      case 'pending':
        return 'جاري التحضير...';
      case 'accepted':
        return 'جاري التجهيز!';
      case 'on_the_way':
        return 'المندوب في الطريق إليك!';
      case 'completed':
        return 'تم التوصيل بنجاح';
      case 'cancelled':
        return 'تم إلغاء الطلب';
      default:
        return 'حالة غير معروفة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيان الأوردر'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
            return const Center(child: Text('الأوردر غير موجود.'));
          }

          final orderData = orderSnapshot.data!.data() as Map<String, dynamic>;

          if (!_pointsChecked && orderData['status'] == 'completed') {
            _pointsChecked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _addPointsIfCompleted(orderData);
            });
          }

          final agentId = orderData['agentId'] as String?;
          final isTracking =
              agentId != null && orderData['status'] != 'completed';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رقم الأوردر: #${orderData['orderNumber'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'المحل: ${orderData['storeName'] ?? 'غير معروف'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'العنوان: ${orderData['customerAddress'] ?? 'غير معروف'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Divider(height: 20),

                  const Text(
                    'الأصناف بالتفاصيل:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),

                  ...(orderData['items'] as List<dynamic>? ?? []).map((item) {
                    final itemPrice = (item['priceOriginal'] ?? 0.0).toDouble();
                    final itemQuantity = (item['quantity'] ?? 0).toInt();
                    final itemSubtotal = itemPrice * itemQuantity;
                    final itemSize = item['size'] ?? 'حجم عادي';
                    final itemAddons = item['addons'] as List<dynamic>? ?? [];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['name'] ?? ''} (x$itemQuantity)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'الحجم: $itemSize | سعر الوحدة: ${itemPrice.toStringAsFixed(2)} ج',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          if (itemAddons.isNotEmpty)
                            Text(
                              'إضافات: ${itemAddons.map((e) => e['name']).join(', ')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.indigo,
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'الإجمالي: ${itemSubtotal.toStringAsFixed(2)} جنيه',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Divider(height: 5),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي الأصناف:'),
                      Text(
                        '${(orderData['totalItemsPrice'] ?? 0.0).toStringAsFixed(2)} جنيه',
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سعر التوصيل:'),
                      Text(
                        '${(orderData['deliveryFee'] ?? 0.0).toStringAsFixed(2)} جنيه',
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.black),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الإجمالي النهائي:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${(orderData['grandTotal'] ?? 0.0).toStringAsFixed(2)} جنيه',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  if (isTracking)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'بيانات المندوب:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'اسم المندوب: ${orderData['agentName'] ?? 'غير متاح'}',
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'رقم الهاتف: ${orderData['agentPhone'] ?? 'غير متاح'}',
                                  ),
                                ),
                                if (orderData['agentPhone'] != null &&
                                    (orderData['agentPhone'] as String)
                                        .isNotEmpty)
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.call,
                                          color: Colors.green,
                                        ),
                                        onPressed: () async {
                                          final phone = orderData['agentPhone'];
                                          final uri = Uri(
                                            scheme: 'tel',
                                            path: phone,
                                          );
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          } else {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تعذر فتح تطبيق الاتصال',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const FaIcon(
                                          FontAwesomeIcons.whatsapp,
                                          color: Colors.green,
                                        ),
                                        onPressed: () async {
                                          String phone = orderData['agentPhone']
                                              .toString()
                                              .replaceAll('+', '')
                                              .replaceAll(' ', '')
                                              .trim();

                                          if (!phone.startsWith('20')) {
                                            phone = '20$phone';
                                          }

                                          final whatsappUrl = Uri.parse(
                                            'https://wa.me/$phone',
                                          );

                                          if (await canLaunchUrl(whatsappUrl)) {
                                            await launchUrl(
                                              whatsappUrl,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          } else {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'تعذر فتح تطبيق واتساب على هذا الجهاز',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  const Text(
                    'الحالة الحالية:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _mapStatusToText(orderData['status'] ?? 'pending'),
                    style: TextStyle(
                      fontSize: 16,
                      color: (orderData['status'] == 'completed'
                          ? Colors.green
                          : Colors.blue),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),

                  Center(
                    child: Visibility(
                      visible:
                          orderData['status'] == 'completed' && !_isOrderRated,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // فتح صندوق تقييم الخدمة
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => RatingDialog(
                              storeId: orderData['store_id'],
                              orderId: widget.orderId,
                            ),
                          );

                          final prefs = await SharedPreferences.getInstance();
                          final ratedOrders =
                              prefs.getStringList('rated_orders') ?? [];
                          if (!ratedOrders.contains(widget.orderId)) {
                            ratedOrders.add(widget.orderId);
                            await prefs.setStringList(
                              'rated_orders',
                              ratedOrders,
                            );
                          }
                          await prefs.remove('active_order_id');
                          await prefs.remove('active_store_id');

                          if (mounted) {
                            setState(() {
                              _isOrderRated = true;
                            });
                          }
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MarketplacePage(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.star_rate),
                        label: const Text('إنهاء التتبع وتقييم الخدمة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
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
}
