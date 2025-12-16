// في ملف PreviousOrdersPage.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zed/order_details_page.dart'; // أو المسار الصحيح للملف

class PreviousOrdersPage extends StatelessWidget {
  const PreviousOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('الأوردرات السابقة'), centerTitle: true),
        body: Center(child: Text('من فضلك سجل الدخول لعرض أوردراتك السابقة.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الأوردرات السابقة'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customer_id', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .orderBy('timestamp', descending: true)
            .limit(10) // ✅ آخر 10 أوردرات فقط
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد لديك أوردرات سابقة.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;

              // لعرض التاريخ بطريقة واضحة
              final timestamp = order['timestamp'] as Timestamp;
              final dateTime = timestamp.toDate();
              final formattedDate =
                  '${dateTime.day}/${dateTime.month}/${dateTime.year}';

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: ListTile(
                  title: Text(
                    'طلب من: ${order['storeName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'الإجمالي: ${(order['grandTotal'] ?? 0).toStringAsFixed(2)} جنيه\nالتاريخ: $formattedDate',
                  ),
                  onTap: () {
                    // ✅ الكود اللي بينقل المستخدم لصفحة التفاصيل
                    final orderId = orders[index].id;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            OrderDetailsPage(orderId: orderId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
