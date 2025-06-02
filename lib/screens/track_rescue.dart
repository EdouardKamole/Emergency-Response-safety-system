import 'dart:async';
import 'dart:convert';
import 'package:emergency_response_safety_system_ambulance_side/utils/tracking_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

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

class _TrackRescuerScreenState extends State<TrackRescuerScreen>
    with TickerProviderStateMixin {
  late latlong.LatLng _emergencyLocation;
  late AnimationController _pulseController;
  late AnimationController _routeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _routeAnimation;
  late StreamSubscription<DatabaseEvent> _rescuerSubscription;
  StreamSubscription<Position>? _positionSubscription; // New: For victim location
  final MapController _mapController = MapController();
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastRouteFetch;
  bool _hasUserInteractedWithMap = false;
  double _lastZoom = 13.0;

  final List<Map<String, dynamic>> _statuses = [
    {
      "text": "En Route to Patient",
      "icon": Icons.directions_car,
      "color": Colors.orange,
    },
    {"text": "At Scene", "icon": Icons.location_on, "color": Colors.blue},
    {
      "text": "Transporting Patient",
      "icon": Icons.local_hospital,
      "color": Colors.green,
    },
    {
      "text": "Arrived at Hospital",
      "icon": Icons.local_hospital,
      "color": Colors.red,
    },
  ];

  @override
  void initState() {
    super.initState();
    _emergencyLocation = latlong.LatLng(
      widget.emergencyLat,
      widget.emergencyLon,
    );

    // Check and request location permissions
    _checkLocationPermissions();

    // Start live victim location updates
    _startLocationUpdates();

    _fetchInitialRescuerData();
    _listenToRescuerUpdates();

    // Animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _routeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _routeController, curve: Curves.easeInOut),
    );
    _routeController.forward();

    // Center map initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recenterMap();
    });

    // Listen for user map interactions
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        _hasUserInteractedWithMap = true;
      } else if (_mapController.camera.zoom != _lastZoom) {
        _hasUserInteractedWithMap = true;
        _lastZoom = _mapController.camera.zoom;
      }
    });
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _errorMessage = "Location services are disabled.";
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _errorMessage = "Location permissions are denied.";
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _errorMessage = "Location permissions are permanently denied.";
        });
      }
      return;
    }
  }

  void _startLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(
      (Position position) async {
        if (!mounted) return;
        setState(() {
          _emergencyLocation = latlong.LatLng(position.latitude, position.longitude);
        });

        final database = FirebaseDatabase.instance.ref();
        final updateData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        };

        try {
          await database.child('reports/${widget.reportId}/location').set(updateData);
          final trackingState = Provider.of<TrackingState>(context, listen: false);
          trackingState.updateVictimLocation(
            widget.reportId,
            latlong.LatLng(position.latitude, position.longitude),
          );
          if (!_hasUserInteractedWithMap) {
            _fetchRoutePoints();
            _recenterMap();
          }
        } catch (e) {
          debugPrint("Error updating victim location: $e");
          if (mounted) {
            setState(() {
              _errorMessage = "Error updating victim location: $e";
            });
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorMessage = "Error fetching victim location: $e";
          });
        }
      },
    );
  }

  Future<void> _fetchInitialRescuerData() async {
    try {
      final database = FirebaseDatabase.instance.ref();
      final snapshot =
          await database.child('reports/${widget.reportId}/assignedRescuer').get();
      if (mounted) {
        setState(() {
          _isLoading = false;
          final data = snapshot.value as Map<dynamic, dynamic>?;
          final trackingState = Provider.of<TrackingState>(context, listen: false);
          if (data != null && data.isNotEmpty) {
            final rescuerId = data.keys.first;
            final rescuerData = Map<String, dynamic>.from(data[rescuerId]);
            final double? latitude = rescuerData['latitude']?.toDouble();
            final double? longitude = rescuerData['longitude']?.toDouble();
            final int? eta = rescuerData['eta']?.toInt();
            final String? status = rescuerData['status']?.toString();

            if (latitude != null && longitude != null) {
              trackingState.updateRescuerLocation(
                widget.reportId,
                latlong.LatLng(latitude, longitude),
              );
              trackingState.updateEta(widget.reportId, eta ?? 300);
              int statusStep = 0;
              if (status == 'arrived') statusStep = 1;
              trackingState.updateStatus(widget.reportId, statusStep);
              _fetchRoutePoints();
            } else {
              _errorMessage = "Invalid rescuer location data";
            }
          } else {
            _errorMessage = "Waiting for rescuer to be assigned";
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error fetching initial rescuer data: $error";
        });
      }
    }
  }

  void _listenToRescuerUpdates() {
    final database = FirebaseDatabase.instance.ref();
    _rescuerSubscription = database
        .child('reports/${widget.reportId}/assignedRescuer')
        .onValue
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              final trackingState = Provider.of<TrackingState>(context, listen: false);
              if (data != null && data.isNotEmpty) {
                final rescuerId = data.keys.first;
                final rescuerData = Map<String, dynamic>.from(data[rescuerId]);
                final double? latitude = rescuerData['latitude']?.toDouble();
                final double? longitude = rescuerData['longitude']?.toDouble();
                final int? eta = rescuerData['eta']?.toInt();
                final String? status = rescuerData['status']?.toString();

                if (latitude != null && longitude != null) {
                  trackingState.updateRescuerLocation(
                    widget.reportId,
                    latlong.LatLng(latitude, longitude),
                  );
                  trackingState.updateEta(widget.reportId, eta ?? 300);

                  double distance = Geolocator.distanceBetween(
                    latitude,
                    longitude,
                    _emergencyLocation.latitude,
                    _emergencyLocation.longitude,
                  );
                  int newStatusStep = trackingState.getStatusStep(widget.reportId);
                  if (distance < 100 && newStatusStep < 1) {
                    newStatusStep = 1; // At Scene
                  } else if (newStatusStep == 1 && distance > 100) {
                    newStatusStep = 2; // Transporting Patient
                  } else if (newStatusStep == 2 && distance > 1000) {
                    newStatusStep = 3; // Arrived at Hospital
                  } else if (status == 'arrived' && newStatusStep < 1) {
                    newStatusStep = 1;
                  }
                  trackingState.updateStatus(widget.reportId, newStatusStep);

                  if (!_hasUserInteractedWithMap) {
                    _fetchRoutePoints();
                    _recenterMap();
                  }

                  _routeController
                    ..reset()
                    ..forward();
                } else {
                  _errorMessage = "Invalid rescuer location data";
                }
              } else {
                _errorMessage = "Waiting for rescuer to be assigned";
              }
            });
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = "Error fetching rescuer data: $error";
              });
            }
          },
        );
  }

  Future<void> _fetchRoutePoints() async {
    if (_lastRouteFetch != null &&
        DateTime.now().difference(_lastRouteFetch!).inSeconds < 10) {
      return; // Throttle route requests
    }
    _lastRouteFetch = DateTime.now();

    final trackingState = Provider.of<TrackingState>(context, listen: false);
    final rescuerLoc = trackingState.getRescuerLocation(widget.reportId);
    if (rescuerLoc == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "Rescuer location unavailable";
        });
      }
      return;
    }

    const String apiKey =
        '5b3ce3597851110001cf624862ba9d9ce4314f088c7a3b8fec0f957e';
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${rescuerLoc.longitude},${rescuerLoc.latitude}&end=${_emergencyLocation.longitude},${_emergencyLocation.latitude}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coordinates =
            data['features'][0]['geometry']['coordinates'];
        final List<latlong.LatLng> newRoutePoints =
            coordinates
                .map((coord) => latlong.LatLng(coord[1], coord[0]))
                .toList();
        trackingState.updateRoutePoints(widget.reportId, newRoutePoints);
      } else {
        trackingState.updateRoutePoints(widget.reportId, [
          rescuerLoc,
          _emergencyLocation,
        ]);
        if (mounted) {
          setState(() {
            _errorMessage = "Failed to fetch route, using direct path";
          });
        }
      }
    } catch (e) {
      trackingState.updateRoutePoints(widget.reportId, [
        rescuerLoc,
        _emergencyLocation,
      ]);
      if (mounted) {
        setState(() {
          _errorMessage = "Error fetching route, using direct path";
        });
      }
    }
  }

  Widget _buildCustomMarker({
    required IconData icon,
    required Color color,
    required double size,
    bool isPulsing = false,
  }) {
    return AnimatedBuilder(
      animation:
          isPulsing ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: isPulsing ? _pulseAnimation.value : 1.0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: isPulsing ? 5 : 2,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: size * 0.6),
          ),
        );
      },
    );
  }

  void _recenterMap() {
    final trackingState = Provider.of<TrackingState>(context, listen: false);
    final rescuerLoc = trackingState.getRescuerLocation(widget.reportId);
    final bounds = LatLngBounds.fromPoints([
      _emergencyLocation,
      rescuerLoc ?? _emergencyLocation,
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(50.w)),
    );
    _hasUserInteractedWithMap = false;
    _lastZoom = _mapController.camera.zoom;
  }

  @override
  void dispose() {
    _rescuerSubscription.cancel();
    _positionSubscription?.cancel();
    _pulseController.dispose();
    _routeController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = Provider.of<TrackingState>(context);
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _emergencyLocation,
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
              PolylineLayer(
                polylines: [
                  if (trackingState.getRoutePoints(widget.reportId).length > 1)
                    Polyline(
                      points: trackingState.getRoutePoints(widget.reportId),
                      color: Colors.redAccent.withOpacity(0.8),
                      strokeWidth: 4.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 50.0,
                    height: 50.0,
                    point: _emergencyLocation,
                    child: _buildCustomMarker(
                      icon: Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 50,
                      isPulsing: true,
                    ),
                  ),
                  if (trackingState.getRescuerLocation(widget.reportId) != null)
                    Marker(
                      width: 45.0,
                      height: 45.0,
                      point: trackingState.getRescuerLocation(widget.reportId)!,
                      child: _buildCustomMarker(
                        icon: Icons.local_hospital,
                        color: _statuses[trackingState.getStatusStep(widget.reportId)]["color"],
                        size: 45,
                        isPulsing: false,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
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
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.redAccent,
                    ),
                  ),
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
          Positioned(
            right: 20,
            bottom: 230,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "recenter",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _recenterMap,
                  child: const Icon(Icons.my_location, color: Colors.redAccent),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom) + 1,
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
                    _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom) - 1,
                    );
                  },
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Container(
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
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _errorMessage ==
                                    "Waiting for rescuer to be assigned"
                                ? Colors.orange
                                : Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Container(
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _statuses[trackingState.getStatusStep(widget.reportId)]["color"]
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _statuses[trackingState.getStatusStep(widget.reportId)]["icon"],
                                    color: _statuses[trackingState.getStatusStep(widget.reportId)]["color"],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _statuses[trackingState.getStatusStep(widget.reportId)]["text"],
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Rescuer Unit #${FirebaseAuth.instance.currentUser?.uid.substring(0, 6) ?? 'RES-001'}",
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
                                      colors: [
                                        Colors.redAccent,
                                        Colors.red[700]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "ETA: ${(trackingState.getEtaSeconds(widget.reportId) ~/ 60).clamp(1, 15)} mins",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                widthFactor:
                                    (trackingState.getStatusStep(widget.reportId) + 1) /
                                    _statuses.length,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.redAccent,
                                        Colors.red[700]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.call,
                                          color: Colors.green[500],
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Call Rescuer",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.message,
                                          color: Colors.blue[500],
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Message",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}