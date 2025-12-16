// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // لإجراء تنسيق التاريخ
import 'package:url_launcher/url_launcher.dart'; // لإجراء المكالمات

class SuperAdminEarningsDuesPage extends StatefulWidget {
  const SuperAdminEarningsDuesPage({super.key});

  @override
  State<SuperAdminEarningsDuesPage> createState() =>
      _SuperAdminEarningsDuesPageState();
}

class _SuperAdminEarningsDuesPageState extends State<SuperAdminEarningsDuesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  double _superAdminEarnings = 0.0;
  List<Map<String, dynamic>> _agentsWithHighDues = [];
  List<Map<String, dynamic>> _filteredAgents = [];

  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _filteredManagers = [];
  bool _showHighDuesManagersOnly = false;
  final TextEditingController _managerSearchController =
      TextEditingController();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  final TextEditingController _agentSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSuperAdminEarnings(_startDate, _endDate);
    _loadAgentsWithHighDues();
    _loadManagers();

    _agentSearchController.addListener(_filterAgents);
    _managerSearchController.addListener(_filterManagers);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _agentSearchController.removeListener(_filterAgents);
    _agentSearchController.dispose();
    _managerSearchController.removeListener(_filterManagers);
    _managerSearchController.dispose();
    super.dispose();
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

  Future<void> _loadSuperAdminEarnings(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      DocumentSnapshot superAdminEarningsDoc = await FirebaseFirestore.instance
          .collection('super_admins')
          .doc('admin_earnings')
          .get();

      if (!superAdminEarningsDoc.exists) {
        await FirebaseFirestore.instance
            .collection('super_admins')
            .doc('admin_earnings')
            .set({'totalEarnings': 0.0}, SetOptions(merge: true));
      }

      QuerySnapshot transactionsSnapshot = await FirebaseFirestore.instance
          .collection('super_admins')
          .doc('admin_earnings')
          .collection('clearedDuesTransactions')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where(
            'timestamp',
            isLessThanOrEqualTo: endDate.add(const Duration(days: 1)),
          )
          .get();

      double totalEarningsForPeriod = 0.0;
      for (var doc in transactionsSnapshot.docs) {
        totalEarningsForPeriod += (doc['amount'] ?? 0.0).toDouble();
      }

      setState(() {
        _superAdminEarnings = totalEarningsForPeriod;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل أرباح السوبر أدمن: $e')),
        );
      }
      setState(() {
        _superAdminEarnings = 0.0;
      });
    }
  }

  Future<void> _loadAgentsWithHighDues() async {
    List<Map<String, dynamic>> agents = [];
    try {
      QuerySnapshot agentsSnapshot = await FirebaseFirestore.instance
          .collection('agents')
          .where('currentDues', isGreaterThan: 0)
          .get();

      for (var agentDoc in agentsSnapshot.docs) {
        Map<String, dynamic> agentData =
            agentDoc.data() as Map<String, dynamic>;
        double currentDues = (agentData['currentDues'] ?? 0.0).toDouble();

        agents.add({
          'agentId': agentDoc.id,
          'agentName': agentData['agentName'] ?? 'غير معروف',
          'currentDues': currentDues,
          'isActive': agentData['isActive'] ?? true,
          'managerId': agentData['managerId'] ?? 'N/A',
        });
      }
      agents.sort((a, b) => b['currentDues'].compareTo(a['currentDues']));

      setState(() {
        _agentsWithHighDues = agents;
        _filterAgents();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المناديب ذوي المستحقات العالية: $e'),
          ),
        );
      }
      setState(() {
        _agentsWithHighDues = [];
        _filteredAgents = [];
      });
    }
  }

  void _filterAgents() {
    String query = _agentSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredAgents = List.from(_agentsWithHighDues);
      } else {
        _filteredAgents = _agentsWithHighDues
            .where(
              (agent) =>
                  (agent['agentName'] as String).toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _loadManagers() async {
    List<Map<String, dynamic>> managers = [];
    try {
      QuerySnapshot managersSnapshot = await FirebaseFirestore.instance
          .collection('managers')
          .get();

      for (var managerDoc in managersSnapshot.docs) {
        Map<String, dynamic> managerData =
            managerDoc.data() as Map<String, dynamic>;
        double totalEarnings = _parseToDouble(managerData['totalEarnings']);
        double commissionRate = _parseToDouble(managerData['commissionRate']);
        double duesLimit = _parseToDouble(managerData['duesLimit']);

        double currentDues = totalEarnings * commissionRate;

        managers.add({
          'managerId': managerDoc.id,
          'managerName': managerData['managerName'] ?? 'غير معروف',
          'phone': managerData['phone'] ?? 'غير محدد',
          'password': managerData['password'] ?? '',
          'paymentPhoneNumber': managerData['paymentPhoneNumber'] ?? 'غير محدد',
          'commissionRate': commissionRate,
          'duesLimit': duesLimit,
          'currentDues': currentDues,
          'totalEarnings': totalEarnings,
          'isActive': managerData['isActive'] ?? true,
        });
      }
      managers.sort((a, b) => b['currentDues'].compareTo(a['currentDues']));

      setState(() {
        _managers = managers;
        _filterManagers();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل المديرين: $e')));
      }
      setState(() {
        _managers = [];
        _filteredManagers = [];
      });
    }
  }

  void _filterManagers() {
    String query = _managerSearchController.text.toLowerCase();
    setState(() {
      _filteredManagers = _managers.where((manager) {
        bool matchesSearch = true;
        if (query.isNotEmpty) {
          String managerNameLower = (manager['managerName'] ?? '')
              .toString()
              .toLowerCase();
          String managerIdLower = (manager['managerId'] ?? '')
              .toString()
              .toLowerCase();
          String managerPhoneLower = (manager['phone'] ?? '')
              .toString()
              .toLowerCase();

          matchesSearch =
              managerNameLower.contains(query) ||
              managerIdLower.contains(query) ||
              managerPhoneLower.contains(query);
        }

        bool matchesHighDuesFilter = true;
        if (_showHighDuesManagersOnly) {
          double duesLimit = _parseToDouble(manager['duesLimit']);
          double currentDues = _parseToDouble(manager['currentDues']);
          matchesHighDuesFilter =
              (duesLimit > 0 && currentDues >= (0.8 * duesLimit));
        }

        return matchesSearch && matchesHighDuesFilter;
      }).toList();

      if (query.isNotEmpty) {
        _filteredManagers.sort((a, b) {
          String nameA = (a['managerName'] ?? '').toString().toLowerCase();
          String idA = (a['managerId'] ?? '').toString().toLowerCase();
          String phoneA = (a['phone'] ?? '').toString().toLowerCase();

          String nameB = (b['managerName'] ?? '').toString().toLowerCase();
          String idB = (b['managerId'] ?? '').toString().toLowerCase();
          String phoneB = (b['phone'] ?? '').toString().toLowerCase();

          bool aStarts =
              nameA.startsWith(query) ||
              idA.startsWith(query) ||
              phoneA.startsWith(query);
          bool bStarts =
              nameB.startsWith(query) ||
              idB.startsWith(query) ||
              phoneB.startsWith(query);

          if (aStarts && !bStarts) return -1;
          if (!aStarts && bStarts) return 1;

          bool aContains =
              nameA.contains(query) ||
              idA.contains(query) ||
              phoneA.contains(query);
          bool bContains =
              nameB.contains(query) ||
              idB.contains(query) ||
              phoneB.contains(query);

          if (aContains && !bContains) return -1;
          if (!aContains && bContains) return 1;

          return nameA.compareTo(nameB);
        });
      }
    });
  }

  double _parseToDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // 📍 دالة لتصفير مستحقات المندوب وتفعيل حسابه (تم التأكد من مكانها)
  Future<void> _clearAgentDuesAndActivate(
    String agentId,
    double currentDues,
  ) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد تصفير المستحقات'),
          content: Text(
            'هل أنت متأكد من تصفير المستحقات على هذا المندوب (${currentDues.toStringAsFixed(2)} جنيه)؟ سيتم تفعيل حسابه ومسح إجمالي أرباحه وعدد طلباته المكتملة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // قفل الـ dialog

                try {
                  // 1. تصفير المستحقات وإجمالي الأرباح وعدد الطلبات المكتملة وتفعيل حساب المندوب
                  await FirebaseFirestore.instance
                      .collection('agents')
                      .doc(agentId)
                      .update({
                        'currentDues': 0.0,
                        'totalEarnings': 0.0, // مسح إجمالي الأرباح
                        'completedOrdersCount': 0, // مسح عدد الطلبات المكتملة
                        'isActive': true, // تفعيل حساب المندوب
                      });

                  // 2. تحديث أرباح السوبر أدمن بإضافة المبلغ المُحصل
                  DocumentReference superAdminEarningsRef = FirebaseFirestore
                      .instance
                      .collection('super_admins')
                      .doc('admin_earnings');

                  await FirebaseFirestore.instance.runTransaction((
                    transaction,
                  ) async {
                    DocumentSnapshot snapshot = await transaction.get(
                      superAdminEarningsRef,
                    );

                    double currentSuperAdminTotalEarnings = 0.0;
                    if (snapshot.exists &&
                        snapshot.data() is Map<String, dynamic> &&
                        snapshot['totalEarnings'] != null) {
                      if (snapshot['totalEarnings'] is num) {
                        currentSuperAdminTotalEarnings =
                            snapshot['totalEarnings'].toDouble();
                      } else if (snapshot['totalEarnings'] is String) {
                        currentSuperAdminTotalEarnings =
                            double.tryParse(snapshot['totalEarnings']) ?? 0.0;
                      }
                    }

                    double newSuperAdminTotalEarnings =
                        currentSuperAdminTotalEarnings + currentDues;
                    transaction.set(superAdminEarningsRef, {
                      'totalEarnings': newSuperAdminTotalEarnings,
                    }, SetOptions(merge: true));

                    // إضافة سجل للمعاملة في subcollection
                    transaction.set(
                      superAdminEarningsRef
                          .collection('clearedDuesTransactions')
                          .doc(),
                      {
                        'amount': currentDues,
                        'timestamp': FieldValue.serverTimestamp(),
                        'agentId': agentId,
                      },
                    );
                  });

                  // 3. إعادة تحميل البيانات في الصفحة
                  await _loadSuperAdminEarnings(_startDate, _endDate);
                  await _loadAgentsWithHighDues();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '✅ تم تصفير المستحقات وتفعيل حساب المندوب بنجاح!',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ حدث خطأ أثناء تصفير المستحقات: $e'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }

  void _showAddManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController managerIdCtrl = TextEditingController();
        final TextEditingController managerNameCtrl = TextEditingController();
        final TextEditingController passwordCtrl = TextEditingController();
        final TextEditingController phoneCtrl = TextEditingController();
        final TextEditingController paymentPhoneCtrl = TextEditingController();
        final TextEditingController commissionRateCtrl = TextEditingController(
          text: '0.05',
        );
        final TextEditingController duesLimitCtrl = TextEditingController(
          text: '1000.0',
        );

        return AlertDialog(
          title: const Text('إضافة مدير جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: managerIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'معرف المدير (ID)',
                  ),
                ),
                TextField(
                  controller: managerNameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المدير'),
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
                    labelText: 'رقم هاتف الدفع',
                  ),
                ),
                TextField(
                  controller: commissionRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة (مثال: 0.05 لـ 5%)',
                  ),
                ),
                TextField(
                  controller: duesLimitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'حد المستحقات الأقصى',
                  ),
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
                  double parsedCommissionRate = _parseToDouble(
                    commissionRateCtrl.text.trim(),
                  );
                  double parsedDuesLimit = _parseToDouble(
                    duesLimitCtrl.text.trim(),
                  );

                  await FirebaseFirestore.instance
                      .collection('managers')
                      .doc(managerIdCtrl.text.trim())
                      .set({
                        'managerName': managerNameCtrl.text.trim(),
                        'password': passwordCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'paymentPhoneNumber': paymentPhoneCtrl.text.trim(),
                        'commissionRate': parsedCommissionRate,
                        'duesLimit': parsedDuesLimit,
                        'currentDues': 0.0,
                        'totalEarnings': 0.0,
                        'isActive': true,
                      });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إضافة المدير بنجاح.')),
                  );
                  Navigator.pop(context);
                  _loadManagers();
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

  void _showEditManagerDialog(Map<String, dynamic> managerData) {
    String managerId = managerData['managerId'];
    final TextEditingController managerNameCtrl = TextEditingController(
      text: managerData['managerName'],
    );
    final TextEditingController passwordCtrl = TextEditingController(
      text: managerData['password'],
    );
    final TextEditingController phoneCtrl = TextEditingController(
      text: managerData['phone'],
    );
    final TextEditingController paymentPhoneCtrl = TextEditingController(
      text: managerData['paymentPhoneNumber'],
    );
    final TextEditingController commissionRateCtrl = TextEditingController(
      text: managerData['commissionRate'].toString(),
    );
    final TextEditingController duesLimitCtrl = TextEditingController(
      text: managerData['duesLimit'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل بيانات المدير'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'معرف المدير (ID): $managerId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: managerNameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المدير'),
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
                    labelText: 'رقم هاتف الدفع',
                  ),
                ),
                TextField(
                  controller: commissionRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة (مثال: 0.05 لـ 5%)',
                  ),
                ),
                TextField(
                  controller: duesLimitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'حد المستحقات الأقصى',
                  ),
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
                  double parsedCommissionRate = _parseToDouble(
                    commissionRateCtrl.text.trim(),
                  );
                  double parsedDuesLimit = _parseToDouble(
                    duesLimitCtrl.text.trim(),
                  );

                  await FirebaseFirestore.instance
                      .collection('managers')
                      .doc(managerId)
                      .update({
                        'managerName': managerNameCtrl.text.trim(),
                        'password': passwordCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'paymentPhoneNumber': paymentPhoneCtrl.text.trim(),
                        'commissionRate': parsedCommissionRate,
                        'duesLimit': parsedDuesLimit,
                      });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تعديل المدير بنجاح.')),
                  );
                  Navigator.pop(context);
                  _loadManagers();
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

  Future<void> _toggleManagerStatus(
    String managerId,
    bool currentStatus,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('managers')
          .doc(managerId)
          .update({'isActive': !currentStatus});

      QuerySnapshot agentsSnapshot = await FirebaseFirestore.instance
          .collection('agents')
          .where('managerId', isEqualTo: managerId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in agentsSnapshot.docs) {
        batch.update(doc.reference, {'isActive': !currentStatus});
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ${currentStatus ? 'إيقاف' : 'تفعيل'} المدير والمناديب التابعين بنجاح.',
          ),
        ),
      );
      _loadManagers();
      _loadAgentsWithHighDues();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تغيير حالة المدير: $e')));
    }
  }

  Future<void> _clearManagerDues(String managerId, double currentDues) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد تصفير المستحقات'),
          content: Text(
            'هل أنت متأكد من تصفير المستحقات على هذا المدير (${currentDues.toStringAsFixed(2)} جنيه)؟ سيتم إضافة المبلغ لأرباح السوبر أدمن.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('managers')
                      .doc(managerId)
                      .update({'currentDues': 0.0, 'totalEarnings': 0.0});

                  DocumentReference superAdminEarningsRef = FirebaseFirestore
                      .instance
                      .collection('super_admins')
                      .doc('admin_earnings');
                  await FirebaseFirestore.instance.runTransaction((
                    transaction,
                  ) async {
                    DocumentSnapshot snapshot = await transaction.get(
                      superAdminEarningsRef,
                    );
                    double currentSuperAdminTotalEarnings = _parseToDouble(
                      (snapshot.data()
                          as Map<String, dynamic>?)?['totalEarnings'],
                    );
                    double newSuperAdminTotalEarnings =
                        currentSuperAdminTotalEarnings + currentDues;
                    transaction.set(superAdminEarningsRef, {
                      'totalEarnings': newSuperAdminTotalEarnings,
                    }, SetOptions(merge: true));

                    transaction.set(
                      superAdminEarningsRef
                          .collection('clearedDuesTransactions')
                          .doc(),
                      {
                        'amount': currentDues,
                        'timestamp': FieldValue.serverTimestamp(),
                        'managerId': managerId,
                      },
                    );
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم تصفير مستحقات المدير وإضافتها لأرباحك بنجاح.',
                      ),
                    ),
                  );
                  _loadManagers();
                  _loadSuperAdminEarnings(_startDate, _endDate);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في تصفير مستحقات المدير: $e')),
                  );
                }
              },
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteManager(String managerId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل أنت متأكد من حذف المدير ($managerId)؟ سيتم حذف جميع بياناته.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('managers')
                      .doc(managerId)
                      .delete();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف المدير بنجاح.')),
                  );
                  _loadManagers();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }

  void _showFullManagerDetailsDialog(Map<String, dynamic> managerData) {
    String managerId = managerData['managerId'] ?? 'N/A';
    String managerName = managerData['managerName'] ?? 'غير معروف';
    String phone = managerData['phone'] ?? 'غير محدد';
    String password = managerData['password'] ?? 'غير متوفر';
    String paymentPhoneNumber = managerData['paymentPhoneNumber'] ?? 'غير محدد';
    double commissionRate = _parseToDouble(managerData['commissionRate']);
    double duesLimit = _parseToDouble(managerData['duesLimit']);
    double currentDues = _parseToDouble(managerData['currentDues']);
    double totalEarnings = _parseToDouble(managerData['totalEarnings']);
    bool isActive = managerData['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'تفاصيل المدير: $managerName',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('معرف المدير (ID): $managerId'),
              Text('اسم المدير: $managerName'),
              Text('رقم الهاتف: $phone'),
              Text('كلمة المرور: $password'),
              Text('رقم هاتف الدفع: $paymentPhoneNumber'),
              const Divider(),
              Text(
                'إجمالي الأرباح: ${totalEarnings.toStringAsFixed(2)} جنيه',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'المستحقات على المدير: ${currentDues.toStringAsFixed(2)} جنيه',
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
                'الحالة: ${isActive ? 'نشط' : 'غير نشط'}',
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.red,
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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSuperAdminEarnings(_startDate, _endDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة الأرباح والمستحقات',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'المناديب'),
            Tab(text: 'المديرين'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAgentsTab(), _buildManagersTab()],
      ),
    );
  }

  Widget _buildAgentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'أرباح السوبر أدمن:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_superAdminEarnings.toStringAsFixed(2)} جنيه',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _agentSearchController,
            decoration: InputDecoration(
              labelText: 'البحث باسم المندوب',
              hintText: 'اكتب اسم المندوب للبحث',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _agentSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _agentSearchController.clear();
                        _filterAgents();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 15),

          const Text(
            'مناديب عليهم مستحقات (أكثر من صفر):',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const Divider(),
          const SizedBox(height: 10),

          if (_filteredAgents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'لا يوجد مناديب مطابقون للبحث أو لا توجد مستحقات حاليًا.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredAgents.length,
              itemBuilder: (context, index) {
                var agent = _filteredAgents[index];
                double dues = agent['currentDues'];
                bool isActive = agent['isActive'];
                String managerId = agent['managerId'] ?? 'N/A';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المندوب: ${agent['agentName']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text('ID المندوب: ${agent['agentId']}'),
                        Text('معرف المدير: $managerId'),
                        Text(
                          'المستحقات: ${dues.toStringAsFixed(2)} جنيه',
                          style: TextStyle(
                            color: dues >= 500
                                ? Colors.red.shade700
                                : (dues > 0
                                      ? Colors.orange.shade700
                                      : Colors.green),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'الحالة: ${isActive ? 'نشط' : 'غير نشط (متوقف)'}',
                          style: TextStyle(
                            color: isActive ? Colors.green : Colors.red,
                          ),
                        ),
                        if (dues > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: () => _clearAgentDuesAndActivate(
                                agent['agentId'],
                                dues,
                              ),
                              icon: const Icon(Icons.payment, size: 20),
                              label: const Text('تصفير وتفعيل الحساب'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // 💡 بناء تاب المديرين (تم تعديله)
  Widget _buildManagersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إدارة المديرين',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.indigo,
                ),
                onPressed: _showAddManagerDialog,
                tooltip: 'إضافة مدير جديد',
              ),
            ],
          ),
          const Divider(thickness: 2),
          const SizedBox(height: 15),

          // فلتر المديرين ذوي المستحقات العالية
          Row(
            children: [
              const Text(
                'مديرين عليهم مستحقات عالية فقط',
                style: TextStyle(fontSize: 14),
              ),
              Switch(
                value: _showHighDuesManagersOnly,
                onChanged: (newValue) {
                  setState(() {
                    _showHighDuesManagersOnly = newValue;
                    _filterManagers();
                  });
                },
                activeColor: Colors.red.shade300,
                inactiveThumbColor: Colors.grey.shade400,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // حقل البحث للمديرين (في أعلى التاب)
          TextField(
            controller: _managerSearchController,
            decoration: InputDecoration(
              labelText:
                  'البحث باسم المدير، المعرف أو رقم الهاتف', // 💡 نص توضيحي للبحث
              hintText: 'اكتب للبحث عن مدير...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _managerSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _managerSearchController.clear();
                        _filterManagers(); // إعادة فلترة لعرض الكل
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 15),

          const Text(
            'قائمة المديرين:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const Divider(),
          const SizedBox(height: 10),

          if (_filteredManagers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'لا يوجد مديرون مطابقون للبحث أو الفلترة.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredManagers.length,
              itemBuilder: (context, index) {
                var manager = _filteredManagers[index];
                String managerId = manager['managerId'] ?? 'N/A';
                String managerName = manager['managerName'] ?? 'غير معروف';
                String managerPhone = manager['phone'] ?? 'غير محدد';
                double dues = _parseToDouble(manager['currentDues']);
                double duesLimit = _parseToDouble(manager['duesLimit']);
                bool isActive = manager['isActive'] ?? true;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: () => _showFullManagerDetailsDialog(manager),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المدير: $managerName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text('ID المدير: $managerId'),
                          Row(
                            // 💡 عرض رقم الهاتف مع زر الاتصال
                            children: [
                              Expanded(
                                child: Text('رقم الهاتف: $managerPhone'),
                              ),
                              if (managerPhone != 'غير محدد' &&
                                  managerPhone.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.phone,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  onPressed: () => _launchPhone(managerPhone),
                                  tooltip: 'الاتصال بالمدير',
                                ),
                            ],
                          ),
                          Text(
                            'المستحقات: ${dues.toStringAsFixed(2)} جنيه',
                            style: TextStyle(
                              color: dues >= duesLimit * 0.8
                                  ? Colors.red.shade700
                                  : (dues > 0
                                        ? Colors.orange.shade700
                                        : Colors.green),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'الحالة: ${isActive ? 'نشط' : 'غير نشط (متوقف)'}',
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.red,
                            ),
                          ),
                          // رسالة التحذير للمدير
                          if (isActive &&
                              duesLimit > 0 &&
                              dues >= duesLimit * 0.8 &&
                              dues < duesLimit)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '⚠️ تحذير: المستحقات تقترب من الحد الأقصى (${(duesLimit * 0.8).toStringAsFixed(2)} جنيه)!',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // زرار تفعيل/إيقاف المدير
                              IconButton(
                                icon: Icon(
                                  isActive ? Icons.toggle_on : Icons.toggle_off,
                                  color: isActive ? Colors.green : Colors.grey,
                                  size: 30,
                                ),
                                onPressed: () => _toggleManagerStatus(
                                  manager['managerId'],
                                  isActive,
                                ),
                                tooltip: isActive
                                    ? 'إيقاف المدير'
                                    : 'تفعيل المدير',
                              ),
                              // زرار تعديل
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () =>
                                    _showEditManagerDialog(manager),
                                tooltip: 'تعديل المدير',
                              ),
                              // زرار تصفير المستحقات
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.orange,
                                ),
                                onPressed: () => _clearManagerDues(
                                  manager['managerId'],
                                  dues,
                                ),
                                tooltip: 'تصفير مستحقات المدير',
                              ),
                              // زرار حذف
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _confirmDeleteManager(manager['managerId']),
                                tooltip: 'حذف المدير',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
