import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:firebase_database/firebase_database.dart';

class TrackRescuerScreen extends StatefulWidget {
  final String reportId;
  final double emergencyLat;
  final double emergencyLon;

  const TrackRescuerScreen({
    required this.reportId,
    required this.emergencyLat,
    required this.emergencyLon,
    Key? key,
  }) : super(key: key);

  @override
  _TrackRescuerScreenState createState() => _TrackRescuerScreenState();
}

class _TrackRescuerScreenState extends State<TrackRescuerScreen> {
  MapController? _mapController;
  Set<Marker> _markers = {};
  List<latlong.LatLng> _routePoints = [];
  int? _etaSeconds;
  DatabaseReference? _rescuerRef;
  StreamSubscription<DatabaseEvent>? _rescuerListener;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Add emergency location marker
    _markers = {
      Marker(
        point: latlong.LatLng(widget.emergencyLat, widget.emergencyLon),
        width: 50.0,
        height: 50.0,
        child: const Icon(
          Icons.person_pin_circle,
          color: Colors.blue,
          size: 50,
        ),
      ),
    };
    _listenToRescuerLocation();
  }

  void _listenToRescuerLocation() {
    setState(() {
      _isLoading = true;
    });
    _rescuerRef = FirebaseDatabase.instance.ref(
      'reports/${widget.reportId}/assignedRescuer',
    );
    _rescuerListener = _rescuerRef!.onValue.listen(
      (event) {
        if (!mounted) return;

        final data = event.snapshot.value as Map?;
        if (data != null && data.isNotEmpty) {
          final rescuerId = data.keys.first;
          final rescuerData = Map<String, dynamic>.from(data[rescuerId]);
          final latitude = (rescuerData['latitude'] as num?)?.toDouble();
          final longitude = (rescuerData['longitude'] as num?)?.toDouble();
          final eta = rescuerData['eta'] as int?;

          if (latitude != null && longitude != null) {
            setState(() {
              _isLoading = false;
              _etaSeconds = eta;
              _markers.removeWhere((m) => m.key == const ValueKey('rescuer'));
              _markers.add(
                Marker(
                  width: 45.0,
                  height: 45.0,
                  key: const ValueKey('rescuer'),
                  point: latlong.LatLng(latitude, longitude),
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.red,
                    size: 45,
                  ),
                ),
              );
              // Update route points for polyline
              _routePoints
                ..clear()
                ..add(latlong.LatLng(widget.emergencyLat, widget.emergencyLon))
                ..add(latlong.LatLng(latitude, longitude));
            });

            _mapController?.move(latlong.LatLng(latitude, longitude), 15.0);
          }
        } else {
          setState(() {
            _isLoading = false;
            _etaSeconds = null;
            _markers.removeWhere((m) => m.key == const ValueKey('rescuer'));
            _routePoints.clear();
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        print("Error listening to rescuer location: $error");
        setState(() {
          _isLoading = false;
          _etaSeconds = null;
          _markers.removeWhere((m) => m.key == const ValueKey('rescuer'));
          _routePoints.clear();
        });
        _rescuerListener?.cancel();
        _rescuerListener = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report no longer available")),
        );
      },
    );
  }

  @override
  void dispose() {
    _rescuerListener?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latlong.LatLng(
                widget.emergencyLat,
                widget.emergencyLon,
              ),
              initialZoom: 13.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: _markers.toList()),
            ],
          ),

          // Gradient overlay at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // Custom App Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.redAccent),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      "Track Rescuer",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status indicator
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _etaSeconds != null
                                  ? 'ETA: ${(_etaSeconds! / 60).round()} minutes'
                                  : 'Waiting for rescuer assignment...',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Rescuer Unit #RES-001",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.redAccent, Colors.red[700]!],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "ETA: ${_etaSeconds != null ? (_etaSeconds! / 60).round() : '--'} mins",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController?.move(
                      latlong.LatLng(widget.emergencyLat, widget.emergencyLon),
                      (_mapController?.camera.zoom ?? 13) + 1,
                    );
                  },
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController?.move(
                      latlong.LatLng(widget.emergencyLat, widget.emergencyLon),
                      (_mapController?.camera.zoom ?? 13) - 1,
                    );
                  },
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
