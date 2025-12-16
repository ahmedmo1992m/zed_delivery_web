// mandoob_login_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'mandoob_home_page.dart';
import 'super_admin_dashboard_page.dart';
import 'manager_home_page.dart';
import 'pages/client_auth_screen.dart';

class MandoobLoginPage extends StatefulWidget {
  const MandoobLoginPage({super.key});

  @override
  MandoobLoginPageState createState() => MandoobLoginPageState();
}

class MandoobLoginPageState extends State<MandoobLoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  static const String _whatsappNumber = '+201500083403';

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateAgentStatusInFirestore(
    String agentId,
    bool isOnline, {
    String? fcmToken,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'isOnline': isOnline,
        'latitude': null,
        'longitude': null,
        'lastLocationUpdateAt': FieldValue.serverTimestamp(),
      };

      if (fcmToken != null && isOnline) {
        updateData['fcmToken'] = fcmToken;
      }

      await FirebaseFirestore.instance
          .collection('agents')
          .doc(agentId)
          .set(updateData, SetOptions(merge: true));

      debugPrint('Agent status updated in Firestore: $isOnline for $agentId');
    } catch (e) {
      debugPrint('Error updating agent status in Firestore: $e');
    }
  }

  Future<void> _login() async {
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم المستخدم وكلمة السر')),
      );
      return;
    }

    try {
      DocumentSnapshot superAdminDoc = await FirebaseFirestore.instance
          .collection('super_admins')
          .doc(username)
          .get();

      if (superAdminDoc.exists && superAdminDoc.data() != null) {
        Map<String, dynamic> adminData =
            superAdminDoc.data() as Map<String, dynamic>;
        String storedAdminPassword = adminData.containsKey('password')
            ? adminData['password']
            : '';
        String adminName = adminData.containsKey('adminName')
            ? adminData['adminName']
            : 'سوبر أدمن';

        if (storedAdminPassword == password) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تسجيل الدخول كمسؤول عام بنجاح!'),
            ),
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userType', 'super_admin');
          await prefs.setString('adminName', adminName);
          await prefs.setString('adminId', username);

          usernameController.clear();
          passwordController.clear();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SuperAdminDashboardPage(adminName: adminName),
            ),
          );
          return;
        }
      }

      DocumentSnapshot managerDoc = await FirebaseFirestore.instance
          .collection('managers')
          .doc(username)
          .get();

      if (managerDoc.exists && managerDoc.data() != null) {
        Map<String, dynamic> managerData =
            managerDoc.data() as Map<String, dynamic>;
        String storedManagerPassword = managerData.containsKey('password')
            ? managerData['password']
            : '';
        String managerName = managerData.containsKey('managerName')
            ? managerData['managerName']
            : 'مدير';
        String managerPhone = managerData.containsKey('phone')
            ? managerData['phone']
            : '';

        if (storedManagerPassword == password) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم تسجيل الدخول كمدير بنجاح!')),
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userType', 'manager');
          await prefs.setString('managerId', username);
          await prefs.setString('managerName', managerName);
          await prefs.setString('managerPhone', managerPhone);

          usernameController.clear();
          passwordController.clear();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ManagerHomePage(
                managerName: managerName,
                managerId: username,
              ),
            ),
          );
          return;
        }
      }

      DocumentSnapshot agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(username)
          .get();

      if (!mounted) return;

      if (agentDoc.exists && agentDoc.data() != null) {
        String storedPassword = agentDoc['password'] ?? '';
        String agentName = agentDoc['agentName'] ?? 'غير معروف';
        String agentPhone = agentDoc['agentPhone'] ?? '';

        double commissionRate = (agentDoc['commissionRate'] is num)
            ? agentDoc['commissionRate'].toDouble()
            : 0.10;
        int completedOrdersCount = (agentDoc['completedOrdersCount'] is int)
            ? agentDoc['completedOrdersCount']
            : 0;

        double currentDues = 0.0;

        if (agentDoc['currentDues'] != null) {
          dynamic duesValue = agentDoc['currentDues'];
          if (duesValue is num) {
            currentDues = duesValue.toDouble();
          } else if (duesValue is String) {
            currentDues = double.tryParse(duesValue) ?? 0.0;
          }
        }

        double duesLimit = (agentDoc['duesLimit'] is num)
            ? agentDoc['duesLimit'].toDouble()
            : 500.0;
        bool isActive = agentDoc['isActive'] ?? true;

        String? paymentPhoneNumber = (agentDoc['paymentPhoneNumber'] is String)
            ? agentDoc['paymentPhoneNumber']
            : (agentDoc['paymentPhoneNumber'] is num
                  ? agentDoc['paymentPhoneNumber'].toString()
                  : null);

        double totalEarnings = (agentDoc['totalEarnings'] is num)
            ? agentDoc['totalEarnings'].toDouble()
            : 0.0;

        bool hasActiveOrder = agentDoc['hasActiveOrder'] ?? false;

        if (!isActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم إيقاف حسابك. الرجاء التواصل مع الإدارة.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        if (currentDues >= duesLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لقد وصلت للحد الأقصى للمستحقات ($duesLimit جنيه). يرجى السداد لمواصلة العمل.',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        if (storedPassword == password) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم تسجيل الدخول بنجاح!')),
          );

          String? fcmToken = await FirebaseMessaging.instance.getToken();
          debugPrint('FCM Token on login: $fcmToken');

          await _updateAgentStatusInFirestore(
            username,
            true,
            fcmToken: fcmToken,
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userType', 'agent');
          await prefs.setString('agentId', username);
          await prefs.setString('agentName', agentName);
          await prefs.setString('agentPhone', agentPhone);
          await prefs.setDouble('commissionRate', commissionRate);
          await prefs.setInt('completedOrdersCount', completedOrdersCount);
          await prefs.setDouble('currentDues', currentDues);
          await prefs.setDouble('duesLimit', duesLimit);
          await prefs.setBool('isActive', isActive);

          if (paymentPhoneNumber != null) {
            await prefs.setString('paymentPhoneNumber', paymentPhoneNumber);
          } else {
            await prefs.remove('paymentPhoneNumber');
          }

          await prefs.setDouble('totalEarnings', totalEarnings);

          usernameController.clear();
          passwordController.clear();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MandoobHomePage(
                agentName: agentName,
                agentPhone: agentPhone,
                onOrderDelivered: () {},
                onLogout: () {},
                hasActiveOrder: hasActiveOrder,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ كلمة السر غير صحيحة')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ اسم المستخدم غير موجود أو كلمة السر غير صحيحة'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء تسجيل الدخول: $e')),
      );
      debugPrint('Login error: $e');
    }
  }

  void _navigateToClientLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ClientAuthScreen()),
    );
  }

  Future<void> _launchWhatsApp() async {
    final String message =
        "مرحباً، أود إنشاء حساب جديد في تطبيقكم والاشتراك معكم.";
    final Uri url = Uri.parse(
      "whatsapp://send?phone=$_whatsappNumber&text=${Uri.encodeComponent(message)}",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن فتح الواتساب. يرجى التأكد من تثبيت تطبيق الواتساب على جهازك.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تسجيل الدخول (المناديب/الإدارة)',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),

            TextField(
              controller: usernameController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم (ID أو رقم الهاتف)',
                hintText: 'أدخل اسم المستخدم الخاص بك',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                hintText: 'أدخل كلمة السر الخاصة بك',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
              child: const Text(
                'تسجيل الدخول (مناديب/إدارة)',
                style: TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 15),

            OutlinedButton(
              onPressed: _navigateToClientLogin,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    'تسجيل الدخول كعميل',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            Text(
              'لإنشاء حساب جديد والاشتراك معنا، يرجى إرسال البيانات التالية عبر الواتساب:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),

            const SizedBox(height: 10),

            Text(
              '• اسمك الكامل\n• رقم هاتفك\n• صورة واضحة لبطاقة هويتك (الوجهين)',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'تواصل معنا الآن على الواتساب:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),

            const SizedBox(height: 5),

            GestureDetector(
              onTap: _launchWhatsApp,
              child: const Text(
                '01556798005',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
