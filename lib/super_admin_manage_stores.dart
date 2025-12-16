// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // لإجراء المكالمات
import 'add_store_page.dart';

class SuperAdminManageStoresPage extends StatefulWidget {
  const SuperAdminManageStoresPage({super.key});

  @override
  State<SuperAdminManageStoresPage> createState() =>
      _SuperAdminManageStoresPageState();
}

class _SuperAdminManageStoresPageState
    extends State<SuperAdminManageStoresPage> {
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

  // 📍 تعديل بيانات محل
  void _showEditStoreDialog(DocumentSnapshot storeDoc) {
    String storeId = storeDoc.id;
    Map<String, dynamic> storeData = storeDoc.data() as Map<String, dynamic>;

    final TextEditingController storeNameCtrl = TextEditingController(
      text: storeData['storeName'],
    );
    final TextEditingController addressCtrl = TextEditingController(
      text: storeData['address'],
    );
    final TextEditingController phoneCtrl = TextEditingController(
      text: storeData['phone'],
    );
    final TextEditingController passwordCtrl = TextEditingController(text: '');
    final TextEditingController storeRegionCtrl = TextEditingController(
      text: storeData['storeRegion'] ?? '',
    );

    // 💡 متغير حالة فتح/إغلاق المحل (القيمة الأولية)
    bool isStoreOpen = storeData['isOpen'] ?? true;

    // 💡 متحكم لنسبة الربح (افتراضياً 0.0 لو مش موجودة)
    final TextEditingController profitPercentageCtrl = TextEditingController(
      text: (storeData['profitPercentage'] ?? 1.0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        // 💡 متغير حالة السويتش عشان نقدر نغيره داخل الـ Builder
        bool currentIsOpen = isStoreOpen;

        return StatefulBuilder(
          // استخدام StatefulBuilder لتحديث الـ Switch
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تعديل بيانات المحل'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store ID: $storeId',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: storeNameCtrl,
                      decoration: const InputDecoration(labelText: 'اسم المحل'),
                    ),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان المحل',
                      ),
                    ),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم التليفون',
                      ),
                    ),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور (اتركها فارغة لعدم التغيير)',
                      ),
                    ),
                    TextField(
                      controller: storeRegionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'المنطقة (Store Region)',
                      ),
                    ),

                    // 🆕 حقل نسبة الربح
                    TextField(
                      controller: profitPercentageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'نسبة ربح التطبيق (%)',
                        suffixText: '%',
                      ),
                    ),

                    const SizedBox(height: 15),

                    // 🆕 حقل حالة فتح/إغلاق المحل (Switch)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'حالة المحل (مفتوح/مغلق):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: currentIsOpen,
                          onChanged: (newValue) {
                            setState(() {
                              // تحديث حالة السويتش
                              currentIsOpen = newValue;
                            });
                          },
                          activeColor: Colors.green,
                          inactiveTrackColor: Colors.red.shade200,
                        ),
                      ],
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
                      // 💡 التحقق من صحة إدخال نسبة الربح
                      double? profit = double.tryParse(
                        profitPercentageCtrl.text.trim(),
                      );

                      if (profit == null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('الرجاء إدخال نسبة ربح صحيحة'),
                          ),
                        );
                        return;
                      }

                      Map<String, dynamic> updates = {
                        'storeName': storeNameCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'storeRegion': storeRegionCtrl.text.trim(),
                        'isOpen': currentIsOpen,
                        'profitPercentage':
                            profit, // ✅ هيسجل القيمة المدخلة كما هي (مثلاً 0.1)
                      };

                      if (passwordCtrl.text.trim().isNotEmpty) {
                        updates['password'] = passwordCtrl.text.trim();
                      }

                      await FirebaseFirestore.instance
                          .collection('stores')
                          .doc(storeId)
                          .update(updates);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تعديل المحل بنجاح.')),
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ في التعديل: $e')),
                      );
                    }
                  },
                  child: const Text('تعديل'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 📍 تأكيد حذف المحل
  void _confirmDeleteStore(String storeId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف المحل ($storeId)؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteStore(storeId);
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

  // 📍 حذف المحل
  Future<void> _deleteStore(String storeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المحل بنجاح.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
    }
  }

  // 🆕 ديالوج لعرض كل تفاصيل المحل
  void _showFullStoreDetailsDialog(DocumentSnapshot storeDoc) {
    String storeId = storeDoc.id;
    Map<String, dynamic> storeData = storeDoc.data() as Map<String, dynamic>;

    String storeName = storeData['storeName'] ?? 'غير معروف';
    String storeAddress = storeData['address'] ?? 'غير محدد';
    String storePhone = storeData['phone'] ?? 'غير محدد';
    String password =
        storeData['password'] ?? 'غير متوفر'; // لعرض كلمة المرور (للمسؤول فقط)
    String storeRegion =
        storeData['storeRegion'] ?? 'غير محددة'; // 💡 جلب المنطقة

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'تفاصيل المحل: $storeName',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('معرف المحل (ID): $storeId'),
              Text('اسم المحل: $storeName'),
              Text('عنوان المحل: $storeAddress'),
              Row(
                children: [
                  Expanded(child: Text('رقم الهاتف: $storePhone')),
                  if (storePhone != 'غير محدد' && storePhone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.blue),
                      onPressed: () => _launchPhone(storePhone),
                      tooltip: 'الاتصال بالمحل',
                    ),
                ],
              ),
              Text('كلمة المرور: $password'), // عرض كلمة المرور هنا
              Text('المنطقة (Store Region): $storeRegion'), // 💡 عرض المنطقة
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
          'إدارة المحلات',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_location_alt_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              // ✅ الكود الجديد: هيفتح صفحة إضافة المحل كاملة
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AddStorePage(), // افتراضاً إنها في نفس الملف
                ),
              );
            },
            tooltip: 'إضافة محل جديد',
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
                hintText: 'ابحث باسم المحل...',
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
                fillColor: Colors.purple.shade700, // لون يتناسب مع الـ AppBar
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
        stream: FirebaseFirestore.instance
            .collection('stores')
            .snapshots(), // كوليكشن المحلات
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد محلات مسجلة.'));
          }

          List<QueryDocumentSnapshot> allStoresDocs = snapshot.data!.docs;
          List<QueryDocumentSnapshot> filteredStores = [];

          // 🆕 تطبيق البحث
          for (var storeDoc in allStoresDocs) {
            Map<String, dynamic> storeData =
                storeDoc.data() as Map<String, dynamic>;
            String storeNameLower = (storeData['storeName'] ?? '')
                .toString()
                .toLowerCase();
            String storeIdLower = storeDoc.id
                .toLowerCase(); // يمكن البحث بالـ ID أيضاً

            bool matchesSearch = true;
            if (_searchQuery.isNotEmpty) {
              matchesSearch =
                  storeNameLower.contains(_searchQuery) ||
                  storeIdLower.contains(_searchQuery); // البحث بالاسم أو الـ ID
            }

            if (matchesSearch) {
              filteredStores.add(storeDoc);
            }
          }

          // 🆕 فرز النتائج بحيث تكون الأقرب للبحث في البداية (بحث مرن/تقريبي)
          if (_searchQuery.isNotEmpty) {
            filteredStores.sort((a, b) {
              String nameA = (a['storeName'] ?? '').toString().toLowerCase();
              String idA = a.id.toLowerCase();

              String nameB = (b['storeName'] ?? '').toString().toLowerCase();
              String idB = b.id.toLowerCase();

              // الأولوية للمطابقة التامة أو التي تبدأ بنفس الحروف (للاسم أو الـ ID)
              bool aStarts =
                  nameA.startsWith(_searchQuery) ||
                  idA.startsWith(_searchQuery);
              bool bStarts =
                  nameB.startsWith(_searchQuery) ||
                  idB.startsWith(_searchQuery);

              if (aStarts && !bStarts) return -1;
              if (!aStarts && bStarts) return 1;

              // ثم الأولوية للمطابقة التي تحتوي على الكلمة (للاسم أو الـ ID)
              bool aContains =
                  nameA.contains(_searchQuery) || idA.contains(_searchQuery);
              bool bContains =
                  nameB.contains(_searchQuery) || idB.contains(_searchQuery);

              if (aContains && !bContains) return -1;
              if (!aContains && bContains) return 1;

              // أخيرًا، الفرز الأبجدي إذا لم يكن هناك فرق في المطابقة
              return nameA.compareTo(nameB);
            });
          }

          if (filteredStores.isEmpty) {
            return const Center(child: Text('لا توجد محلات مطابقة للبحث.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: filteredStores.length,
            itemBuilder: (context, index) {
              var storeDoc = filteredStores[index];
              String storeId = storeDoc.id;
              String storeName = storeDoc['storeName'] ?? 'غير معروف';
              String storeAddress = storeDoc['address'] ?? 'غير محدد';
              String storePhone = storeDoc['phone'] ?? 'غير محدد';
              String storeRegion =
                  storeDoc['storeRegion'] ??
                  'غير محددة'; // 💡 جلب المنطقة للعرض

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  // 💡 لجعل الكارد قابل للضغط لعرض التفاصيل الكاملة
                  onTap: () => _showFullStoreDetailsDialog(
                    storeDoc,
                  ), // نمرر الـ DocumentSnapshot
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اسم المحل: $storeName ($storeId)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text('العنوان: $storeAddress'),
                        Text(
                          'المنطقة: $storeRegion',
                        ), // 💡 عرض المنطقة في الكارد
                        Row(
                          // 💡 إضافة زر الاتصال بجانب رقم الهاتف
                          children: [
                            Expanded(child: Text('رقم الهاتف: $storePhone')),
                            if (storePhone != 'غير محدد' &&
                                storePhone.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.phone,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _launchPhone(storePhone),
                                tooltip: 'الاتصال بالمحل',
                              ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // زرار تعديل
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditStoreDialog(storeDoc),
                              tooltip: 'تعديل المحل',
                            ),
                            // زرار حذف
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteStore(storeId),
                              tooltip: 'حذف المحل',
                            ),
                          ],
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
      // 💡 هنا تم إضافة الـ BannerAdWidget في الـ bottomNavigationBar
    );
  }
}
