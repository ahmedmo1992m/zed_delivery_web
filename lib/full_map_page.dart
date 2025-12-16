// file: full_map_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// ----------------------------------------------
// 📌 1. تحويل الـ StatelessWidget إلى StatefulWidget
// ----------------------------------------------
class FullMapPage extends StatefulWidget {
  final LatLng? agentLocation;
  final GeoPoint storeLocation;
  final GeoPoint customerLocation;
  final String orderId;

  const FullMapPage({
    super.key,
    required this.agentLocation,
    required this.storeLocation,
    required this.customerLocation,
    required this.orderId,
  });

  @override
  State<FullMapPage> createState() => _FullMapPageState();
}

class _FullMapPageState extends State<FullMapPage> {
  List<LatLng> _routePoints = [];
  bool _isRouteLoading = true;
  double? _durationInSeconds; // 💡 متغير جديد لحفظ زمن الوصول المتوقع (ETA)

  @override
  void initState() {
    super.initState();
    _getRoute();
  }

  // ----------------------------------------------
  // 📌 2. دالة جلب المسار وتخزين الزمن من OSRM
  // ----------------------------------------------
  Future<void> _getRoute() async {
    final start =
        '${widget.storeLocation.longitude},${widget.storeLocation.latitude}';
    final end =
        '${widget.customerLocation.longitude},${widget.customerLocation.latitude}';

    final url =
        'http://router.project-osrm.org/route/v1/driving/$start;$end?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null) {
          final coordinates =
              data['routes'][0]['geometry']['coordinates'] as List<dynamic>;

          // 💡 استخراج زمن الوصول (Duration) بالثواني
          final duration = data['routes'][0]['duration'] as double?;

          final List<LatLng> points = [];
          for (var coord in coordinates) {
            points.add(LatLng(coord[1] as double, coord[0] as double));
          }

          if (mounted) {
            setState(() {
              _routePoints = points;
              _durationInSeconds = duration; // 👈 حفظ قيمة الزمن
              _isRouteLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isRouteLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRouteLoading = false;
        });
      }
    }
  }

  // ----------------------------------------------
  // 📌 3. الدوال المساعدة
  // ----------------------------------------------
  Stream<DocumentSnapshot> _getAgentLiveLocationStream(String agentId) {
    return FirebaseFirestore.instance
        .collection('agents')
        .doc(agentId)
        .snapshots();
  }

  LatLng _toLatLng(GeoPoint geoPoint) {
    return LatLng(geoPoint.latitude, geoPoint.longitude);
  }

  // ----------------------------------------------
  // 📌 4. الـ Build method مع زرار رجوع مخصص
  // ----------------------------------------------
  @override
  Widget build(BuildContext context) {
    final initialTarget =
        widget.agentLocation ?? _toLatLng(widget.storeLocation);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التتبع الحي '),
        centerTitle: true,
        // 💡 استخدام زرار رجوع مخصص لإرجاع قيمة الزمن
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // نرجع قيمة الزمن (بالثواني) اللي حسبناها
            Navigator.of(context).pop(_durationInSeconds);
          },
        ),
      ),
      body: _isRouteLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderId)
                  .snapshots(),
              builder: (context, orderSnapshot) {
                if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
                  return const Center(
                    child: Text('جاري تحميل بيانات التتبع...'),
                  );
                }

                final orderData =
                    orderSnapshot.data!.data() as Map<String, dynamic>;
                final agentId = orderData['agentId'] as String?;
                final status = orderData['status'] as String?;

                if (agentId == null || status != 'accepted') {
                  // لو مفيش تتبع حالي، نرجع الخريطة بالموقع الثابت
                  return _buildFlutterMap(
                    context,
                    initialTarget,
                    widget.agentLocation,
                    widget.storeLocation,
                    widget.customerLocation,
                  );
                }

                // لو فيه تتبع، نستخدم StreamBuilder تاني لموقع المندوب
                return StreamBuilder<DocumentSnapshot>(
                  stream: _getAgentLiveLocationStream(agentId),
                  builder: (context, agentSnapshot) {
                    LatLng? liveAgentLocation = widget.agentLocation;

                    if (agentSnapshot.hasData && agentSnapshot.data!.exists) {
                      final agentData =
                          agentSnapshot.data!.data() as Map<String, dynamic>;
                      final agentLat = agentData['latitude'] as double?;
                      final agentLng = agentData['longitude'] as double?;

                      if (agentLat != null && agentLng != null) {
                        liveAgentLocation = LatLng(agentLat, agentLng);
                      }
                    }

                    return _buildFlutterMap(
                      context,
                      liveAgentLocation ?? initialTarget,
                      liveAgentLocation,
                      widget.storeLocation,
                      widget.customerLocation,
                    );
                  },
                );
              },
            ),
    );
  }

  // ----------------------------------------------
  // 📌 5. دالة _buildFlutterMap (لأنها جزء من الـ State)
  // ----------------------------------------------
  Widget _buildFlutterMap(
    BuildContext context,
    LatLng center,
    LatLng? liveAgentLocation,
    GeoPoint storeLocation,
    GeoPoint customerLocation,
  ) {
    final storeLatLng = _toLatLng(storeLocation);
    final customerLatLng = _toLatLng(customerLocation);

    final List<Marker> markers = [
      Marker(
        point: customerLatLng,
        width: 80,
        height: 80,
        child: const Icon(Icons.location_on, color: Colors.green, size: 40),
      ),
      Marker(
        point: storeLatLng,
        width: 80,
        height: 80,
        child: const Icon(Icons.store, color: Colors.red, size: 40),
      ),
    ];

    if (liveAgentLocation != null) {
      markers.add(
        Marker(
          point: liveAgentLocation,
          width: 80,
          height: 80,
          child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 40),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15.0,
        minZoom: 3.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yourcompany.sapeq',
        ),
        PolylineLayer(
          polylines: [
            if (_routePoints.isNotEmpty)
              Polyline(
                points: _routePoints,
                color: Colors.orange.shade700,
                strokeWidth: 5.0,
              ),
          ],
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
