// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // For making phone calls

class ManagerAgentsPage extends StatefulWidget {
  final String managerId;

  const ManagerAgentsPage({super.key, required this.managerId});

  @override
  State<ManagerAgentsPage> createState() => _ManagerAgentsPageState();
}

class _ManagerAgentsPageState extends State<ManagerAgentsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _showDuesOver80Percent = false;
  bool _showOnlineWithOrder = false;
  bool _showOnlineNoOrder = false;
  bool _showAllAgents = true; // Default to showing all agents

  final TextEditingController _newAgentNameController = TextEditingController();
  final TextEditingController _newAgentPhoneController =
      TextEditingController();
  final TextEditingController _newAgentDuesLimitController =
      TextEditingController();
  final TextEditingController _newAgentCommissionRateController =
      TextEditingController();
  final TextEditingController _newAgentPaymentPhoneController =
      TextEditingController();
  final TextEditingController _newAgentPasswordController =
      TextEditingController();
  final TextEditingController _newAgentIdController =
      TextEditingController(); // 💡 حقل جديد للـ Agent ID

  // 💡 إضافة متغير لتخزين نص البحث عشان نقدر نستخدمه في الـ StreamBuilder
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    // 💡 تحديث _currentSearchQuery عند تغيير نص البحث
    // وهذا سيؤدي إلى إعادة بناء الـ StreamBuilder تلقائياً بناءً على الـ setState في هذا الـ listener.
    _searchController.addListener(() {
      setState(() {
        _currentSearchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newAgentNameController.dispose();
    _newAgentPhoneController.dispose();
    _newAgentDuesLimitController.dispose();
    _newAgentCommissionRateController.dispose();
    _newAgentPaymentPhoneController.dispose();
    _newAgentPasswordController.dispose();
    _newAgentIdController.dispose(); // 💡 التخلص من المتحكم الجديد
    super.dispose();
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

  // Function to reset agent's account and transfer dues to manager
  Future<void> _resetAgentAccount(
    String agentId,
    double agentCurrentDues,
  ) async {
    if (!mounted) return;
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تأكيد تصفير الحساب', textAlign: TextAlign.right),
          content: Text(
            'هل أنت متأكد من تصفير حساب المندوب وتحويل مبلغ ${agentCurrentDues.toStringAsFixed(2)} جنيه إلى أرباحك؟',
            textAlign: TextAlign.right,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'تأكيد',
                style: TextStyle(color: Color(0xFFB39DDB)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference agentRef = FirebaseFirestore.instance
            .collection('agents')
            .doc(agentId);
        DocumentSnapshot agentSnapshot = await transaction.get(agentRef);

        DocumentReference managerRef = FirebaseFirestore.instance
            .collection('managers')
            .doc(widget.managerId);
        DocumentSnapshot managerSnapshot = await transaction.get(managerRef);

        if (!agentSnapshot.exists || !managerSnapshot.exists) {
          throw Exception("المندوب أو المدير غير موجود.");
        }

        Map<String, dynamic> agentData =
            agentSnapshot.data() as Map<String, dynamic>;
        // 💡 مرونة في قراءة currentDues للمندوب
        double currentAgentDues = (agentData['currentDues'] is num)
            ? agentData['currentDues'].toDouble()
            : 0.0;

        Map<String, dynamic> managerData =
            managerSnapshot.data() as Map<String, dynamic>;
        // 💡 مرونة في قراءة totalEarnings و currentDues للمدير
        double currentManagerTotalEarnings =
            (managerData['totalEarnings'] is num)
            ? managerData['totalEarnings'].toDouble()
            : 0.0;
        double currentManagerCurrentDues = (managerData['currentDues'] is num)
            ? managerData['currentDues'].toDouble()
            : 0.0;

        // Reset agent's account
        transaction.update(agentRef, {
          'currentDues': 0.0,
          'totalEarnings': 0.0,
          'completedOrdersCount': 0,
        });

        // Transfer amount to manager's total earnings and update manager's current dues
        transaction.update(managerRef, {
          'totalEarnings': currentManagerTotalEarnings + currentAgentDues,
          'currentDues':
              currentManagerCurrentDues +
              currentAgentDues, // 💡 إضافة المبلغ للمستحق على المدير
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تصفير حساب المندوب بنجاح وتحويل المبلغ!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء تصفير الحساب: $e')),
      );
      debugPrint('Reset agent account error: $e');
    }
  }

  // Function to show the Add Agent dialog
  Future<void> _showAddAgentDialog() async {
    _newAgentNameController.clear();
    _newAgentPhoneController.clear();
    _newAgentDuesLimitController.clear();
    _newAgentCommissionRateController.clear();
    _newAgentPaymentPhoneController.clear();
    _newAgentPasswordController.clear();
    _newAgentIdController.clear(); // 💡 مسح حقل الـ ID الجديد

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إضافة مندوب جديد', textAlign: TextAlign.right),
          content: SingleChildScrollView(
            // مرونة في السحب داخل الديالوج
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller:
                        _newAgentIdController, // 💡 حقل إدخال الـ ID الجديد
                    decoration: const InputDecoration(
                      labelText: 'معرف المندوب (ID)',
                      hintText: 'سيستخدم لتسجيل الدخول',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newAgentNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المندوب',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newAgentPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType
                        .number, // Changed to number for consistency
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newAgentDuesLimitController,
                    decoration: const InputDecoration(
                      labelText: 'الحد الأقصى للمبلغ المستحق (جنيه)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newAgentCommissionRateController,
                    decoration: const InputDecoration(
                      labelText: 'نسبة العمولة (مثال: 0.10 لـ 10%)',
                      hintText: 'أدخل ككسر عشري (مثال: 0.10)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newAgentPaymentPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف الدفع للمندوب',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newAgentPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'كلمة السر للمندوب',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(text: widget.managerId),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'معرف المدير (Manager ID)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إغلاق', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'حفظ',
                style: TextStyle(color: Color(0xFFB39DDB)),
              ),
              onPressed: () {
                _addAgentToFirestore();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to add new agent data to Firestore
  Future<void> _addAgentToFirestore() async {
    final String agentId = _newAgentIdController.text
        .trim(); // 💡 جلب الـ ID الجديد
    final String agentName = _newAgentNameController.text.trim();
    final String agentPhone = _newAgentPhoneController.text.trim();
    final String duesLimitText = _newAgentDuesLimitController.text.trim();
    final String commissionRateText = _newAgentCommissionRateController.text
        .trim();
    final String paymentPhoneNumber = _newAgentPaymentPhoneController.text
        .trim();
    final String password = _newAgentPasswordController.text.trim();

    if (agentId.isEmpty || // 💡 التحقق من أن الـ ID ليس فارغاً
        agentName.isEmpty ||
        agentPhone.isEmpty ||
        duesLimitText.isEmpty ||
        commissionRateText.isEmpty ||
        paymentPhoneNumber.isEmpty ||
        password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    // 💡 مرونة في تحويل النصوص المدخلة لأرقام
    double? duesLimit = double.tryParse(duesLimitText);
    double? commissionRate = double.tryParse(commissionRateText);

    if (duesLimit == null || commissionRate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال أرقام صحيحة للحد الأقصى ونسبة العمولة'),
        ),
      );
      return;
    }

    try {
      // 💡 التحقق مما إذا كان الـ ID موجوداً بالفعل
      DocumentSnapshot agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(agentId)
          .get();

      if (agentDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'معرف المندوب (ID) هذا موجود بالفعل! الرجاء اختيار معرف آخر.',
            ),
          ),
        );
        return;
      }

      // 💡 استخدام الـ ID المدخل كـ Document ID
      await FirebaseFirestore.instance.collection('agents').doc(agentId).set({
        'agentName': agentName,
        'agentPhone': agentPhone,
        'commissionRate': commissionRate,
        'completedOrdersCount': 0,
        'currentDues': 0.0,
        'duesLimit': duesLimit,
        'isActive': true,
        'isOnline': false,
        'hasActiveOrder': false,
        'manager_id': widget.managerId,
        'password': password,
        'paymentPhoneNumber': paymentPhoneNumber,
        'totalEarnings': 0.0,
        'status': 'idle', // Default to no active order
        'active_orders_count': 0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إضافة المندوب بنجاح!')),
      );
      Navigator.of(context).pop(); // إغلاق مربع الحوار بعد الإضافة
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إضافة المندوب: $e')),
      );
      debugPrint('Add agent error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المناديب',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFB39DDB),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              _showAddAgentDialog(); // Show add agent dialog from this page
            },
            tooltip: 'إضافة مندوب جديد',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, // Right-to-left for Arabic
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'ابحث عن مندوب بالاسم أو رقم الهاتف',
                  hintText: 'اكتب اسم أو رقم المندوب',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 16.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Filter Chips
              SingleChildScrollView(
                // 💡 مرونة في السحب الأفقي للفلاتر
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('كل المناديب'),
                      selected: _showAllAgents,
                      onSelected: (bool selected) {
                        setState(() {
                          _showAllAgents = selected;
                          if (selected) {
                            _showDuesOver80Percent = false;
                            _showOnlineWithOrder = false;
                            _showOnlineNoOrder = false;
                          }
                          // 💡 لا نحتاج لاستدعاء _onSearchChanged هنا
                          // لأن تغيير الـ bool variables سيؤدي إلى إعادة بناء الـ StreamBuilder
                        });
                      },
                      selectedColor: const Color(0xFF673AB7),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _showAllAgents ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('مستحقات > 80%'),
                      selected: _showDuesOver80Percent,
                      onSelected: (bool selected) {
                        setState(() {
                          _showDuesOver80Percent = selected;
                          if (selected) {
                            _showAllAgents = false;
                            _showOnlineWithOrder = false;
                            _showOnlineNoOrder = false;
                          }
                        });
                      },
                      selectedColor: const Color(0xFF673AB7),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _showDuesOver80Percent
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),

                    FilterChip(
                      label: const Text('متصل فقط  '),
                      selected: _showOnlineNoOrder,
                      onSelected: (bool selected) {
                        setState(() {
                          _showOnlineNoOrder = selected;
                          if (selected) {
                            _showAllAgents = false;
                            _showDuesOver80Percent = false;
                            _showOnlineWithOrder = false;
                          }
                        });
                      },
                      selectedColor: const Color(0xFF673AB7),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _showOnlineNoOrder
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'المناديب التابعون لك:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF673AB7),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                // 💡 مرونة في السحب الرأسي لقائمة المناديب
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('agents')
                      .where('manager_id', isEqualTo: widget.managerId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('خطأ في تحميل المناديب: ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'لا يوجد مناديب تابعون لهذا المدير حاليًا.',
                        ),
                      );
                    }

                    // 💡 هنا يتم تطبيق الفلترة والبحث بمرونة
                    List<DocumentSnapshot> allAgentsDocs = snapshot.data!.docs;
                    List<DocumentSnapshot> displayAgents = [];

                    // 1. تطبيق فلتر البحث النصي
                    if (_currentSearchQuery.isNotEmpty) {
                      displayAgents = allAgentsDocs.where((agent) {
                        final agentData = agent.data() as Map<String, dynamic>;
                        final agentName = (agentData['agentName'] ?? '')
                            .toLowerCase();
                        final agentPhone = (agentData['agentPhone'] ?? '')
                            .toLowerCase();
                        final agentId = agent.id
                            .toLowerCase(); // 💡 تم تصحيح هذا السطر
                        return agentName.contains(_currentSearchQuery) ||
                            agentPhone.contains(_currentSearchQuery) ||
                            agentId.contains(_currentSearchQuery);
                      }).toList();
                    } else {
                      displayAgents = List.from(
                        allAgentsDocs,
                      ); // لو مفيش بحث، اعرض كل المناديب
                    }

                    // 2. تطبيق فلاتر الـ FilterChip
                    if (_showDuesOver80Percent) {
                      displayAgents = displayAgents.where((agent) {
                        final agentData = agent.data() as Map<String, dynamic>;
                        // 💡 مرونة في قراءة الأرقام من Firestore
                        double totalEarnings =
                            (agentData['totalEarnings'] is num)
                            ? agentData['totalEarnings'].toDouble()
                            : 0.0;
                        double commissionRate =
                            (agentData['commissionRate'] is num)
                            ? agentData['commissionRate'].toDouble()
                            : 0.0;
                        double duesLimit = (agentData['duesLimit'] is num)
                            ? agentData['duesLimit'].toDouble()
                            : 0.0;

                        if (duesLimit <= 0) return false;
                        double currentDuesToPay =
                            totalEarnings * commissionRate;
                        return (currentDuesToPay / duesLimit) * 100 >= 80;
                      }).toList();
                    } else if (_showOnlineWithOrder) {
                      displayAgents = displayAgents.where((agent) {
                        final agentData = agent.data() as Map<String, dynamic>;
                        // 💡 مرونة في قراءة القيم المنطقية
                        return (agentData['isOnline'] ?? false) &&
                            (agentData['status'] == 'accepted');
                      }).toList();
                    } else if (_showOnlineNoOrder) {
                      displayAgents = displayAgents.where((agent) {
                        final agentData = agent.data() as Map<String, dynamic>;
                        // 💡 مرونة في قراءة القيم المنطقية
                        return (agentData['isOnline'] ?? false) &&
                            !(agentData['status'] == 'accepted');
                      }).toList();
                    }
                    // لو _showAllAgents True، مش هنعمل فلترة إضافية لأن displayAgents هتكون already كل المناديب (أو اللي مطابقين للبحث النصي)

                    if (displayAgents.isEmpty) {
                      return const Center(
                        child: Text(
                          'لا يوجد مناديب مطابقون للفلترة الحالية.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: displayAgents.length,
                      itemBuilder: (context, index) {
                        var agent = displayAgents[index];
                        var agentData = agent.data() as Map<String, dynamic>;
                        String agentName =
                            agentData['agentName'] ??
                            'غير معروف'; // 💡 مرونة في النص
                        String agentPhone =
                            agentData['agentPhone'] ??
                            'غير متاح'; // 💡 مرونة في النص
                        bool isActive =
                            agentData['isActive'] ??
                            false; // 💡 مرونة في القيمة المنطقية
                        // 💡 مرونة في قراءة الأرقام
                        double totalEarnings =
                            (agentData['totalEarnings'] is num)
                            ? agentData['totalEarnings'].toDouble()
                            : 0.0;
                        double commissionRate =
                            (agentData['commissionRate'] is num)
                            ? agentData['commissionRate'].toDouble()
                            : 0.0;
                        double duesLimit =
                            (agentData['duesLimit'] is num) // 💡 جلب duesLimit
                            ? agentData['duesLimit'].toDouble()
                            : 0.0;

                        double currentDuesToPay =
                            totalEarnings * commissionRate;

                        // 💡 تحديد ما إذا كانت المستحقات أعلى من 80%
                        bool isHighDues =
                            (duesLimit > 0 &&
                            currentDuesToPay >= (0.8 * duesLimit));

                        return GestureDetector(
                          // 💡 هنا الـ GestureDetector الجديد
                          // 💡 لو المندوب "متصل ومعاه أوردر"، هنستدعي دالة عرض الأوردرات
                          // 💡 غير كده، هنرجع الدالة القديمة لعرض بيانات المندوب
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'اسم المندوب: $agentName',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'معرف المندوب (ID): ${agent.id}', // 💡 عرض الـ ID
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'رقم الهاتف: $agentPhone',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.call,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () =>
                                            _launchCaller(agentPhone),
                                        tooltip: 'اتصال بالمندوب',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'الحالة: ${isActive ? 'نشط' : 'غير نشط'}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isActive
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    // 💡 إضافة Row لعرض المبلغ والتحذير
                                    children: [
                                      Text(
                                        'المبلغ الجاري المستحق دفعه: ${currentDuesToPay.toStringAsFixed(2)} جنيه',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isHighDues) // 💡 عرض أيقونة التحذير بشكل شرطي
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Icon(
                                            Icons.warning,
                                            color: Colors.amber.shade800,
                                            size: 24,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () => _resetAgentAccount(
                                        agent.id,
                                        currentDuesToPay,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.deepPurple.shade400,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('تصفير حساب المندوب'),
                                    ),
                                  ),
                                ],
                              ),
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
      ),
      // 💡 هنا تم إضافة الـ BannerAdWidget في الـ bottomNavigationBar
    );
  }
}
