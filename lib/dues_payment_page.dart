// dues_payment_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
// ignore_for_file: use_build_context_synchronously

class DuesPaymentPage extends StatefulWidget {
  final String agentPhone; // معرف المندوب (رقم هاتفه)
  final double currentDues; // المستحقات الحالية (قادمة من الصفحة السابقة)
  final String agentName; // اسم المندوب

  const DuesPaymentPage({
    super.key,
    required this.agentPhone,
    required this.currentDues,
    required this.agentName,
  });

  @override
  State<DuesPaymentPage> createState() => _DuesPaymentPageState();
}

class _DuesPaymentPageState extends State<DuesPaymentPage> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingAgentData = true; // حالة تحميل بيانات المندوب
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // بيانات المندوب التي سيتم جلبها من Firestore
  Map<String, dynamic>? _agentData;
  String? _agentPaymentPhoneNumber; // رقم هاتف السداد الخاص بالمسؤول العام
  int _completedOrdersCount = 0; // عدد الطلبات المكتملة للفترة المحددة

  // متغيرات لتحديد فترة عرض الطلبات المكتملة
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAgentDashboardData(); // تحميل جميع بيانات لوحة تحكم المندوب
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // 📍 دالة لجلب بيانات المندوب ورقم هاتف السداد وتحديث حالة الحساب
  Future<void> _loadAgentDashboardData() async {
    setState(() {
      _isLoadingAgentData = true;
    });
    try {
      DocumentSnapshot agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentPhone)
          .get();

      if (agentDoc.exists && agentDoc.data() != null) {
        _agentData = agentDoc.data() as Map<String, dynamic>;
        _agentPaymentPhoneNumber = _agentData!['paymentPhoneNumber'];

        // تحديث حالة isActive إذا تجاوزت المستحقات الحد الأقصى
        double currentDues = (_agentData!['currentDues'] ?? 0.0).toDouble();
        double duesLimit = (_agentData!['duesLimit'] ?? 500.0).toDouble();

        if (currentDues >= duesLimit && (_agentData!['isActive'] ?? true)) {
          await FirebaseFirestore.instance
              .collection('agents')
              .doc(widget.agentPhone)
              .update({'isActive': false});
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لقد وصلت للحد الأقصى للمستحقات. تم إيقاف حسابك مؤقتاً.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          // إعادة تحميل البيانات بعد التحديث لتعكس التغيير في isActive
          agentDoc = await FirebaseFirestore.instance
              .collection('agents')
              .doc(widget.agentPhone)
              .get();
          _agentData = agentDoc.data() as Map<String, dynamic>;
        }

        // جلب عدد الطلبات المكتملة للفترة المحددة
        await _fetchCompletedOrdersCount(_startDate, _endDate);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بيانات المندوب غير موجودة.')),
        );
      }
    } catch (e) {
      debugPrint("Error loading agent dashboard data: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر جلب بيانات المندوب: $e')));
    } finally {
      setState(() {
        _isLoadingAgentData = false;
      });
    }
  }

  // 📍 دالة لجلب عدد الطلبات المكتملة للمندوب في فترة محددة
  Future<void> _fetchCompletedOrdersCount(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders') // افترض أن لديك كوليكشن 'orders'
          .where('agentId', isEqualTo: widget.agentPhone)
          .where('status', isEqualTo: 'completed')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where(
            'timestamp',
            isLessThanOrEqualTo: endDate.add(const Duration(days: 1)),
          )
          .get();

      setState(() {
        _completedOrdersCount = ordersSnapshot.docs.length;
      });
    } catch (e) {
      debugPrint("Error fetching completed orders count: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب عدد الطلبات المكتملة: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    setState(() {
      _isLoading = true;
    });

    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child('agent_payments')
          .child(widget.agentPhone)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(_selectedImage!);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء رفع صورة الإيصال: $e')),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitPaymentReceipt() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_agentData == null || !(_agentData!['isActive'] ?? false)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('حسابك غير نشط. لا يمكنك إرسال إيصالات دفع حالياً.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_amountController.text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال المبلغ المراد سداده')),
      );
      return;
    }

    if (_selectedImage == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء إرفاق صورة الإيصال.')),
      );
      return;
    }

    double paymentAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (paymentAmount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من صفر')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = await _uploadImage();
      if (imageUrl == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('payment_receipts').add({
        'agentPhone': widget.agentPhone,
        'agentName': widget.agentName,
        'amount': paymentAmount,
        'receiptImageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // حالة الإيصال في انتظار المراجعة
      });

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال الإيصال بنجاح. سيتم مراجعته قريباً.'),
        ),
      );
      _amountController.clear();
      setState(() {
        _selectedImage = null;
      });
    } catch (e) {
      debugPrint('Error submitting payment receipt: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إرسال الإيصال: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم المستحقات',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: _isLoadingAgentData
          ? const Center(child: CircularProgressIndicator())
          : _agentData == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'تعذر تحميل بيانات المندوب.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.red),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'يرجى التأكد من اتصال الإنترنت أو التواصل مع الإدارة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text(
                        'العودة',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 📍 معلومات المندوب الأساسية
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً، ${widget.agentName}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const Divider(),
                          _buildInfoRow(
                            'رقم الهاتف:',
                            widget.agentPhone,
                            Icons.phone,
                          ),
                          _buildInfoRow(
                            'إجمالي الأرباح:',
                            '${(_agentData!['totalEarnings'] ?? 0.0).toStringAsFixed(2)} جنيه',
                            Icons.attach_money,
                          ),
                          _buildInfoRow(
                            'نسبة العمولة:',
                            '${((_agentData!['commissionRate'] ?? 0.10) * 100).toStringAsFixed(0)}%',
                            Icons.percent,
                          ),
                          _buildInfoRow(
                            'حد المستحقات:',
                            '${(_agentData!['duesLimit'] ?? 500.0).toStringAsFixed(2)} جنيه',
                            Icons.money_off,
                          ),
                          _buildInfoRow(
                            'المستحقات الحالية:',
                            '${(_agentData!['currentDues'] ?? 0.0).toStringAsFixed(2)} جنيه',
                            Icons.account_balance_wallet,
                            color:
                                (_agentData!['currentDues'] ?? 0.0) >=
                                    ((_agentData!['duesLimit'] ?? 500.0) * 0.8)
                                ? Colors.red
                                : Colors.black,
                          ),
                          if (!(_agentData!['isActive'] ?? true))
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                '⚠️ حسابك متوقف بسبب تجاوز حد المستحقات. يرجى السداد للتفعيل.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if ((_agentData!['currentDues'] ?? 0.0) >=
                                  ((_agentData!['duesLimit'] ?? 500.0) * 0.8) &&
                              (_agentData!['currentDues'] ?? 0.0) <
                                  (_agentData!['duesLimit'] ?? 500.0) &&
                              (_agentData!['isActive'] ?? true))
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                '⚠️ لقد تجاوزت 80% من حد المستحقات. يرجى السداد لتجنب إيقاف الحساب!',
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

                  // 📍 قسم الطلبات المكتملة
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'عدد الطلبات المكتملة:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null &&
                                        picked != _startDate) {
                                      setState(() {
                                        _startDate = picked;
                                      });
                                      _fetchCompletedOrdersCount(
                                        _startDate,
                                        _endDate,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'من: ${_startDate.toLocal().toString().split(' ')[0]}',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null && picked != _endDate) {
                                      setState(() {
                                        _endDate = picked;
                                      });
                                      _fetchCompletedOrdersCount(
                                        _startDate,
                                        _endDate,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'إلى: ${_endDate.toLocal().toString().split(' ')[0]}',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              '$_completedOrdersCount طلب',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 📍 قسم السداد
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إرسال إيصال سداد المستحقات:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (_agentPaymentPhoneNumber != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الرجاء السداد على الرقم التالي:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _agentPaymentPhoneNumber!,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 15),
                              ],
                            )
                          else
                            const Text(
                              'لا يوجد رقم سداد متاح حالياً. يرجى التواصل مع الإدارة.',
                              style: TextStyle(color: Colors.red),
                            ),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'المبلغ المراد سداده',
                              hintText: 'أدخل المبلغ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.money),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image, color: Colors.white),
                            label: Text(
                              _selectedImage == null
                                  ? 'اختيار صورة الإيصال'
                                  : 'تم اختيار صورة (تغيير)',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (_selectedImage != null) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: Image.file(
                                _selectedImage!,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: (_agentData!['isActive'] ?? true)
                                      ? _submitPaymentReceipt
                                      : null, // 👈 تعطيل الزر إذا كان الحساب غير نشط
                                  icon: const Icon(Icons.send, size: 28),
                                  label: const Text(
                                    'إرسال إيصال السداد',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 5,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      // 💡 هنا تم إضافة الـ BannerAdWidget في الـ bottomNavigationBar
    );
  }

  // 📍 دالة مساعدة لعرض صفوف المعلومات
  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
