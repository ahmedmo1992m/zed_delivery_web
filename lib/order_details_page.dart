import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import './rating_dialog.dart'; // تأكد من المسار الصحيح

class OrderDetailsPage extends StatelessWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الأوردر'),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('الأوردر غير موجود.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // التأكد من وجود القيم، وتوفير Default للقيم غير موجودة
          final storeName = data['storeName'] ?? 'غير معروف';
          final storeAddress = data['storeAddress'] ?? 'غير معروف';
          final orderNumber = data['orderNumber']?.toString() ?? '-';
          final status = data['status'] ?? 'غير معروف';

          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();
          final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();

          final agentName = data['agentName'] ?? '-';
          final agentPhone = data['agentPhone'] ?? '-';

          final customerName = data['customerName'] ?? '-';
          final customerPhone = data['customerPhone'] ?? '-';
          final customerAddress = data['customerAddress'] ?? '-';
          final customerNotes = data['customerNotes'] ?? '-';

          final items = (data['items'] as List?) ?? [];
          final deliveryFee = data['deliveryFee']?.toDouble() ?? 0;
          final totalItemsPrice = data['totalItemsPrice']?.toDouble() ?? 0;
          final grandTotal = data['grandTotal']?.toDouble() ?? 0;
          final storeRating = data['storeRating'];

          Color statusColor;
          switch (status) {
            case 'completed':
              statusColor = Colors.green;
              break;
            case 'accepted':
              statusColor = Colors.blue;
              break;
            case 'delivered':
              statusColor = Colors.grey[700]!;
              break;
            default:
              statusColor = Colors.black;
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        storeName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('العنوان: $storeAddress'),
                  Text('رقم الأوردر: $orderNumber'),
                  const SizedBox(height: 10),

                  // Dates
                  if (timestamp != null)
                    Text(
                      'تاريخ الإنشاء: ${timestamp.day}/${timestamp.month}/${timestamp.year}',
                    ),
                  if (acceptedAt != null)
                    Text(
                      'تم قبول الأوردر: ${acceptedAt.day}/${acceptedAt.month}/${acceptedAt.year}',
                    ),
                  if (deliveredAt != null)
                    Text(
                      'تم التسليم: ${deliveredAt.day}/${deliveredAt.month}/${deliveredAt.year}',
                    ),
                  const Divider(height: 20),

                  // Agent info
                  if (agentName.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'معلومات المندوب:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('الاسم: $agentName'),
                        Text('الهاتف: $agentPhone'),
                        const Divider(height: 20),
                      ],
                    ),

                  // Customer info
                  const Text(
                    'بيانات العميل:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('الاسم: $customerName'),
                  Text('الهاتف: $customerPhone'),
                  Text('العنوان: $customerAddress'),
                  Text('ملاحظات: $customerNotes'),
                  const Divider(height: 20),

                  // Items
                  const Text(
                    'الأصناف:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...items.map((item) {
                    final name = item['name'] ?? '-';
                    final quantity = item['quantity']?.toString() ?? '0';
                    final size = item['size'] ?? '';
                    final price =
                        (item['priceAfterProfit'] ?? item['subtotal'] ?? 0)
                            .toDouble();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('$name $size'),
                      subtitle: Text(
                        'الكمية: $quantity | السعر: ${(price * int.parse(quantity)).toStringAsFixed(2)} جنيه',
                      ),
                      leading:
                          (item['imageUrl'] != null &&
                              item['imageUrl'].isNotEmpty)
                          ? Image.network(
                              item['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : null,
                    );
                  }),

                  const Divider(height: 20),
                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي الأصناف:'),
                      Text('${totalItemsPrice.toStringAsFixed(2)} جنيه'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سعر التوصيل:'),
                      Text('${deliveryFee.toStringAsFixed(2)} جنيه'),
                    ],
                  ),
                  const Divider(height: 20),
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
                        '${grandTotal.toStringAsFixed(2)} جنيه',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  // Rating button
                  if (status == 'completed' && storeRating == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.star),
                          label: const Text('قيم الأوردر'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // نتأكد من storeId قبل فتح الـDialog
                            final storeId =
                                data['store_id']?.toString().trim() ?? '';
                            if (storeId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('المحل غير موجود للتقييم'),
                                ),
                              );
                              return;
                            }

                            // نفتح RatingDialog
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => RatingDialog(
                                storeId: storeId,
                                orderId: orderId,
                              ),
                            );
                          },
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
