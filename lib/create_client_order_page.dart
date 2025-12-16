import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateClientOrderPage extends StatefulWidget {
  const CreateClientOrderPage({super.key});

  @override
  State<CreateClientOrderPage> createState() => _CreateClientOrderPageState();
}

class _CreateClientOrderPageState extends State<CreateClientOrderPage> {
  // 📝 متحكمات حقول الإدخال
  final TextEditingController _fromController =
      TextEditingController(); // من أين (عنوان المحل/البداية)
  final TextEditingController _toController =
      TextEditingController(); // إلى أين (عنوان العميل/النهاية)
  final TextEditingController _detailsController =
      TextEditingController(); // تفاصيل الأوردر
  final TextEditingController _deliveryPriceController =
      TextEditingController(); // سعر التوصيل

  bool _isLoading = false;

  // 🚀 دالة إرسال الطلب
  Future<void> _submitOrder() async {
    if (_fromController.text.isEmpty ||
        _toController.text.isEmpty ||
        _deliveryPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك املأ كل الحقول المطلوبة!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final double deliveryPrice = double.parse(_deliveryPriceController.text);

      // 📦 البيانات اللي هتتبعت لـ Firestore
      await FirebaseFirestore.instance.collection('client_orders').add({
        'orderType': 'اوردر توصيل', // عشان نميزه عن أوردرات المحلات
        'customerAddress': _toController.text.trim(), // إلى أين
        'storeAddress': _fromController.text.trim(), // من أين (كموقع التقاط)
        'orderDescription': _detailsController.text.trim(), // التفاصيل
        'deliveryPrice': deliveryPrice,
        'status': 'pending', // حالة الطلب معلق في انتظار القبول
        'timestamp':
            FieldValue.serverTimestamp(), // بدل createdAt عشان الكارت يقرأها
        // 💡 ممكن تضيف:
        // 'createdBy': 'المدير الفلاني',
        // 'grandTotal': deliveryPrice, // مؤقتاً الإجمالي هو سعر التوصيل لحين التحديث
      });

      // 🥳 نجاح الإرسال
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء أوردر التوصيل بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // الرجوع للصفحة الرئيسية
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: تأكد من أن سعر التوصيل رقم صحيح. $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 📝 دالة بناء حقول الإدخال
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.deepPurple.shade50,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إنشاء أوردر توصيل جديد',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade500, // نفس لون الزرار
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. من أين (عنوان المحل/البداية)
            _buildTextField(
              controller: _fromController,
              label: 'من أين (عنوان الاستلام)',
              icon: Icons.location_on,
            ),
            // 2. إلى أين (عنوان العميل/النهاية)
            _buildTextField(
              controller: _toController,
              label: 'إلى أين (عنوان التسليم)',
              icon: Icons.location_on_sharp,
            ),
            // 3. تفاصيل الأوردر
            _buildTextField(
              controller: _detailsController,
              label: 'تفاصيل الأوردر (اختياري)',
              icon: Icons.description,
              keyboardType: TextInputType.multiline,
            ),
            // 4. سعر التوصيل
            _buildTextField(
              controller: _deliveryPriceController,
              label: 'سعر التوصيل (جنيه)',
              icon: Icons.delivery_dining,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 30),

            // 5. زر إرسال الطلب
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitOrder,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _isLoading ? 'جاري الإرسال...' : 'إرسال الطلب',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
