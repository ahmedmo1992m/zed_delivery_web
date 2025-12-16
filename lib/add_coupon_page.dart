import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCouponPage extends StatefulWidget {
  const AddCouponPage({super.key});

  @override
  State<AddCouponPage> createState() => _AddCouponPageState();
}

class _AddCouponPageState extends State<AddCouponPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController maxUsesController = TextEditingController();

  DateTime? expiryDate;
  bool loading = false;

  final CollectionReference couponsRef = FirebaseFirestore.instance.collection(
    'coupons',
  );

  Future<void> addCoupon() async {
    if (!_formKey.currentState!.validate() || expiryDate == null) return;

    setState(() => loading = true);

    await couponsRef.doc(codeController.text.trim()).set({
      'discount': double.parse(discountController.text), // المبلغ مباشرة
      'maxUses': int.parse(maxUsesController.text),
      'expiry': Timestamp.fromDate(expiryDate!),
      'usedBy': [],
      'active': true, // حقل التفعيل/الإيقاف
    });

    setState(() {
      loading = false;
      codeController.clear();
      discountController.clear();
      maxUsesController.clear();
      expiryDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة كوبونات الخصم'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // FORM لإضافة كوبون
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود الكوبون (مثال: WELCOME10)',
                    ),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة الخصم (%)',
                    ),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: maxUsesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد مرات الاستخدام',
                    ),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(
                      expiryDate == null
                          ? 'اختر تاريخ الانتهاء'
                          : expiryDate.toString(),
                    ),
                    trailing: const Icon(Icons.date_range),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                        initialDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => expiryDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: loading ? null : addCoupon,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text('إضافة الكوبون'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // LIST لكل الكوبونات
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: couponsRef.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('لا توجد كوبونات'));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(doc.id),
                          subtitle: Text(
                            'خصم: ${data['discount']}% | الاستخدام: ${data['maxUses']} | منتهي: ${data['expiry'].toDate()}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  data['active']
                                      ? Icons.toggle_on
                                      : Icons.toggle_off,
                                  color: data['active']
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 30,
                                ),
                                onPressed: () async {
                                  await couponsRef.doc(doc.id).update({
                                    'active': !data['active'],
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  bool confirm =
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('تأكيد الحذف'),
                                          content: Text(
                                            'هل تريد حذف الكوبون ${doc.id}?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('لا'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('نعم'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                  if (confirm) {
                                    await couponsRef.doc(doc.id).delete();
                                  }
                                },
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
          ],
        ),
      ),
    );
  }
}
