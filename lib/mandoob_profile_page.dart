// mandoob_profile_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MandoobProfilePage extends StatefulWidget {
  final String agentId; // هنا هيكون رقم هاتف المندوب اللي بنستخدمه كـ ID

  const MandoobProfilePage({super.key, required this.agentId});

  @override
  State<MandoobProfilePage> createState() => _MandoobProfilePageState();
}

class _MandoobProfilePageState extends State<MandoobProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController; // للتعامل مع كلمة المرور
  bool _isLoading = true;
  String? _initialPassword; // لتخزين كلمة المرور الأصلية ومقارنتها

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _loadAgentData(); // تحميل بيانات المندوب عند فتح الصفحة
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // دالة لتحميل بيانات المندوب من Firestore
  Future<void> _loadAgentData() async {
    try {
      DocumentSnapshot agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentId)
          .get();

      if (agentDoc.exists && agentDoc.data() != null) {
        Map<String, dynamic> data = agentDoc.data() as Map<String, dynamic>;
        _nameController.text = data['agentName'] ?? '';
        _phoneController.text = data['agentPhone'] ?? '';
        _initialPassword = data['password'] ?? ''; // تخزين كلمة المرور الأصلية
        _passwordController.text = _initialPassword!; // عرض كلمة المرور الحالية

        setState(() {
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بيانات المندوب غير موجودة.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading agent data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة لتحديث بيانات المندوب في Firestore
  Future<void> _updateAgentData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // التحقق من أن رقم الهاتف مصري وصحيح (11 رقم ويبدأ بـ 01)
      String newPhone = _phoneController.text.trim();
      if (newPhone.length != 11 || !newPhone.startsWith('01')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'الرجاء إدخال رقم هاتف مصري صحيح (11 رقم يبدأ بـ 01)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // إذا تم تغيير رقم الهاتف (الـ ID)، يجب التحقق مما إذا كان الـ ID الجديد موجودًا بالفعل
      if (newPhone != widget.agentId) {
        DocumentSnapshot existingAgentDoc = await FirebaseFirestore.instance
            .collection('agents')
            .doc(newPhone)
            .get();
        if (existingAgentDoc.exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الهاتف الجديد مسجل لمندوب آخر بالفعل.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن تغيير رقم الهاتف (معرف المندوب) من هذه الصفحة.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // تحديث البيانات
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentId)
          .update({
            'agentName': _nameController.text.trim(),
            'agentPhone': _phoneController.text.trim(), // هذا لن يتغير عملياً
            'password': _passwordController.text.trim(), // تحديث كلمة المرور
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم تحديث البيانات بنجاح!')),
      );
      Navigator.pop(context); // العودة للصفحة السابقة
    } catch (e) {
      debugPrint('Error updating agent data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ حدث خطأ أثناء التحديث: $e')));
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
          'تعديل بياناتي',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.indigoAccent,
                          child: Icon(
                            Icons.person_outline,
                            size: 70,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'اسم المندوب',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال اسم المندوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _phoneController,
                        readOnly:
                            true, // رقم الهاتف (الـ ID) لا يمكن تعديله من هنا
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف (لا يمكن تعديله)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'كلمة السر',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordController.text.isEmpty
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              // هنا ممكن نضيف وظيفة إظهار/إخفاء كلمة المرور
                              // حالياً، الأيقونة بس بتوضح الحالة
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال كلمة السر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateAgentData,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isLoading ? 'جاري الحفظ...' : 'حفظ التغييرات',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 15),
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
            ),
    );
  }
}
