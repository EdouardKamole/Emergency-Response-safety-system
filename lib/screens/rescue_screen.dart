import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class RescueScreen extends StatefulWidget {
  const RescueScreen({Key? key}) : super(key: key);

  @override
  State<RescueScreen> createState() => _RescueScreenState();
}

class _RescueScreenState extends State<RescueScreen> {
  Completer<GoogleMapController> _controller = Completer();
  static const LatLng _center = const LatLng(
    45.521563,
    -122.677433,
  ); // Default map center

  LatLng? _currentLocation;
  LatLng? _rescueLocation;
  String _eta = "Calculating...";
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  DatabaseReference? _locationRef;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _getCurrentLocation();
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    _locationRef = FirebaseDatabase.instance.ref().child('rescue_location');
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateVictimLocation(); // Update Firebase with victim's location
        _startListeningForRescueUpdates(); // Start listening for rescue location updates
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _updateVictimLocation() async {
    if (_currentLocation != null && _locationRef != null) {
      await _locationRef!.child('victim').set({
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      });
    }
  }

  void _startListeningForRescueUpdates() {
    if (_locationRef != null) {
      _locationRef!.child('rescue').onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final latitude = data['latitude'];
          final longitude = data['longitude'];
          if (latitude != null && longitude != null) {
            setState(() {
              _rescueLocation = LatLng(latitude, longitude);
              _updateMarkersAndPolylines();
              _calculateETA(); // Recalculate ETA when rescue location changes
            });
          }
        }
      });
    }
  }

  Future<void> _calculateETA() async {
    // *** Replace with your actual ETA calculation logic ***
    // This is a placeholder - you'll need a service or algorithm
    // to calculate the ETA based on the victim and rescue locations.
    if (_currentLocation != null && _rescueLocation != null) {
      setState(() {
        _eta = "10 minutes (Placeholder)"; // Replace with actual calculation
      });
    }
  }

  void _updateMarkersAndPolylines() {
    _markers.clear();
    _polylines.clear();

    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('victim'),
          position: _currentLocation!,
          infoWindow: InfoWindow(title: 'Victim Location'),
        ),
      );
    }

    if (_rescueLocation != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('rescue'),
          position: _rescueLocation!,
          infoWindow: InfoWindow(title: 'Rescue Location'),
        ),
      );

      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blue,
          points: [_currentLocation!, _rescueLocation!],
          width: 5,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Rescue Screen")),
      body:
          _currentLocation == null
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Help is on the way!",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Arriving ETA: $_eta"), // Display ETA
                  ),
                  Expanded(
                    child: GoogleMap(
                      mapType: MapType.hybrid,
                      initialCameraPosition: CameraPosition(
                        target: _currentLocation!,
                        zoom: 12.0,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                      },
                      markers: _markers, // Use the updated markers
                      polylines: _polylines, // Use the polyline
                    ),
                  ),
                ],
              ),
    );
  }
}
