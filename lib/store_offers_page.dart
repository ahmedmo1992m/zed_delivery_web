// store_offers_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_offer_page.dart';
import 'package:intl/intl.dart';

class StoreOffersPage extends StatefulWidget {
  final String storeId;
  const StoreOffersPage({super.key, required this.storeId});

  @override
  State<StoreOffersPage> createState() => _StoreOffersPageState();
}

class _StoreOffersPageState extends State<StoreOffersPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>> get _offersStream =>
      FirebaseFirestore.instance
          .collection('offers')
          .where('store_id', isEqualTo: widget.storeId)
          .orderBy('created_at', descending: true)
          .snapshots();

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    return DateFormat('yyyy-MM-dd').format(d);
  }

  // تم تعديل دالة بناء الكارت لعرض البيانات الجديدة فقط
  Widget _buildOfferCard(String docId, Map<String, dynamic> data) {
    final title = data['title'] ?? '-';
    final description = data['description'] ?? '-';
    final imageUrl = data['image_url'] ?? '';
    final active = data['active'] ?? true;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عرض الصورة لو موجودة
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            const SizedBox(height: 8),
            // عرض العنوان
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            // عرض التفاصيل
            Text(description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            // عرض مدة العرض
            Text(
              'المدة: ${_formatDate(data['start_date'])} → ${_formatDate(data['end_date'])}',
            ),
            const SizedBox(height: 2),
            // عرض حالة العرض وأزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الحالة: ${active ? 'نشط' : 'متوقف'}'),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        active ? Icons.pause_circle : Icons.play_circle,
                        color: Colors.blueAccent,
                      ),
                      tooltip: active ? 'إيقاف العرض' : 'تفعيل العرض',
                      onPressed: () => _toggleOfferStatus(docId, active),
                    ),

                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'حذف العرض',
                      onPressed: () => _deleteOffer(docId),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // باقي الدوال زي ما هي بدون تغيير
  Future<void> _toggleOfferStatus(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('offers').doc(docId).update({
      'active': !currentStatus,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(currentStatus ? 'تم إيقاف العرض' : 'تم تفعيل العرض'),
      ),
    );
  }

  Future<void> _deleteOffer(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا العرض؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('offers').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العرض')));
    }
  }

  Future<void> _goToAddOffer() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddOfferPage(storeId: widget.storeId)),
    );
    if (!mounted) return;
    if (added == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة العرض بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض المحل'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة عرض جديد',
            onPressed: _goToAddOffer,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _offersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('خطأ في تحميل العروض: ${snapshot.error}'),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد عروض لهذا المحل'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) => _buildOfferCard(docs[i].id, docs[i].data()),
          );
        },
      ),
    );
  }
}
