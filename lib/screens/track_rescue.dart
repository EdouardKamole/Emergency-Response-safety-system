import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  int? _etaSeconds;
  DatabaseReference? _rescuerRef;
  StreamSubscription<DatabaseEvent>? _rescuerListener;

  @override
  void initState() {
    super.initState();
    // Add emergency location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('emergency'),
        position: LatLng(widget.emergencyLat, widget.emergencyLon),
        infoWindow: const InfoWindow(title: 'Emergency Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    _listenToRescuerLocation();
  }

  void _listenToRescuerLocation() {
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
              _etaSeconds = eta;
              _markers.removeWhere((m) => m.markerId.value == 'rescuer');
              _markers.add(
                Marker(
                  markerId: const MarkerId('rescuer'),
                  position: LatLng(latitude, longitude),
                  infoWindow: const InfoWindow(title: 'Rescuer'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                ),
              );
            });

            _mapController?.animateCamera(
              CameraUpdate.newLatLng(LatLng(latitude, longitude)),
            );
          }
        } else {
          setState(() {
            _etaSeconds = null;
            _markers.removeWhere((m) => m.markerId.value == 'rescuer');
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        print("Error listening to rescuer location: $error");
        setState(() {
          _etaSeconds = null;
          _markers.removeWhere((m) => m.markerId.value == 'rescuer');
        });
        // Stop listening if the report is deleted
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
    _rescuerListener = null;
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Track Rescuer",
          style: GoogleFonts.poppins(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red.shade500,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 4,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.emergencyLat, widget.emergencyLon),
                zoom: 15,
              ),
              markers: _markers,
              onMapCreated: (controller) {
                if (mounted) {
                  setState(() {
                    _mapController = controller;
                  });
                }
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16.w),
            color: Colors.grey.shade100,
            child: Text(
              _etaSeconds != null
                  ? 'ETA: ${(_etaSeconds! / 60).round()} minutes'
                  : 'Waiting for rescuer assignment...',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
