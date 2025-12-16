import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class AgentWalletScreen extends StatefulWidget {
  final String agentPhone; // هنستخدم رقم المندوب عشان نجيب بياناته

  const AgentWalletScreen({super.key, required this.agentPhone});

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen> {
  final Logger _logger = Logger(); // عشان نسجل الأخطاء والتحذيرات

  // دالة للاتصال برقم تليفون
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _logger.e('Could not launch $phoneNumber'); //
      }
    } catch (e) {
      _logger.e('Error launching phone call: $e'); //
    }
  }

  // Widget عشان نبني كروت البيانات بشكل موحد
  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isWarning = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha((255 * 0.1).round()),
              radius: 28,
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isWarning ? Colors.red.shade700 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal, // لون مميز للمحفظة
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // بنجيب بيانات المندوب من الـ 'agents' collection باستخدام agentPhone
        stream: FirebaseFirestore.instance
            .collection('agents')
            .doc(widget.agentPhone)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            _logger.e('Error fetching agent wallet data: ${snapshot.error}'); //
            return Center(
              child: Text(
                'حدث خطأ: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data == null ||
              !snapshot.data!.exists) {
            _logger.w(
              'Agent wallet data not found for ${widget.agentPhone}',
            ); //
            return const Center(
              child: Text('لا توجد بيانات محفظة لهذا المندوب حالياً.'),
            );
          }

          // بنحول البيانات لـ Map عشان نقدر نقرا منها
          final Map<String, dynamic>? agentData =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (agentData == null) {
            _logger.w('Agent data map is null for ${widget.agentPhone}'); //
            return const Center(child: Text('لا توجد بيانات محفظة صالحة.'));
          }

          // قراءة البيانات مع التعامل الآمن مع القيم اللي ممكن تكون مش موجودة أو نوعها غلط
          final num totalEarningsNum = agentData['totalEarnings'] is num
              ? agentData['totalEarnings']
              : 0.0; //
          final double totalEarnings = totalEarningsNum.toDouble(); //

          final num completedOrdersCountNum =
              agentData['completedOrdersCount'] is num
              ? agentData['completedOrdersCount']
              : 0; //
          final int completedOrdersCount = completedOrdersCountNum.toInt(); //

          final num commissionRateNum = agentData['commissionRate'] is num
              ? agentData['commissionRate']
              : 0.0; //
          final double commissionRate = commissionRateNum.toDouble(); //

          final num duesLimitNum = agentData['duesLimit'] is num
              ? agentData['duesLimit']
              : 0.0; //
          final double duesLimit = duesLimitNum.toDouble(); //

          final String paymentPhoneNumber =
              agentData['paymentPhoneNumber']?.toString() ?? 'غير متاح'; //
          final bool isActive = agentData['isActive'] is bool
              ? agentData['isActive']
              : true; //
          // لو الـ isActive مش موجودة أو مش bool، هنعتبرها true افتراضيا عشان المندوب يعرف يشتغل

          // حساب المبلغ المستحق الجاري
          final double currentDues = (totalEarnings * commissionRate).isFinite
              ? totalEarnings * commissionRate
              : 0.0; //

          // تحديد حالة التحذير وإيقاف الحساب
          final bool duesApproachingLimit =
              currentDues >= (duesLimit * 0.8) && currentDues < duesLimit; //
          final bool duesExceededLimit = currentDues >= duesLimit; //

          // لو المستحقات عدت الـ duesLimit، لازم نوقف الحساب ونعمل update في Firestore
          // بس لازم ناخد بالنا إن الـ update ده مايتعملش كل مرة الـ build method بتشتغل
          // لو عايزين نتحكم في ده بشكل أدق، ممكن نعملها في FutureBuilder أو StreamSubscription
          // أو Check بسيط هنا لو قيمة isActive لسه true مع إن المستحقات تجاوزت
          if (duesExceededLimit && isActive) {
            // بنعمل update لمرة واحدة بس عشان نوقف الحساب
            FirebaseFirestore.instance
                .collection('agents')
                .doc(widget.agentPhone)
                .update({'isActive': false})
                .catchError((e) {
                  _logger.e('Error updating isActive status: $e'); //
                });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // كارت الأرباح وعدد الأوردرات المكتملة في صف واحد
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        title: 'إجمالي الأرباح',
                        value: '${totalEarnings.toStringAsFixed(2)} جنيه', //
                        icon: Icons.monetization_on,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        title: 'أوردرات مكتملة',
                        value: '$completedOrdersCount طلب', //
                        icon: Icons.assignment_turned_in,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'النسبة المحددة (عمولة التطبيق)',
                  value: '${(commissionRate * 100).toStringAsFixed(1)}%', //
                  icon: Icons.percent,
                  color: Colors.purple,
                ),
                _buildInfoCard(
                  title: 'إجمالي المبلغ المستحق دفعه (حد المستحقات)',
                  value: '${duesLimit.toStringAsFixed(2)} جنيه', //
                  icon: Icons.attach_money,
                  color: Colors.orange,
                ),
                _buildInfoCard(
                  title: 'المبلغ المستحق الجاري',
                  value: '${currentDues.toStringAsFixed(2)} جنيه', //
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.redAccent,
                  isWarning:
                      duesApproachingLimit ||
                      duesExceededLimit, // هتخلي اللون أحمر لو في تحذير
                ),
                const SizedBox(height: 24),

                // رسائل التحذير وإيقاف الحساب
                Visibility(
                  visible: duesApproachingLimit, //
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تنبيه! المستحقات قاربت الحد الأقصى. يرجى السداد قريباً لتجنب إيقاف الحساب.', //
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Visibility(
                  visible: duesExceededLimit, //
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تحذير! تم تجاوز الحد الأقصى للمستحقات.', //
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'تم إيقاف حسابك مؤقتاً. لن تتمكن من قبول طلبات جديدة أو تسجيل الدخول حتى يتم سداد المستحقات بالكامل.', //
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // زرار الاتصال بالإدارة
                Visibility(
                  visible: paymentPhoneNumber.isNotEmpty, //
                  child: Column(
                    children: [
                      Text(
                        'للسداد، يرجى التواصل مع الإدارة على الرقم:', //
                        style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: paymentPhoneNumber != 'غير متاح'
                              ? () =>
                                    _makePhoneCall(paymentPhoneNumber) //
                              : null, // تعطيل الزرار لو الرقم مش متاح
                          icon: const Icon(Icons.call, color: Colors.white),
                          label: Text(
                            paymentPhoneNumber, //
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      // 💡 هنا تم إضافة الـ BannerAdWidget في الـ bottomNavigationBar
    );
  }
}
