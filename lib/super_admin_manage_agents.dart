// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // لإجراء المكالمات

class SuperAdminManageAgentsPage extends StatefulWidget {
  const SuperAdminManageAgentsPage({super.key});

  @override
  State<SuperAdminManageAgentsPage> createState() =>
      _SuperAdminManageAgentsPageState();
}

class _SuperAdminManageAgentsPageState
    extends State<SuperAdminManageAgentsPage> {
  bool _showHighDuesAgentsOnly = false; // متغير للفلترة: مستحقات عالية
  bool _showOnlineAgentsOnly = false; // متغير جديد للفلترة: متواجدون فقط
  final TextEditingController _searchController =
      TextEditingController(); // متحكم لخانة البحث
  String _searchQuery = ''; // لتخزين نص البحث

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      _onSearchChanged,
    ); // الاستماع لتغييرات خانة البحث
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text
          .toLowerCase(); // تحويل النص لحروف صغيرة للبحث غير الحساس لحالة الأحرف
    });
  }

  /// دالة لفتح تطبيق الاتصال
  Future<void> _launchPhone(String phoneNumber) async {
    final Uri phoneCall = Uri.parse('tel:$phoneNumber');
    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(phoneCall)) {
      await launchUrl(phoneCall);
    } else {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال بالرقم.')),
      );
    }
  }

  // 📍 إضافة مندوب جديد
  void _showAddAgentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController agentIdCtrl = TextEditingController();
        final TextEditingController agentNameCtrl = TextEditingController();
        final TextEditingController passwordCtrl = TextEditingController();
        final TextEditingController phoneCtrl = TextEditingController();
        final TextEditingController paymentPhoneCtrl = TextEditingController();
        final TextEditingController managerIdCtrl =
            TextEditingController(); // متحكم جديد لـ manager_id

        final TextEditingController commissionRateCtrl = TextEditingController(
          text: '0.10',
        );
        final TextEditingController duesLimitCtrl = TextEditingController(
          text: '500.0',
        );
        final TextEditingController totalEarningsCtrl = TextEditingController(
          text: '0.0',
        );

        bool isOnlineValue = true; // القيمة الافتراضية عند الإضافة

        return AlertDialog(
          title: const Text('إضافة مندوب جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: agentIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'معرف المندوب (ID)',
                    hintText: 'يجب أن يكون فريدًا، مثال: رقم الهاتف',
                  ),
                ),
                TextField(
                  controller: agentNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المندوب',
                    hintText: 'مثال: أحمد محمد عزب',
                  ),
                ),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة السر',
                    hintText: 'كلمة السر لتسجيل الدخول',
                  ),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (agentPhone)',
                    hintText: 'مثال: 01556798005',
                  ),
                ),
                TextField(
                  controller: paymentPhoneCtrl,
                  keyboardType: TextInputType.number, // رقم الهاتف غالبًا رقم
                  decoration: const InputDecoration(
                    labelText: 'رقم هاتف الدفع (paymentPhoneNumber)',
                    hintText: 'مثال: 1500083403 (محفظة إلكترونية)',
                  ),
                ),
                TextField(
                  controller: managerIdCtrl, // حقل manager_id
                  decoration: const InputDecoration(
                    labelText: 'معرف المدير (manager_id)', // 💡 تم التعديل هنا
                    hintText: 'مثال: MGR001',
                  ),
                ),
                TextField(
                  controller: totalEarningsCtrl, // 🆕 حقل إجمالي الأرباح
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'إجمالي الأرباح (totalEarnings)',
                    hintText: 'القيمة الأولية للأرباح، مثال: 0.0',
                  ),
                ),
                TextField(
                  controller: commissionRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة (commissionRate)',
                    hintText: 'مثال: 0.2 (تعني 20%)',
                  ),
                ),
                TextField(
                  controller: duesLimitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'حد المستحقات الأقصى (duesLimit)',
                    hintText: 'الحد الأقصى للمستحقات قبل التنبيه، مثال: 500.0',
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setInnerState) {
                    return SwitchListTile(
                      title: const Text('متواجد أونلاين (isOnline)'),
                      value: isOnlineValue,
                      onChanged: (newValue) {
                        setInnerState(() {
                          isOnlineValue = newValue;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  double parsedTotalEarnings =
                      double.tryParse(totalEarningsCtrl.text.trim()) ?? 0.0;
                  double parsedCommissionRate =
                      double.tryParse(commissionRateCtrl.text.trim()) ?? 0.10;

                  // 🆕 حساب currentDues هنا
                  double calculatedCurrentDues =
                      parsedTotalEarnings * parsedCommissionRate;

                  await FirebaseFirestore.instance
                      .collection('agents')
                      .doc(agentIdCtrl.text.trim())
                      .set({
                        'agentName': agentNameCtrl.text.trim(),
                        'password': passwordCtrl.text.trim(),
                        'agentPhone': phoneCtrl.text.trim(),
                        // التأكد من تحويل رقم الهاتف إلى int إذا كان يجب تخزينه كرقم
                        'paymentPhoneNumber':
                            int.tryParse(paymentPhoneCtrl.text.trim()) ?? 0,
                        'manager_id': managerIdCtrl.text
                            .trim(), // 💡 تم التعديل هنا
                        'currentDues':
                            calculatedCurrentDues, // 🆕 حفظ القيمة المحسوبة
                        'commissionRate': parsedCommissionRate,
                        'duesLimit':
                            double.tryParse(duesLimitCtrl.text.trim()) ?? 500.0,
                        'isActive': true, // قيمة افتراضية
                        'isOnline':
                            isOnlineValue, // استخدام القيمة من الـ Switch
                        'totalEarnings':
                            parsedTotalEarnings, // 🆕 حفظ قيمة إجمالي الأرباح
                        'hasActiveOrder': false,
                        'completedOrdersCount': 0, // قيمة افتراضية
                        'active_orders_count': 0,
                      });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إضافة المندوب بنجاح.')),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطأ في الإضافة: $e')));
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  // 📍 تفعيل/إيقاف المندوب
  Future<void> _toggleAgentStatus(String agentId, bool currentStatus) async {
    try {
      // إذا كان المندوب سيتم إيقافه (currentStatus كان true وسيصبح false)
      // يجب أيضًا تعيين isOnline إلى false لضمان تسجيل الخروج
      Map<String, dynamic> updateData = {'isActive': !currentStatus};
      if (currentStatus == true) {
        updateData['isOnline'] = false; // إيقاف حالة الأونلاين عند الإيقاف
      }

      await FirebaseFirestore.instance
          .collection('agents')
          .doc(agentId)
          .update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ${currentStatus ? 'إيقاف' : 'تفعيل'} المندوب بنجاح.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تغيير حالة المندوب: $e')));
    }
  }

  // 📍 تعديل بيانات مندوب
  void _showEditAgentDialog(String agentId, Map<String, dynamic> agentData) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController agentNameCtrl = TextEditingController(
          text: agentData['agentName'],
        );
        final TextEditingController passwordCtrl = TextEditingController(
          text: agentData['password'],
        );
        final TextEditingController phoneCtrl = TextEditingController(
          text: agentData['agentPhone'],
        );
        final TextEditingController paymentPhoneCtrl = TextEditingController(
          text: (agentData['paymentPhoneNumber'] ?? 0).toString(),
        );
        final TextEditingController managerIdCtrl = TextEditingController(
          // متحكم لـ manager_id
          text: agentData['manager_id'] ?? '', // 💡 تم التعديل هنا
        );

        final TextEditingController commissionRateCtrl = TextEditingController(
          text: (agentData['commissionRate'] ?? 0.10).toString(),
        );
        final TextEditingController duesLimitCtrl = TextEditingController(
          text: (agentData['duesLimit'] ?? 500.0).toString(),
        );
        final TextEditingController totalEarningsCtrl = TextEditingController(
          text: (agentData['totalEarnings'] ?? 0.0)
              .toString(), // 🆕 جلب قيمة إجمالي الأرباح
        );

        bool isOnlineValue = agentData['isOnline'] ?? false;

        return AlertDialog(
          title: const Text('تعديل بيانات المندوب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: agentNameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المندوب'),
                ),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة السر'),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                ),
                TextField(
                  controller: paymentPhoneCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم هاتف الدفع (محفظة إلكترونية)',
                  ),
                ),
                TextField(
                  controller: managerIdCtrl, // حقل manager_id
                  decoration: const InputDecoration(
                    labelText: 'معرف المدير (manager_id)', // 💡 تم التعديل هنا
                  ),
                ),
                TextField(
                  controller: totalEarningsCtrl, // 🆕 حقل إجمالي الأرباح
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'إجمالي الأرباح (ج.م)',
                  ),
                ),
                TextField(
                  controller: commissionRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة (مثال: 0.10 لـ 10%)',
                  ),
                ),
                TextField(
                  controller: duesLimitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'حد المستحقات (ج.م)',
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setInnerState) {
                    return SwitchListTile(
                      title: const Text('متواجد أونلاين'),
                      value: isOnlineValue,
                      onChanged: (newValue) {
                        setInnerState(() {
                          isOnlineValue = newValue;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  double parsedTotalEarnings =
                      double.tryParse(totalEarningsCtrl.text.trim()) ?? 0.0;
                  double parsedCommissionRate =
                      double.tryParse(commissionRateCtrl.text.trim()) ?? 0.10;

                  // 🆕 حساب currentDues هنا
                  double calculatedCurrentDues =
                      parsedTotalEarnings * parsedCommissionRate;

                  await FirebaseFirestore.instance
                      .collection('agents')
                      .doc(agentId)
                      .update({
                        'agentName': agentNameCtrl.text.trim(),
                        'password': passwordCtrl.text.trim(),
                        'agentPhone': phoneCtrl.text.trim(),
                        'paymentPhoneNumber':
                            int.tryParse(paymentPhoneCtrl.text.trim()) ?? 0,
                        'manager_id': managerIdCtrl.text
                            .trim(), // 💡 تم التعديل هنا
                        'currentDues':
                            calculatedCurrentDues, // 🆕 حفظ القيمة المحسوبة
                        'commissionRate': parsedCommissionRate,
                        'duesLimit':
                            double.tryParse(duesLimitCtrl.text.trim()) ?? 500.0,
                        'isOnline':
                            isOnlineValue, // استخدام القيمة من الـ Switch
                        'totalEarnings':
                            parsedTotalEarnings, // 🆕 حفظ قيمة إجمالي الأرباح
                      });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تعديل المندوب بنجاح.')),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطأ في التعديل: $e')));
                }
              },
              child: const Text('تعديل'),
            ),
          ],
        );
      },
    );
  }

  // 📍 تأكيد حذف المندوب
  void _confirmDeleteAgent(String agentId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف المندوب ($agentId)؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteAgent(agentId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }

  // 📍 حذف المندوب
  Future<void> _deleteAgent(String agentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(agentId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المندوب بنجاح.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
    }
  }

  // 🆕 ديالوج لعرض كل تفاصيل المندوب
  void _showFullAgentDetailsDialog(Map<String, dynamic> agentData) {
    String agentId = agentData['agentId'] ?? 'N/A';
    String agentName = agentData['agentName'] ?? 'غير معروف';
    String agentPhone = agentData['agentPhone'] ?? 'غير معروف';
    String paymentPhoneNumber = (agentData['paymentPhoneNumber'] ?? 0)
        .toString();
    String managerId =
        agentData['manager_id'] ?? 'غير محدد'; // 💡 تم التعديل هنا
    double totalEarnings = (agentData['totalEarnings'] ?? 0.0).toDouble();
    double commissionRate = (agentData['commissionRate'] ?? 0.10).toDouble();
    double duesLimit = (agentData['duesLimit'] ?? 500.0).toDouble();
    bool isActive = agentData['isActive'] ?? true;
    bool isOnline = agentData['isOnline'] ?? false;

    // حساب currentDues مرة أخرى للتأكد من القيمة الأحدث
    double currentDues = totalEarnings * commissionRate;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'تفاصيل المندوب: $agentName',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('معرف المندوب (ID): $agentId'),
              Text('اسم المندوب: $agentName'),
              Row(
                children: [
                  Expanded(child: Text('رقم الهاتف: $agentPhone')),
                  if (agentPhone != 'غير معروف' && agentPhone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.blue),
                      onPressed: () => _launchPhone(agentPhone),
                    ),
                ],
              ),
              Text('رقم هاتف الدفع: $paymentPhoneNumber'),
              Text('معرف المدير (manager_id): $managerId'), // 💡 تم التعديل هنا
              const Divider(),
              Text(
                'إجمالي الأرباح: ${totalEarnings.toStringAsFixed(2)} جنيه',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'المستحقات على المندوب: ${currentDues.toStringAsFixed(2)} جنيه',
                style: TextStyle(
                  color: currentDues >= duesLimit ? Colors.red : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'نسبة العمولة: ${(commissionRate * 100).toStringAsFixed(0)}%',
              ),
              Text('حد المستحقات: ${duesLimit.toStringAsFixed(2)} جنيه'),
              const Divider(),
              Text(
                'حالة المندوب: ${isActive ? 'نشط' : 'غير نشط'}',
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'حالة التواجد: ${isOnline ? 'أونلاين' : 'أوفلاين'}',
                style: TextStyle(
                  color: isOnline ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المناديب',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey,
        actions: [
          Row(
            children: [
              const Text(
                'مستحقات عالية فقط',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Switch(
                value: _showHighDuesAgentsOnly,
                onChanged: (newValue) {
                  setState(() {
                    _showHighDuesAgentsOnly = newValue;
                  });
                },
                activeColor: Colors.red.shade300,
                inactiveThumbColor: Colors.grey.shade400,
              ),
            ],
          ),
          // 💡 إضافة زر تبديل جديد للمناديب المتواجدة أونلاين
          Row(
            children: [
              const Text(
                'متواجدون فقط',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Switch(
                value: _showOnlineAgentsOnly,
                onChanged: (newValue) {
                  setState(() {
                    _showOnlineAgentsOnly = newValue;
                  });
                },
                activeColor: Colors.green.shade300,
                inactiveThumbColor: Colors.grey.shade400,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () {
              _showAddAgentDialog();
            },
            tooltip: 'إضافة مندوب جديد',
          ),
        ],
        bottom: PreferredSize(
          // 💡 إضافة خانة البحث في الـ AppBar
          preferredSize: const Size.fromHeight(
            kToolbarHeight + 10,
          ), // ارتفاع مناسب لخانة البحث
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو المعرف...',
                hintStyle: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.blueGrey.shade700,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agents').snapshots(),
        builder: (context, agentsSnapshot) {
          if (agentsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (agentsSnapshot.hasError) {
            return Center(
              child: Text('خطأ في تحميل المناديب: ${agentsSnapshot.error}'),
            );
          }
          if (!agentsSnapshot.hasData || agentsSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد مناديب مسجلون.'));
          }

          List<QueryDocumentSnapshot> allAgentsDocs = agentsSnapshot.data!.docs;
          List<Map<String, dynamic>> filteredAgents = [];

          // 👈 تطبيق الفلترة والبحث
          for (var agentDoc in allAgentsDocs) {
            Map<String, dynamic> agentData =
                agentDoc.data() as Map<String, dynamic>;
            agentData['agentId'] = agentDoc.id; // أضف الـ ID للبيانات

            double totalEarnings = (agentData['totalEarnings'] ?? 0.0)
                .toDouble();
            double commissionRate = (agentData['commissionRate'] ?? 0.10)
                .toDouble();
            double currentDues = totalEarnings * commissionRate;
            agentData['currentDues'] =
                currentDues; // تحديث البيانات عشان الفلترة تستخدم القيمة المحسوبة

            double duesLimit = (agentData['duesLimit'] ?? 500.0)
                .toDouble(); // افتراضي 500

            bool matchesFilter = true;
            if (_showHighDuesAgentsOnly) {
              matchesFilter =
                  (duesLimit > 0 && currentDues >= (0.8 * duesLimit));
            }

            // 💡 تطبيق الفلتر الجديد للمناديب المتواجدة أونلاين
            if (_showOnlineAgentsOnly) {
              matchesFilter = matchesFilter && (agentData['isOnline'] ?? false);
            }

            // 🆕 تطبيق البحث
            bool matchesSearch = true;
            if (_searchQuery.isNotEmpty) {
              String agentNameLower = (agentData['agentName'] ?? '')
                  .toString()
                  .toLowerCase();
              String agentIdLower = (agentData['agentId'] ?? '')
                  .toString()
                  .toLowerCase();
              String agentPhoneLower = (agentData['agentPhone'] ?? '')
                  .toString()
                  .toLowerCase(); // البحث برقم الهاتف أيضًا
              String managerIdLower = (agentData['manager_id'] ?? '')
                  .toString()
                  .toLowerCase(); // 💡 تم التعديل هنا

              matchesSearch =
                  agentNameLower.contains(_searchQuery) ||
                  agentIdLower.contains(_searchQuery) ||
                  agentPhoneLower.contains(_searchQuery) ||
                  managerIdLower.contains(
                    _searchQuery,
                  ); // 💡 إضافة manager_id للبحث
            }

            if (matchesFilter && matchesSearch) {
              filteredAgents.add(agentData);
            }
          }

          // 🆕 فرز النتائج بحيث تكون الأقرب للبحث في البداية (بحث مرن/تقريبي)
          if (_searchQuery.isNotEmpty) {
            filteredAgents.sort((a, b) {
              String nameA = (a['agentName'] ?? '').toString().toLowerCase();
              String idA = (a['agentId'] ?? '').toString().toLowerCase();
              String phoneA = (a['agentPhone'] ?? '').toString().toLowerCase();
              String mgrIdA = (a['manager_id'] ?? '')
                  .toString()
                  .toLowerCase(); // 💡 تم التعديل هنا

              String nameB = (b['agentName'] ?? '').toString().toLowerCase();
              String idB = (b['agentId'] ?? '').toString().toLowerCase();
              String phoneB = (b['agentPhone'] ?? '').toString().toLowerCase();
              String mgrIdB = (b['manager_id'] ?? '')
                  .toString()
                  .toLowerCase(); // 💡 تم التعديل هنا

              // الأولوية للمطابقة التامة أو التي تبدأ بنفس الحروف
              bool aStarts =
                  nameA.startsWith(_searchQuery) ||
                  idA.startsWith(_searchQuery) ||
                  phoneA.startsWith(_searchQuery) ||
                  mgrIdA.startsWith(_searchQuery);
              bool bStarts =
                  nameB.startsWith(_searchQuery) ||
                  idB.startsWith(_searchQuery) ||
                  phoneB.startsWith(_searchQuery) ||
                  mgrIdB.startsWith(_searchQuery);

              if (aStarts && !bStarts) return -1;
              if (!aStarts && bStarts) return 1;

              // ثم الأولوية للمطابقة التي تحتوي على الكلمة
              bool aContains =
                  nameA.contains(_searchQuery) ||
                  idA.contains(_searchQuery) ||
                  phoneA.contains(_searchQuery) ||
                  mgrIdA.contains(_searchQuery);
              bool bContains =
                  nameB.contains(_searchQuery) ||
                  idB.contains(_searchQuery) ||
                  phoneB.contains(_searchQuery) ||
                  mgrIdB.contains(_searchQuery);

              if (aContains && !bContains) return -1;
              if (!aContains && bContains) return 1;

              // أخيرًا، الفرز الأبجدي إذا لم يكن هناك فرق في المطابقة
              return nameA.compareTo(nameB);
            });
          }

          if (filteredAgents.isEmpty) {
            return const Center(
              child: Text('لا يوجد مناديب مطابقون للفلترة أو البحث.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: filteredAgents.length,
            itemBuilder: (context, index) {
              var agent = filteredAgents[index];
              return _buildAgentCard(
                context,
                agent,
              ); // 💡 استدعاء الدالة الجديدة
            },
          );
        },
      ),
    );
  }

  // 🆕 دالة جديدة لبناء كارد المندوب
  Widget _buildAgentCard(BuildContext context, Map<String, dynamic> agent) {
    String agentId = agent['agentId'] ?? 'N/A';
    String agentName = agent['agentName'] ?? 'غير معروف';
    String agentPhone = agent['agentPhone'] ?? 'غير معروف';
    bool isActive = agent['isActive'] ?? true;
    bool isOnline = agent['isOnline'] ?? false; // 💡 جلب حالة التواجد
    String managerId = agent['manager_id'] ?? 'N/A'; // 💡 تم التعديل هنا

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        // 💡 لجعل الكارد قابل للضغط لعرض التفاصيل الكاملة
        onTap: () =>
            _showFullAgentDetailsDialog(agent), // نمرر الـ agent object بالكامل
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اسم المندوب: $agentName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  Text(
                    'المعرف: $agentId',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (agentPhone != 'غير معروف' && agentPhone.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.phone,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () => _launchPhone(agentPhone),
                      tooltip: 'الاتصال بالمندوب',
                    ),
                ],
              ),
              Text('معرف المدير: $managerId'), // 💡 تم التعديل هنا
              // 💡 عرض حالة التواجد وما إذا كان معه أوردر مقبول
              if (isOnline)
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('orders')
                      .where('agentId', isEqualTo: agentId)
                      .where('status', isEqualTo: 'accepted')
                      .limit(1) // نحتاج فقط لمعرفة ما إذا كان هناك أي طلب مقبول
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text(
                        'الحالة: أونلاين (جاري التحقق...)',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Text(
                        'الحالة: أونلاين (خطأ في التحقق)',
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      );
                    }
                    bool hasAcceptedOrder =
                        snapshot.data?.docs.isNotEmpty ?? false;
                    return Text(
                      'الحالة: أونلاين (${hasAcceptedOrder ? 'معاه أوردر مقبول' : 'فاضي'})',
                      style: TextStyle(
                        color: hasAcceptedOrder
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    );
                  },
                )
              else
                const Text(
                  'الحالة: أوفلاين',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 8), // مسافة بسيطة
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // زرار تفعيل/إيقاف المندوب
                  IconButton(
                    icon: Icon(
                      isActive ? Icons.toggle_on : Icons.toggle_off,
                      color: isActive ? Colors.green : Colors.grey,
                      size: 30,
                    ),
                    onPressed: () => _toggleAgentStatus(agentId, isActive),
                    tooltip: isActive ? 'إيقاف المندوب' : 'تفعيل المندوب',
                  ),
                  // زرار تعديل
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditAgentDialog(
                      agentId,
                      agent,
                    ), // نمرر الـ agent object بالكامل
                    tooltip: 'تعديل المندوب',
                  ),

                  // زرار حذف
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeleteAgent(agentId),
                    tooltip: 'حذف المندوب',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
