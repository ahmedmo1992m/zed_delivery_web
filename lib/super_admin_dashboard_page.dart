// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:zed/super_admin_manage_agents.dart';
import 'package:zed/super_admin_manage_stores.dart';
import 'package:zed/super_admin_earnings_dues_page.dart'; // 💡 استيراد الصفحة الجديدة
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zed/mandoob_login_page.dart';
import 'package:zed/add_coupon_page.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  final String adminName;

  const SuperAdminDashboardPage({super.key, required this.adminName});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userType');
    await prefs.remove('adminName');
    await prefs.remove('adminId');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MandoobLoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // تم حذف key: _scaffoldKey
      appBar: AppBar(
        title: Text(
          'مرحباً بك، ${widget.adminName}!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      // تم حذف endDrawer بالكامل
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDashboardCard(
              context,
              title: 'إدارة المناديب',
              icon: Icons.delivery_dining,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SuperAdminManageAgentsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16.0),
            _buildDashboardCard(
              context,
              title: 'إدارة المحلات',
              icon: Icons.store,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SuperAdminManageStoresPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16.0),
            _buildDashboardCard(
              context,
              title: 'إضافة كوبونات خصم',
              icon: Icons.discount,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCouponPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16.0),
            _buildDashboardCard(
              context,
              title: 'إدارة الأرباح والمستحقات',
              icon: Icons.attach_money,
              color: Colors.green,
              onTap: () {
                // 💡 الانتقال إلى الصفحة الجديدة بدلاً من فتح الدرج
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SuperAdminEarningsDuesPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // 💡 هنا تم إضافة الـ BannerAdWidget في الـ bottomNavigationBar
    );
  }

  // Widget مساعدة لبناء حقول الدرج للقراءة فقط (لم تعد تستخدم للعرض الرئيسي للأرباح)
  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          // 💡 تم إضافة Padding هنا لتحسين المسافات الداخلية
          padding: const EdgeInsets.all(20.0), // 💡 مسافة داخلية موحدة
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
