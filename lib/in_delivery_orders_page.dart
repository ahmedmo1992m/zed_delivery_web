// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InDeliveryOrdersPage extends StatefulWidget {
  final String agentPhone;

  const InDeliveryOrdersPage({super.key, required this.agentPhone});

  @override
  State<InDeliveryOrdersPage> createState() => _InDeliveryOrdersPageState();
}

class _InDeliveryOrdersPageState extends State<InDeliveryOrdersPage> {
  final Logger _logger = Logger();
  int _activeOrdersCount = 0;
  // 💡 الدالة الجديدة لتحديث العدد في Firebase (هتُنادى من الـ StreamBuilder)
  Future<void> _updateAgentActiveOrders(int count) async {
    if (count == _activeOrdersCount) return; // لو مفيش تغيير، منعملش تحديث

    _logger.i('Updating agent active orders count to: $count');
    try {
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentPhone)
          .update({
            'active_orders_count':
                count, // 👈🏼 الحقل الجديد اللي المدير هيشوفه
            'hasActiveOrder':
                count > 0, // تحديث الحالة برضه عشان تستخدمها في الـ Logout
          });
      // تحديث المتغير المحلي بعد نجاح التحديث في Firebase
      setState(() {
        _activeOrdersCount = count;
      });
    } catch (e) {
      _logger.e('Error updating active orders count for agent: $e');
    }
  }

  String? _extractPhoneNumber(String? text) {
    if (text == null || text.isEmpty) return null;
    final RegExp phoneRegex = RegExp(
      r'(\+?20|0)?1[0125]\d{8}|\d{7,}',
      multiLine: true,
    );

    final match = phoneRegex.firstMatch(text);
    if (match != null) {
      String number = match.group(0)!;
      // تنظيف الرقم من أي رموز غير ضرورية
      number = number.replaceAll(RegExp(r'[^\d]+'), '');
      // تنسيق الرقم المصري ليبدأ بـ +20
      if (number.length >= 10 && !number.startsWith('+')) {
        if (number.startsWith('0020')) {
          return '+20${number.substring(4)}';
        } else if (number.startsWith('01')) {
          return '+20${number.substring(1)}';
        }
      }
      return number;
    }
    return null;
  }

  // دالة لفتح الخرائط بالإحداثيات (تم تعديل الرابط ليتناسب مع الإحداثيات)
  Future<void> _launchMaps(double latitude, double longitude) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final Uri url = Uri.parse(googleMapsUrl);

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback: opening maps in browser.
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      _logger.e('Error launching Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء فتح الخريطة: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // دالة مساعدة لدمج عرض الوصف والـ Divider بناءً على وجود رقم هاتف
  List<Widget> _buildDescriptionWidgets(
    String orderDescription,
    String? storePhone,
    String? customerPhone,
  ) {
    final String? phoneFromDescription = _extractPhoneNumber(orderDescription);

    // لو لقينا رقم تليفون جديد ومختلف عن رقم المحل أو العميل
    if (phoneFromDescription != null &&
        phoneFromDescription != storePhone &&
        phoneFromDescription != customerPhone) {
      return [
        _buildPhoneLink(
          phoneFromDescription,
          Icons.call_split, // أيقونة مختلفة لتمييزه عن الرقم الأصلي
        ),
        const Divider(),
        // عرض الوصف كنص عادي أسفل زر الاتصال
        _buildSummaryRow('التفاصيل (نص):', orderDescription, Icons.description),
      ];
    } else {
      // لو مفيش رقم أو الرقم متكرر، نعرض الوصف كـ SummaryRow عادي
      return [
        _buildSummaryRow('التفاصيل:', orderDescription, Icons.description),
      ];
    }
  }

  // دالة لإجراء مكالمة هاتفية
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _logger.e('Could not launch phone call for: $phoneNumber');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن إجراء مكالمة هاتفية.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error making phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إجراء المكالمة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // دالة تسليم الأوردر
  Future<void> _completeOrder({
    required String orderId,
    required String collectionName,
    required BuildContext context,
    required double deliveryPrice,
    double grandTotal = 0.0,
    double totalStorePayout = 0.0,
  }) async {
    final bool confirmComplete =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد تسليم الأوردر'),
            content: const Text('هل أنت متأكد أنك قمت بتسليم هذا الأوردر؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                ),
                child: const Text(
                  'تم التسليم',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmComplete) return;

    try {
      // 1. تحديث حالة الأوردر في الكوليكشن الأصلي
      DocumentReference orderRef = FirebaseFirestore.instance
          .collection(collectionName)
          .doc(orderId);

      await orderRef.update({
        'status': 'completed',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // 2. تحديث الأوردر في كوليكشن المحل
      // جلب store_id من كوليكشن 'orders' الرئيسي
      DocumentSnapshot mainOrderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (mainOrderSnapshot.exists) {
        Map<String, dynamic> orderData =
            mainOrderSnapshot.data() as Map<String, dynamic>;

        // 💡 مهم: استخدم 'store_id' بالأندرسكور زي ما هو في الفايربيس عندك
        String? storeId = orderData['store_id'];

        if (storeId != null && storeId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .collection('orders')
              .doc(orderId)
              .update({
                'status': 'completed',
                'deliveredAt': FieldValue.serverTimestamp(),
              });
        } else {
          _logger.w('Order $orderId found, but is missing store_id field.');
        }
      } else {
        _logger.w(
          'Order $orderId not found in main "orders" collection to get store_id. Skipping store update.',
        );
      }

      // 3. تحديث بيانات المندوب
      DocumentSnapshot agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentPhone)
          .get();

      if (agentDoc.exists) {
        Map<String, dynamic> agentData =
            agentDoc.data() as Map<String, dynamic>;

        double commissionRate = (agentData['commissionRate'] is num)
            ? agentData['commissionRate'].toDouble()
            : 0.0;
        double currentDues = (agentData['currentDues'] is num)
            ? agentData['currentDues'].toDouble()
            : 0.0;
        double totalEarnings = (agentData['totalEarnings'] is num)
            ? agentData['totalEarnings'].toDouble()
            : 0.0;
        int completedOrdersCount = (agentData['completedOrdersCount'] is int)
            ? agentData['completedOrdersCount']
            : 0;

        double dueAmount = 0.0;
        double netAgentProfit = 0.0;

        if (collectionName == 'orders') {
          netAgentProfit = grandTotal - totalStorePayout;
          dueAmount = netAgentProfit * commissionRate;
        } else {
          netAgentProfit = deliveryPrice;
          dueAmount = deliveryPrice * commissionRate;
        }

        await FirebaseFirestore.instance
            .collection('agents')
            .doc(widget.agentPhone)
            .update({
              'currentDues': currentDues + dueAmount,
              'totalEarnings': totalEarnings + netAgentProfit,
              'completedOrdersCount': completedOrdersCount + 1,
            });

        _logger.i(
          'Agent ${widget.agentPhone} completed order $orderId. Earnings: $netAgentProfit, Dues added: $dueAmount',
        );
      } else {
        _logger.w('Agent document not found for phone: ${widget.agentPhone}');
      }
      // ⭐️ الخطوة الجديدة: فحص ما إذا كان المندوب لا يملك أوردرات نشطة
      // ----------------------------------------------------------------------

      // هنفحص الأول في كوليكشن 'orders'
      final QuerySnapshot storeOrdersCheck = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'accepted')
          .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
          .limit(1)
          .get();

      // وهنفحص كمان في كوليكشن 'client_orders'
      final QuerySnapshot clientOrdersCheck = await FirebaseFirestore.instance
          .collection('client_orders')
          .where('status', isEqualTo: 'accepted')
          .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
          .limit(1)
          .get();

      // لو مفيش أي أوردرات في الكوليكشنين (طول الليست 0) يبقى المندوب خلص
      final bool noRemainingOrders =
          storeOrdersCheck.docs.isEmpty && clientOrdersCheck.docs.isEmpty;

      if (noRemainingOrders) {
        await FirebaseFirestore.instance
            .collection('agents')
            .doc(widget.agentPhone)
            .update({
              'hasActiveOrder': false, // 💡 تغيير حالة النشاط
              'isAvailable':
                  true, // ممكن تغير الحالة لـ "متاح" بس معندوش أوردر، أو تسيبها زي ما كانت
            });
        _logger.i(
          'Agent ${widget.agentPhone} status set to hasActiveOrder: false.',
        );
      }

      // ----------------------------------------------------------------------
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تسجيل الأوردر كمكتمل بنجاح! تم تحديث بياناتك.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e(
        'Error completing order $orderId from $collectionName and updating agent data: $e',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تسجيل الأوردر كمكتمل أو تحديث بيانات المندوب: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 💡 ويدجت لعرض نص قابل للاتصال (PhoneLink)
  Widget _buildPhoneLink(String? value, IconData icon) {
    // محاولة استخراج الرقم من القيمة اللي جاية (سواء كانت رقم أساساً أو وصف)
    final String? phoneNumber = _extractPhoneNumber(value);
    // لو الرقم موجود وأكبر من 7 حروف، نخليه قابل للاتصال
    final bool isDialable = phoneNumber != null && phoneNumber.length >= 7;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: isDialable ? () => _makePhoneCall(phoneNumber) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: isDialable ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'رقم الاتصال:', // نص ثابت عشان يبان إن دي خانة اتصال
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value ?? 'غير متاح',
                style: TextStyle(
                  fontSize: 15,
                  color: isDialable ? Colors.blue : Colors.black87,
                  decoration: isDialable
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت مساعد لعرض صف ملخص
  Widget _buildSummaryRow(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.black54,
    bool wrapText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              maxLines: wrapText ? null : 2,
              overflow: wrapText ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت لعرض تفاصيل المحل في ExpansionTile
  Widget _buildStoreDetailsTile(Map<String, dynamic> data, bool isClientOrder) {
    if (!isClientOrder) {
      // مرونة في استخراج البيانات
      final String name = data['storeName']?.toString() ?? 'غير معروف';
      final String address = data['storeAddress']?.toString() ?? 'غير محدد';
      final String phoneNumber = data['storePhone']?.toString() ?? 'غير متاح';
      final double payout = (data['totalStorePayout'] is num
          ? data['totalStorePayout'].toDouble()
          : 0.0);
      final GeoPoint? location = (data['storeLocation'] as GeoPoint?);

      return ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.store, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
        leading: const Icon(Icons.arrow_right, color: Colors.blue),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        children: [
          _buildDetailRow('العنوان:', address, Icons.location_on),
          // 💡 استخدام _buildPhoneLink
          _buildPhoneLink(phoneNumber, Icons.phone),
          _buildDetailRow(
            'المبلغ للمحل:',
            '$payout جنيه',
            Icons.paid,
            color: Colors.red,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (location != null)
                      ? () => _launchMaps(location.latitude, location.longitude)
                      : null,
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: const Text(
                    'خريطة المحل',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (location != null)
                        ? Colors.deepOrange
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (phoneNumber != 'غير متاح')
                      ? () => _makePhoneCall(phoneNumber)
                      : null,
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text(
                    'اتصال بالمحل',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (phoneNumber != 'غير متاح')
                        ? Colors.blue
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Container();
  }

  // ويدجت لعرض الأصناف في ExpansionTile
  Widget _buildItemsTile(
    List<dynamic>? items,
    String? orderDescription,
    bool isStoreOrder,
  ) {
    if (!isStoreOrder) {
      return Container();
    }

    final bool isStoreOrderWithItems = items != null && items.isNotEmpty;

    if (!isStoreOrderWithItems) {
      return Container();
    }

    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.list_alt, color: Colors.green),
          const SizedBox(width: 8),
          const Text(
            'الأصناف المطلوبة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green,
            ),
          ),
        ],
      ),
      leading: const Icon(Icons.arrow_right, color: Colors.blue),
      childrenPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      children: [
        if (orderDescription != null && orderDescription.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'وصف الطلب: $orderDescription',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ...items.map((item) {
          if (item is Map<String, dynamic>) {
            final String name = item['name']?.toString() ?? 'منتج غير معروف';
            final String size = item['size']?.toString() ?? '';
            // مرونة في التعامل مع الكمية والسعر
            final int quantity = (item['quantity'] is num)
                ? item['quantity'].toInt()
                : 1;
            final double price = (item['subtotal'] is num)
                ? item['subtotal'].toDouble()
                : 0.0;
            final String? imageUrl = item['imageUrl']?.toString();
            final String description = item['description']?.toString() ?? '';
            final List<dynamic>? addons = item['addons'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.image_not_supported),
                      ),
                    ),

                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$quantity x $name',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        if (size.isNotEmpty)
                          Text(
                            'الحجم: $size',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        if (addons != null && addons.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: addons.map((addon) {
                              if (addon is Map<String, dynamic>) {
                                final String addonName =
                                    addon['name']?.toString() ??
                                    'إضافة غير معروفة';
                                final double addonPrice =
                                    (addon['price'] is num)
                                    ? addon['price'].toDouble()
                                    : 0.0;
                                return Text(
                                  'إضافة: $addonName (+$addonPrice جنيه)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }).toList(),
                          ),
                        Text(
                          'السعر: $price جنيه',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return Container();
        }),
      ],
    );
  }

  // ويدجت لعرض تفاصيل العميل في ExpansionTile
  Widget _buildCustomerDetailsTile(Map<String, dynamic> data) {
    // مرونة في استخراج البيانات
    final String name = data['customerName']?.toString() ?? 'غير معروف';
    final String address = data['customerAddress']?.toString() ?? 'غير محدد';
    final String phoneNumber = data['customerPhone']?.toString() ?? 'غير متاح';
    final double grandTotal = (data['grandTotal'] is num
        ? data['grandTotal'].toDouble()
        : 0.0);
    final GeoPoint? location = (data['customerLocation'] as GeoPoint?);

    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.person, color: Colors.purple),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.purple,
            ),
          ),
        ],
      ),
      leading: const Icon(Icons.arrow_right, color: Colors.blue),
      childrenPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      children: [
        _buildDetailRow('العنوان:', address, Icons.location_on, wrapText: true),
        // 💡 استخدام _buildPhoneLink
        _buildPhoneLink(phoneNumber, Icons.phone),
        // 💡 الملاحظات (جديدة)
        if (data['customerNotes'] != null &&
            data['customerNotes'].toString().isNotEmpty)
          _buildDetailRow(
            'ملاحظات:',
            data['customerNotes'].toString(),
            Icons.sticky_note_2,
            wrapText: true,
          ),
        _buildDetailRow(
          ' المستحق من العميل :',
          '$grandTotal جنيه',
          Icons.monetization_on,
          color: Colors.green,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (location != null)
                    ? () => _launchMaps(location.latitude, location.longitude)
                    : null,
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text(
                  'خريطة العميل',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (location != null)
                      ? Colors.deepOrange
                      : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (phoneNumber != 'غير متاح')
                    ? () => _makePhoneCall(phoneNumber)
                    : null,
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text(
                  'اتصال بالعميل',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (phoneNumber != 'غير متاح')
                      ? Colors.blue
                      : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ويدجت مساعد لعرض صف تفاصيل
  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
    bool wrapText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: wrapText
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.black54),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color ?? Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: color ?? Colors.black87),
              overflow: wrapText ? TextOverflow.clip : TextOverflow.ellipsis,
              maxLines: wrapText ? null : 1,
            ),
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
          'الأوردرات قيد التوصيل',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        // دمج الـ Streams باستخدام Rx.combineLatest2
        stream: Rx.combineLatest2(
          FirebaseFirestore.instance
              .collection('orders') // أوردرات المحلات
              .where('status', isEqualTo: 'accepted')
              .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
              .snapshots(),
          FirebaseFirestore.instance
              .collection('client_orders') // أوردرات العملاء
              .where('status', isEqualTo: 'accepted')
              .where('assignedAgentPhone', isEqualTo: widget.agentPhone)
              .snapshots(),
          (QuerySnapshot storeSnapshot, QuerySnapshot clientSnapshot) {
            final allOrders = <QueryDocumentSnapshot>[];
            allOrders.addAll(storeSnapshot.docs);
            allOrders.addAll(clientSnapshot.docs);

            // ترتيب الأوردرات حسب تاريخ القبول
            allOrders.sort((a, b) {
              final acceptedAtA =
                  (a.data() as Map<String, dynamic>)['acceptedAt']
                      as Timestamp?;
              final acceptedAtB =
                  (b.data() as Map<String, dynamic>)['acceptedAt']
                      as Timestamp?;
              if (acceptedAtA == null || acceptedAtB == null) return 0;
              // الترتيب من الأقدم للأحدث
              return acceptedAtA.compareTo(acceptedAtB);
            });
            return allOrders;
          },
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _logger.e('Error loading orders: ${snapshot.error}');
            return Center(
              child: Text(
                'خطأ في تحميل الأوردرات: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            if (_activeOrdersCount != 0) {
              _updateAgentActiveOrders(0);
            }
            return const Center(
              child: Text(
                'لا توجد أوردرات قيد التوصيل حالياً.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          final allOrdersList = snapshot.data!;

          // ⭐️ الخطوة الجديدة: نحدث العدد بعد ما الأوردرات الجديدة وصلت
          if (_activeOrdersCount != allOrdersList.length) {
            _updateAgentActiveOrders(allOrdersList.length);
          }
          final allOrders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: allOrders.length,
            itemBuilder: (context, index) {
              final doc = allOrders[index];
              final data = doc.data() as Map<String, dynamic>;

              final bool isStoreOrder = data.containsKey('storeName');
              final String orderType = isStoreOrder
                  ? 'اوردر زد'
                  : 'اوردر توصيل';

              // 👈 تعديل طريقة استخراج pickupAddress لاستخدام 'storeAddress' في Client Orders
              final String pickupAddress = isStoreOrder
                  ? (data['storeAddress']?.toString() ?? 'عنوان محل غير محدد')
                  : (data['storeAddress']?.toString() ??
                        data['pickupAddress']?.toString() ??
                        'مكان خارجي غير محدد');

              final String dropoffAddress =
                  data['customerAddress']?.toString() ?? 'عنوان عميل غير محدد';
              final String orderDescription =
                  data['orderDescription']?.toString() ?? 'لا يوجد وصف إضافي.';

              final String orderNumber = (data['orderNumber'] != null)
                  ? (data['orderNumber'] is num
                        ? data['orderNumber'].toString()
                        : data['orderNumber'].toString())
                  : doc.id.substring(0, 5);

              // دايماً بيمثل سعر التوصيل عشان نحسب منه العمولة (استخدام مرن للـ num)
              final double totalDeliveryPrice =
                  (isStoreOrder ? data['deliveryFee'] : data['deliveryPrice'])
                      is num
                  ? (isStoreOrder ? data['deliveryFee'] : data['deliveryPrice'])
                        .toDouble()
                  : 0.0;
              final double grandTotal = (data['grandTotal'] is num
                  ? data['grandTotal'].toDouble()
                  : 0.0);
              final double totalStorePayout = (data['totalStorePayout'] is num
                  ? data['totalStorePayout'].toDouble()
                  : 0.0);
              final Timestamp? acceptedAt = data['acceptedAt'] as Timestamp?;
              final String formattedAcceptedAt = acceptedAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(acceptedAt.toDate())
                  : 'غير متاح';

              final String collectionName = isStoreOrder
                  ? 'orders'
                  : 'client_orders';

              return Card(
                key: ValueKey(doc.id),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8.0,
                          right: 6.0,
                          left: 6.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // إخفاء رقم الأوردر في أوردرات التوصيل (Client Orders)
                            if (isStoreOrder)
                              Text(
                                '$orderType رقم: $orderNumber',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                ),
                              )
                            else
                              Text(
                                orderType,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                ),
                              ),

                            // عرض تفاصيل التوصيل مباشرةً في الملخص (تم تعديلها للاتصال)
                            if (!isStoreOrder) ...[
                              const SizedBox(height: 5),

                              // 1. الاستلام من (يسمح بالاتصال برقم المحل أو الرقم المستخرج من العنوان)
                              _buildPhoneLink(
                                data['storePhone']?.toString() ?? pickupAddress,
                                Icons.storefront,
                              ),

                              // 2. التسليم لـ (رقم العميل)
                              _buildPhoneLink(
                                data['customerPhone']?.toString() ??
                                    dropoffAddress,
                                Icons.person_pin,
                              ),

                              // 3. الوصف (لو فيه رقم مش متكرر في اللي فات، نعرضه كرابط اتصال)
                              ..._buildDescriptionWidgets(
                                orderDescription,
                                data['storePhone']?.toString(),
                                data['customerPhone']?.toString(),
                              ),

                              // سعر التوصيل
                              _buildSummaryRow(
                                'سعر التوصيل :',
                                '$totalDeliveryPrice جنيه',
                                Icons.local_shipping,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 5),
                            ],
                          ], // <-- قفل الـ children بتاعة الـ Column الداخلية
                        ), // <-- قفل الـ Column الداخلية
                      ), // <-- قفل الـ Padding

                      const Divider(), // <-- أول فاصل بعد الملخص (سليم)
                      // 1. تفاصيل المحل (هتظهر فقط لأوردرات المحلات)
                      _buildStoreDetailsTile(data, !isStoreOrder),

                      // 2. تفاصيل الأصناف/الوصف (هتظهر فقط لأوردرات المحلات)
                      _buildItemsTile(
                        data['items'] as List<dynamic>?,
                        data['description'], // أضف هذا السطر لتمرير وصف الأوردر من Firestore
                        isStoreOrder,
                      ),

                      // 3. تفاصيل العميل (هتظهر بس لو كان أوردر محل)
                      if (isStoreOrder) _buildCustomerDetailsTile(data),

                      // 4. تاريخ القبول (هتظهر بس لو كان أوردر محل)
                      if (isStoreOrder)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                'تاريخ القبول:',
                                formattedAcceptedAt,
                                Icons.access_time,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      // زر "تم التسليم"
                      ElevatedButton.icon(
                        onPressed: () => _completeOrder(
                          orderId: doc.id,
                          collectionName: collectionName,
                          context: context,
                          deliveryPrice: totalDeliveryPrice,
                          grandTotal: grandTotal,
                          totalStorePayout: totalStorePayout,
                        ),
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                        label: const Text(
                          'تم التسليم',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(double.infinity, 55),
                        ),
                      ),
                    ], // <-- قفل الـ children بتاعة الـ Column الرئيسية
                  ), // <-- قفل الـ Column الرئيسية
                ), // <-- قفل الـ Padding اللي جوا الـ Card
              ); // <-- قفل الـ Card
            },
          );
        },
      ),
    );
  }
}
