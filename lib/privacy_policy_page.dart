import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سياسات وخصوصية زد'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // مقدمة
            const Center(
              child: Text(
                'مرحبًا بك في تطبيق زد 🚀',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'تطبيق التوصيل السريع الذي يوصلك بأي شيء لأي مكان، ويساعد المحلات والاوردرات الاون لاين على توصيل منتجاتها بسهولة وأمان.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // جمع المعلومات
            Row(
              children: const [
                Icon(Icons.info, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'جمع المعلومات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'نقوم بجمع المعلومات الأساسية مثل:\n'
              '- الاسم: أحمد محمد\n'
              '- رقم الهاتف: 01556798005 \n'
              '- العنوان: المنصورة\n'
              'ونستخدم موقعك الجغرافي (GPS) لتسهيل عملية التوصيل بدقة.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // استخدام المعلومات
            Row(
              children: const [
                Icon(Icons.settings, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'استخدام المعلومات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '- لتسهيل الطلبات والتواصل معك عند الحاجة.\n'
              '- نضمن عدم مشاركة بياناتك مع أي طرف خارجي بدون إذنك، إلا إذا كان مطلوبًا قانونيًا.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // حماية البيانات
            Row(
              children: const [
                Icon(Icons.lock, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'حماية البيانات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'نتبع أفضل ممارسات الأمان لحماية معلوماتك من أي اختراق أو استخدام غير مصرح به.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // سياسات الدفع
            Row(
              children: const [
                Icon(Icons.payment, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'سياسات الدفع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '- جميع المدفوعات تتم بطريقة آمنة عبر التطبيق.\n'
              '- نحتفظ بسجلات الدفع لفترة مناسبة لضمان حقوق الجميع.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // الالتزام بالقوانين
            Row(
              children: const [
                Icon(Icons.gavel, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'الالتزام بالقوانين',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'يُمنع استخدام التطبيق لأغراض غير قانونية أو ضارة.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // مواعيد العمل
            Row(
              children: const [
                Icon(Icons.access_time, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'مواعيد العمل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'متاح لتلقي الطلبات من 8:00 صباحًا حتى 4:00 فجراً يوميًا.\n'
              'خارج هذه المواعيد، يمكن ترك الطلب وسيتم التعامل معه عند بدء الدوام.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // التواصل معنا
            Row(
              children: const [
                Icon(Icons.phone, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'التواصل معنا',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'لأي استفسار أو شكوى:\n'
              '- الاسم: أحمد عزب\n'
              '- رقم الهاتف: 01556798005 \n'
              '- العنوان: المنصورة',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
