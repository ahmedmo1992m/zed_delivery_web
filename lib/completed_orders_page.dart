// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logger/logger.dart';

class CompletedOrdersPage extends StatefulWidget {
  final String agentPhone;

  const CompletedOrdersPage({super.key, required this.agentPhone});

  @override
  State<CompletedOrdersPage> createState() => _CompletedOrdersPageState();
}

class _CompletedOrdersPageState extends State<CompletedOrdersPage> {
  final Logger _logger = Logger();
  static const int maxCompletedOrders = 10;

  @override
  void initState() {
    super.initState();
    _listenForCompletedOrdersToCleanUp();
  }

  // دوال التنظيف وجلب الـ Streams (تركت كما هي)
  void _listenForCompletedOrdersToCleanUp() {
    final Stream<QuerySnapshot> storeOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
        .snapshots();

    final Stream<QuerySnapshot> clientOrdersStream = FirebaseFirestore.instance
        .collection('client_orders')
        .where('status', isEqualTo: 'completed')
        .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
        .snapshots();

    Rx.combineLatest2(storeOrdersStream, clientOrdersStream, (
      QuerySnapshot storeSnap,
      QuerySnapshot clientSnap,
    ) {
      return true;
    }).listen(
      (_) {
        _cleanUpOldOrders();
      },
      onError: (e) {
        _logger.e("Error listening for cleanup trigger: $e");
      },
    );
  }

  Future<void> _cleanUpOldOrders() async {
    try {
      List<QueryDocumentSnapshot> allCompletedOrders = [];

      QuerySnapshot storeOrdersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
          .orderBy('deliveredAt', descending: false)
          .get();
      allCompletedOrders.addAll(storeOrdersSnapshot.docs);

      QuerySnapshot clientOrdersSnapshot = await FirebaseFirestore.instance
          .collection('client_orders')
          .where('status', isEqualTo: 'completed')
          .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
          .orderBy('deliveredAt', descending: false)
          .get();
      allCompletedOrders.addAll(clientOrdersSnapshot.docs);

      allCompletedOrders.sort((a, b) {
        final aTime =
            (a.data() as Map<String, dynamic>)['deliveredAt'] as Timestamp?;
        final bTime =
            (b.data() as Map<String, dynamic>)['deliveredAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

      if (allCompletedOrders.length > maxCompletedOrders) {
        int ordersToDelete = allCompletedOrders.length - maxCompletedOrders;
        _logger.i(
          "Deleting $ordersToDelete old completed orders for agent ${widget.agentPhone}.",
        );

        WriteBatch batch = FirebaseFirestore.instance.batch();

        for (int i = 0; i < ordersToDelete; i++) {
          final doc = allCompletedOrders[i];
          final data = doc.data() as Map<String, dynamic>;
          String collectionName = data.containsKey('storeName')
              ? 'orders'
              : 'client_orders';
          batch.delete(
            FirebaseFirestore.instance.collection(collectionName).doc(doc.id),
          );
        }
        await batch.commit();
        _logger.i(
          "Successfully deleted old completed orders for agent ${widget.agentPhone}.",
        );
      }
    } catch (e) {
      _logger.e(
        "Error cleaning up old completed orders for agent ${widget.agentPhone}: $e",
      );
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getCompletedOrdersStream() {
    final Stream<QuerySnapshot> storeOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
        .snapshots();

    final Stream<QuerySnapshot> clientOrdersStream = FirebaseFirestore.instance
        .collection('client_orders')
        .where('status', isEqualTo: 'completed')
        .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
        .snapshots();

    return Rx.combineLatest2(storeOrdersStream, clientOrdersStream, (
      QuerySnapshot storeSnap,
      QuerySnapshot clientSnap,
    ) {
      return [...storeSnap.docs, ...clientSnap.docs];
    });
  }

  // 🛠️ دالة مساعدة لتنسيق حقول البيانات في الـ Alert
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  // 🛠️ دالة مساعدة لعرض تفاصيل الأصناف (لأوردرات المحلات فقط)
  Widget _buildItemsList(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return const Text('لا توجد أصناف محددة.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          'تفاصيل الأصناف:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 5),
        ...items.map((item) {
          final String name = item['name']?.toString() ?? 'صنف غير معروف';
          final String size = item['size']?.toString() ?? '';
          final int quantity = item['quantity'] as int? ?? 1;
          final double subtotal = (item['subtotal'] as num? ?? 0.0).toDouble();

          return Padding(
            padding: const EdgeInsets.only(bottom: 5.0, right: 10),
            child: Text(
              '• $name (${size.trim()}) x$quantity - الإجمالي: ${subtotal.toStringAsFixed(2)} جنيه',
              style: const TextStyle(fontSize: 14),
            ),
          );
        }),
        const Divider(),
      ],
    );
  }

  // 💡 الدالة الأساسية لعرض تفاصيل الأوردر في Alert Dialog
  void _showOrderDetailsDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    final bool isStoreOrder = data.containsKey('storeName');
    final String orderType = isStoreOrder ? 'اوردر زد' : 'اوردر توصيل';
    final String orderNumber = (data['orderNumber'] != null)
        ? data['orderNumber'].toString()
        : docId.substring(0, 5);
    final String priceType = isStoreOrder ? 'deliveryFee' : 'deliveryPrice';
    final double deliveryPrice = (data[priceType] is num)
        ? data[priceType].toDouble()
        : 0.0;

    // 🛠️ بناء محتوى الـ Alert
    final List<Widget> detailsWidgets = [];

    // الحقول المشتركة/الأساسية
    detailsWidgets.add(_buildDetailRow('نوع الأوردر', orderType));
    detailsWidgets.add(_buildDetailRow('رقم الأوردر', orderNumber));

    detailsWidgets.add(
      _buildDetailRow(
        'سعر التوصيل ',
        '${deliveryPrice.toStringAsFixed(2)} جنيه',
      ),
    );

    final Timestamp? deliveredAt = data['deliveredAt'] as Timestamp?;
    final String formattedDate = deliveredAt != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(deliveredAt.toDate())
        : 'غير متاح';
    detailsWidgets.add(_buildDetailRow('وقت التسليم', formattedDate));

    // ----------------------------------------------------
    // حقول خاصة بأوردر زد (orders)
    if (isStoreOrder) {
      detailsWidgets.add(const Divider());
      detailsWidgets.add(
        const Text(
          'بيانات أوردر زد :',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.indigo,
          ),
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'اسم المحل',
          data['storeName']?.toString() ?? 'غير متاح',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'عنوان المحل',
          data['storeAddress']?.toString() ?? 'غير متاح',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'اسم العميل',
          data['customerName']?.toString() ?? 'غير متاح',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'هاتف العميل',
          data['customerPhone']?.toString() ?? 'غير متاح',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'إجمالي الأصناف',
          '${(data['totalItemsPrice'] as num? ?? 0.0).toStringAsFixed(2)} جنيه',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'الإجمالي النهائي (على العميل)',
          '${(data['grandTotal'] as num? ?? 0.0).toStringAsFixed(2)} جنيه',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'ملاحظات العميل',
          data['customerNotes']?.toString() ?? 'لا يوجد',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'عنوان التسليم',
          data['customerAddress']?.toString() ?? 'غير متاح',
        ),
      );

      // إضافة تفاصيل الأصناف
      detailsWidgets.add(_buildItemsList(data['items'] as List<dynamic>?));
    }
    // ----------------------------------------------------
    // حقول خاصة بأوردر توصيل (client_orders)
    else {
      detailsWidgets.add(const Divider());
      detailsWidgets.add(
        const Text(
          'بيانات أوردر التوصيل (العميل):',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.indigo,
          ),
        ),
      );
      // في أوردرات التوصيل، 'storeAddress' هو مكان الاستلام.
      detailsWidgets.add(
        _buildDetailRow(
          'مكان الاستلام',
          data['storeAddress']?.toString() ?? 'غير متاح',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'وصف الطلب',
          data['orderDescription']?.toString() ?? 'لا يوجد وصف',
        ),
      );
      detailsWidgets.add(
        _buildDetailRow(
          'عنوان التسليم',
          data['customerAddress']?.toString() ?? 'غير متاح',
        ),
      );
    }
    // ----------------------------------------------------

    // عرض الـ Alert Dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '$orderType رقم $orderNumber',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.blue,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: detailsWidgets,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إغلاق', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الأوردرات المكتملة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _getCompletedOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد أوردرات مكتملة حتى الآن.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final completedOrders = snapshot.data!;

          completedOrders.sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['deliveredAt'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['deliveredAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: completedOrders.length,
            itemBuilder: (context, index) {
              final doc = completedOrders[index];
              final data = doc.data() as Map<String, dynamic>;

              String orderType = '';
              String name = '';
              double price = 0.0;
              String orderNumber = '';
              Timestamp? deliveredAt = data['deliveredAt'] as Timestamp?;

              if (data.containsKey('storeName')) {
                // أوردر زد
                orderType = 'اوردر زد';
                name = data['storeName']?.toString() ?? 'غير معروف';
                price = (data['deliveryFee'] is num)
                    ? data['deliveryFee'].toDouble()
                    : 0.0;
                orderNumber = (data['orderNumber'] != null)
                    ? data['orderNumber'].toString()
                    : doc.id.substring(0, 5);
              } else {
                // أوردر توصيل (عميل)
                orderType = 'اوردر توصيل';
                name = data['customerName']?.toString() ?? 'غير معروف';
                price = (data['deliveryPrice'] is num)
                    ? data['deliveryPrice'].toDouble()
                    : 0.0;
                orderNumber = doc.id.substring(0, 5);
              }

              String formattedDate = deliveredAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(deliveredAt.toDate())
                  : 'غير متاح';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: InkWell(
                  onTap: () {
                    // 💡 هنا بنستدعي دالة عرض التفاصيل
                    _showOrderDetailsDialog(context, data, doc.id);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 💡 عرض رقم الأوردر بجانب نوع الأوردر
                        Text(
                          '$orderType رقم: $orderNumber',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'لـ: $name',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'سعر التوصيل: ${price.toStringAsFixed(2)} جنيه',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'تاريخ التسليم: $formattedDate',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
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
      ),
    );
  }
}
