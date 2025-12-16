import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // For making phone calls
import 'dart:async'; // For StreamSubscription
import 'manager_agents_page.dart'; // Make sure this path is correct
import 'mandoob_login_page.dart'; // Make sure this path is correct
import 'manager_pending_orders_page.dart'; // Make sure this path is correct
import 'create_client_order_page.dart';

class ManagerHomePage extends StatefulWidget {
  final String managerName;
  final String managerId; // معرف المدير، يتم تمريره هنا

  const ManagerHomePage({
    super.key,
    required this.managerName,
    required this.managerId, // يجب أن يكون managerId مطلوبًا هنا
  });

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  Map<String, dynamic>? _managerData; // To store current manager's data
  StreamSubscription<DocumentSnapshot>? _managerDataSubscription;

  // Controllers for adding new store dialog
  final TextEditingController _newStoreNameController = TextEditingController();
  final TextEditingController _newStorePhoneController =
      TextEditingController();
  final TextEditingController _newStoreAddressController =
      TextEditingController();
  final TextEditingController _newStoreRegionController =
      TextEditingController();
  final TextEditingController _newStorePasswordController =
      TextEditingController();
  // 💡 إضافة متحكم جديد لمعرف المحل
  final TextEditingController _newStoreIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenToManagerData(); // Start listening to manager's data
  }

  @override
  void dispose() {
    _managerDataSubscription?.cancel();
    _newStoreNameController.dispose();
    _newStorePhoneController.dispose();
    _newStoreAddressController.dispose();
    _newStoreRegionController.dispose();
    _newStorePasswordController.dispose();
    _newStoreIdController.dispose(); // 💡 التخلص من المتحكم الجديد
    super.dispose();
  }

  // Listen to real-time updates for the manager's own document
  void _listenToManagerData() {
    _managerDataSubscription = FirebaseFirestore.instance
        .collection('managers')
        .doc(widget.managerId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              setState(() {
                _managerData = snapshot.data() as Map<String, dynamic>;
              });
              _checkManagerDuesAndSuspend(); // Check manager's dues on update
            }
          },
          onError: (error) {
            debugPrint('Error listening to manager data: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('خطأ في تحميل بيانات المدير: $error')),
              );
            }
          },
        );
  }

  // Function to handle manager logout (now as a bottom sheet)
  Future<void> _showLogoutBottomSheet() async {
    // 💡 ننتظر هنا حتى يتم إغلاق الـ BottomSheet بالكامل
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl, // Right-to-left for Arabic
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear(); // Clear all stored user data

                        // 💡 نقوم بإغلاق الـ BottomSheet هنا
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        // بعد الـ pop، الكود الموجود خارج الـ builder (بعد await showModalBottomSheet) هو اللي هيتنفذ
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('تسجيل الخروج'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop(); // Close bottom sheet
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB39DDB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ); // 💡 الـ await هنا هيضمن إن الـ BottomSheet اتقفل

    // 💡 هذا الكود سيتم تنفيذه فقط بعد أن يتم إغلاق الـ BottomSheet بالكامل
    if (!mounted) return; // إعادة فحص mounted status
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MandoobLoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  // Function to make a phone call
  Future<void> _launchCaller(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يمكن إجراء المكالمة')));
    }
  }

  // Function to show Manager's Financial Details as a bottom sheet
  Future<void> _showManagerFinancialsBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow content to be scrollable
      builder: (BuildContext context) {
        bool isManagerActive = _managerData?['isActive'] ?? true;
        // 💡 جلب إجمالي الأرباح ونسبة العمولة من حقل 'totalEarnings' و 'commissionRate'
        double managerTotalEarnings = (_managerData?['totalEarnings'] is num)
            ? _managerData!['totalEarnings'].toDouble()
            : 0.0;
        // 💡 استخدام حقل 'commissionRate' من Firestore مباشرة
        double managerCommissionRate = (_managerData?['commissionRate'] is num)
            ? _managerData!['commissionRate'].toDouble()
            : 0.0; // Default to 0.0 if not found

        // 💡 حساب المستحق على المدير دفعه بناءً على الأرباح والنسبة
        double managerCalculatedDues =
            managerTotalEarnings * managerCommissionRate;

        double managerDuesLimit = (_managerData?['duesLimit'] is num)
            ? _managerData!['duesLimit'].toDouble()
            : 0.0;
        String? managerPaymentPhoneNumber = _managerData?['paymentPhoneNumber'];

        return Directionality(
          textDirection: TextDirection.rtl, // Right-to-left for Arabic
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              // Use MediaQuery to make it responsive to keyboard and content
              height:
                  MediaQuery.of(context).size.height *
                  0.75, // 75% of screen height
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'تفاصيل الأرباح والمستحقات',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF673AB7),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(
                    'إجمالي أرباحك من المناديب: ${managerTotalEarnings.toStringAsFixed(2)} جنيه',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'المستحق عليك للدفع: ${managerCalculatedDues.toStringAsFixed(2)} جنيه', // 💡 عرض المبلغ المحسوب
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'حد المستحقات عليك: ${managerDuesLimit.toStringAsFixed(2)} جنيه',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  if (managerPaymentPhoneNumber != null &&
                      managerPaymentPhoneNumber.isNotEmpty)
                    Row(
                      children: [
                        Text(
                          'رقم الدفع: $managerPaymentPhoneNumber',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.call,
                            color: Color(0xFF673AB7),
                          ),
                          onPressed: () =>
                              _launchCaller(managerPaymentPhoneNumber),
                          tooltip: 'اتصال برقم الدفع',
                        ),
                      ],
                    )
                  else
                    const Text('رقم الدفع: غير متاح حالياً'),
                  const SizedBox(height: 10),
                  if (!isManagerActive)
                    const Text(
                      'حسابك موقوف. يرجى التواصل مع الإدارة للسداد.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  // Add more financial details or graphs if needed
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Function to check manager's dues and suspend account if necessary
  Future<void> _checkManagerDuesAndSuspend() async {
    if (_managerData == null) return;

    // 💡 جلب إجمالي الأرباح ونسبة العمولة من حقل 'totalEarnings' و 'commissionRate'
    double managerTotalEarnings = (_managerData!['totalEarnings'] is num)
        ? _managerData!['totalEarnings'].toDouble()
        : 0.0;
    double managerCommissionRate =
        (_managerData!['commissionRate']
            is num) // 💡 استخدام حقل 'commissionRate'
        ? _managerData!['commissionRate'].toDouble()
        : 0.0; // Default to 0.0 if not found

    // 💡 حساب المستحق على المدير دفعه بناءً على الأرباح والنسبة
    double managerCalculatedDues = managerTotalEarnings * managerCommissionRate;

    double managerDuesLimit = (_managerData?['duesLimit'] is num)
        ? _managerData!['duesLimit'].toDouble()
        : 0.0;
    bool managerIsActive = _managerData!['isActive'] ?? true;
    String? managerPaymentPhoneNumber = _managerData!['paymentPhoneNumber'];

    if (managerDuesLimit <= 0) {
      // Avoid division by zero or illogical limits
      return;
    }

    // 💡 استخدام managerCalculatedDues في حساب النسبة المئوية
    double percentage = (managerCalculatedDues / managerDuesLimit) * 100;

    if (percentage >= 100 && managerIsActive) {
      // Manager account suspension
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '❌ تم إيقاف حسابك كمدير بسبب تجاوز حد المستحقات!',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'الرجاء سداد المبلغ المستحق: ${managerCalculatedDues.toStringAsFixed(2)} جنيه', // 💡 عرض المبلغ المحسوب
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
              ),
              if (managerPaymentPhoneNumber != null &&
                  managerPaymentPhoneNumber.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'رقم الدفع: $managerPaymentPhoneNumber',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.white),
                      onPressed: () => _launchCaller(managerPaymentPhoneNumber),
                      tooltip: 'اتصال برقم الدفع',
                    ),
                  ],
                ),
              const Text(
                'سيتم إيقاف جميع المناديب التابعين لك.',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );

      // Update manager's isActive status
      await FirebaseFirestore.instance
          .collection('managers')
          .doc(widget.managerId)
          .update({'isActive': false});

      // Update all agents under this manager to isActive: false
      QuerySnapshot agentsSnapshot = await FirebaseFirestore.instance
          .collection('agents')
          .where('manager_id', isEqualTo: widget.managerId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in agentsSnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      await batch.commit();

      // Force logout the manager
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MandoobLoginPage()),
        (Route<dynamic> route) => false,
      );
    } else if (percentage >= 80 && percentage < 100 && managerIsActive) {
      // Warning for 80% threshold
      if (!mounted) return;
      debugPrint(
        'Manager Dues Warning: Percentage is ${percentage.toStringAsFixed(2)}%',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ تنبيه: لقد وصلت إلى ${percentage.toStringAsFixed(0)}% من حد المستحقات. يرجى السداد لتجنب إيقاف الحساب.',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isManagerActive = _managerData?['isActive'] ?? true;

    // 💡 جلب إجمالي الأرباح ونسبة العمولة هنا أيضاً لحساب الحدود في الـ UI
    double managerTotalEarnings = (_managerData?['totalEarnings'] is num)
        ? _managerData!['totalEarnings'].toDouble()
        : 0.0;
    double managerCommissionRate =
        (_managerData?['commissionRate']
            is num) // 💡 استخدام حقل 'commissionRate'
        ? _managerData!['commissionRate'].toDouble()
        : 0.0;
    double managerCalculatedDuesForUI =
        managerTotalEarnings * managerCommissionRate;
    double managerDuesLimit = (_managerData?['duesLimit'] is num)
        ? _managerData!['duesLimit'].toDouble()
        : 0.0;

    // 💡 حساب النسبة المئوية للمستحقات لعرضها في الـ UI
    double currentDuesPercentage = (managerDuesLimit > 0)
        ? (managerCalculatedDuesForUI / managerDuesLimit) * 100
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم المدير',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFB39DDB),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
            ), // 💡 أيقونة أرباح المدير
            onPressed: isManagerActive
                ? () {
                    _showManagerFinancialsBottomSheet(); // دالة عرض أرباح المدير
                  }
                : null,
            tooltip: 'تفاصيل الأرباح والمستحقات',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed:
                _showLogoutBottomSheet, // 💡 استدعاء الـ bottom sheet للخروج
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات المدير الأساسية (بدون تفاصيل الأرباح والمستحقات هنا)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (isManagerActive &&
                          currentDuesPercentage >=
                              80) // 💡 استخدام النسبة المحسوبة
                      ? Colors.orange.shade700
                      : (!isManagerActive
                            ? Colors.red.shade700
                            : Colors.transparent),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أهلاً بك يا أستاذ : ${widget.managerName}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF673AB7),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'معرف المدير (ID): ${widget.managerId}',
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  if (!isManagerActive)
                    const Text(
                      'حسابك موقوف. يرجى التواصل مع الإدارة للسداد.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // الأزرار الرئيسية في منتصف الصفحة
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🆕 1. زر إنشاء أوردر توصيل (الزر الجديد)
                    _buildFeatureButton(
                      context,
                      'إنشاء أوردر توصيل', // اسم الزرار
                      Icons.add_shopping_cart, // أيقونة عربية التسوق
                      isManagerActive
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CreateClientOrderPage(), // 👈 الصفحة الجديدة
                                ),
                              );
                            }
                          : null,
                      buttonColor: const Color.fromARGB(
                        255,
                        8,
                        218,
                        61,
                      ), // لون مميز (أخضر مزرق)
                    ),
                    const SizedBox(height: 20),

                    _buildFeatureButton(
                      context,
                      'إدارة المناديب',
                      Icons.people_alt,
                      isManagerActive
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ManagerAgentsPage(
                                    managerId: widget.managerId,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureButton(
                      context,
                      'الطلبات المعلقة',
                      Icons.list_alt,
                      isManagerActive
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ManagerPendingOrdersPage(
                                    managerId: widget
                                        .managerId, // 💡 تم تمرير managerId هنا
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 20), // 💡 مسافة بين الأزرار
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // لا يوجد bottomNavigationBar هنا، تم نقل زر الطلبات المعلقة لزر عادي
    );
  }

  // Helper widget for main feature buttons
  Widget _buildFeatureButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback? onPressed, {
    Color? buttonColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 30, color: Colors.white),
      label: Text(
        title,
        style: const TextStyle(fontSize: 20, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            buttonColor ??
            const Color.fromARGB(255, 13, 139, 80), // Deep purple
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 8,
        minimumSize: const Size(250, 70), // Fixed size for consistency
      ),
    );
  }
}
