import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 💡 استيراد مكتبة flutter_map
import 'package:latlong2/latlong.dart'; // 💡 استيراد مكتبة latlong2
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui; // 💡 تم إعادة استيراد dart:ui لاستخدام Path و Canvas

class AgentMapScreen extends StatefulWidget {
  final String managerId; // 💡 تم إضافة managerId هنا

  const AgentMapScreen({
    super.key,
    required this.managerId,
  }); // 💡 يجب أن يكون managerId مطلوباً

  @override
  State<AgentMapScreen> createState() => _AgentMapScreenState();
}

class _AgentMapScreenState extends State<AgentMapScreen> {
  final MapController _mapController =
      MapController(); // متحكم الخريطة لـ flutter_map
  final List<Marker> _markers = []; // لتخزين علامات المناديب

  // 💡 تم حذف دالة _fetchAcceptedOrdersCount لتبسيط الكود والاعتماد على حقل active_orders_count

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مواقع المناديب على الخريطة',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 💡 بنستمع لتغييرات بيانات المناديب في Firestore التابعين للمدير الحالي
        stream: FirebaseFirestore.instance
            .collection('agents')
            .where(
              'manager_id',
              isEqualTo: widget.managerId,
            ) // 💡 فلترة حسب managerId
            .snapshots(),
        builder: (context, agentSnapshot) {
          if (agentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (agentSnapshot.hasError) {
            return Center(
              child: Text(
                'خطأ في تحميل بيانات المناديب: ${agentSnapshot.error}',
              ),
            );
          }
          if (!agentSnapshot.hasData || agentSnapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد بيانات مناديب لعرضها على الخريطة.'),
            );
          }

          // 💡 هنا هنعتمد مباشرة على بيانات المناديب الجاهزة في الـ StreamBuilder
          _markers.clear();

          List<DocumentSnapshot> managerAgents = agentSnapshot.data!.docs;

          // 💡 بناء علامات الخريطة
          for (final doc in managerAgents) {
            final agentData = doc.data() as Map<String, dynamic>;
            final agentName = agentData['agentName'] ?? 'مندوب غير معروف';
            // final String agentPhone = agentData['agentPhone'] ?? ''; // لم تعد ضرورية هنا
            final double? latitude = (agentData['latitude'] as num?)
                ?.toDouble();
            final double? longitude = (agentData['longitude'] as num?)
                ?.toDouble();
            final bool isOnline = agentData['isOnline'] ?? false;

            // ⭐⭐ التعديل الرئيسي: جلب عدد الأوردرات النشطة من حقل المندوب ⭐⭐
            final int activeOrdersCount =
                (agentData['active_orders_count'] as num?)?.toInt() ?? 0;
            // 💡 تحديد لون حالة المندوب بناءً على activeOrdersCount
            Color statusColor = Colors.green.shade800;
            String statusText = 'بدون أوردرات';

            if (activeOrdersCount > 0) {
              statusColor = Colors.orange.shade800;
              statusText = 'معه $activeOrdersCount أوردرات';
            } else if (!isOnline) {
              statusColor = Colors.red.shade800;
              statusText = 'غير متصل';
            }

            // عرض المندوب فقط إذا كان "أون لاين" (ومعاه أو ممعاهوش أوردر)
            if (latitude != null && longitude != null && isOnline) {
              final LatLng position = LatLng(latitude, longitude);

              final marker = Marker(
                point: position,
                width: 200,
                height: 100, // 💡 زيادة الارتفاع لاستيعاب 3 أسطر نصية
                alignment:
                    Alignment.topCenter, // عشان السهم يبقى تحت النقطة بالظبط
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.3 * 255).toInt()),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        // ⭐⭐ التعديل الرئيسي: عرض activeOrdersCount ⭐⭐
                        '$agentName\n$statusText',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14, // 💡 تصغير الخط قليلاً لاستيعاب 3 أسطر
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 💡 السهم الصغير تحت اسم المندوب
                    CustomPaint(
                      painter: _ArrowPainter(), // دالة الرسم للسهم
                      child: const SizedBox(width: 20, height: 10), // حجم السهم
                    ),
                  ],
                ),
              );
              _markers.add(marker); // إضافة الـ marker للقائمة
            }
          }

          // تحديد موقع الكاميرا الأولي
          LatLng initialCameraPosition = const LatLng(
            30.0444,
            31.2357,
          ); // القاهرة، مصر

          // لو فيه مناديب أون لاين، نركز الخريطة على أول واحد
          if (_markers.isNotEmpty) {
            initialCameraPosition = _markers.first.point;
          } else if (agentSnapshot.data!.docs.isNotEmpty) {
            // لو مفيش علامات (محدش أون لاين)، نرجع لأول مندوب عشان نركز الخريطة في مكانه لو كان موقعه معروف
            final firstAgentData =
                agentSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            final double? lat = (firstAgentData['latitude'] as num?)
                ?.toDouble();
            final double? lng = (firstAgentData['longitude'] as num?)
                ?.toDouble();
            if (lat != null && lng != null) {
              initialCameraPosition = LatLng(lat, lng);
            }
          }

          return FlutterMap(
            mapController: _mapController, // ربط المتحكم بالخريطة
            options: MapOptions(
              initialCenter: initialCameraPosition,
              initialZoom: 10.0, // مستوى التكبير الأولي
              maxZoom: 18.0, // أقصى تكبير
              minZoom: 3.0, // أدنى تكبير
            ),
            children: [
              // 💡 طبقة الـ Tile (الخريطة نفسها)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.ridersapeq', // اسم الباكيج بتاعك
              ),
              // 💡 طبقة الـ Markers (علامات المناديب)
              MarkerLayer(
                markers: _markers, // عرض علامات المناديب
              ),
            ],
          );
        },
      ),
    );
  }
}

// 💡 CustomPainter لرسم السهم أسفل العلامة (لم يتغير)
class _ArrowPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // 💡 استخدام ui.Canvas و ui.Size
    final ui.Paint paint = ui.Paint()
      ..color = Colors.white; // 💡 استخدام ui.Paint
    final ui.Path path = ui.Path(); // 💡 استخدام ui.Path
    path.moveTo(size.width / 2 - 10, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + 10, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
