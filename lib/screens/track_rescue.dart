import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  final _rescuerLocation = ValueNotifier<latlong.LatLng?>(null);
  final _etaSeconds = ValueNotifier<int>(300);
  final _statusStep = ValueNotifier<int>(0);
  final _routePoints = ValueNotifier<List<latlong.LatLng>>([]);
  final _isRescuerAssigned = ValueNotifier<bool>(false);
  late AnimationController _pulseController;
  late AnimationController _routeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _routeAnimation;
  late StreamSubscription<DatabaseEvent> _rescuerSubscription;
  StreamSubscription<Position>? _victimLocationSubscription;
  final MapController _mapController = MapController();
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastRouteFetch;
  bool _hasUserInteractedWithMap = false;
  bool _autoRecenter = true;
  double _lastZoom = 13.0;
  double? _distanceToRescuer;
  String? _rescuerPhoneNumber;
  static const String _orsApiKey =
      '5b3ce3597851110001cf624862ba9d9ce4314f088c7a3b8fec0f957e';

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
    _rescuerLocation.value = latlong.LatLng(
      widget.emergencyLat + 0.01,
      widget.emergencyLon + 0.01,
    );

    _checkLocationPermissions();
    _startVictimLocationUpdates();
    _fetchInitialRescuerData();
    _listenToRescuerUpdates();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _routeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _routeController, curve: Curves.easeInOut),
    );
    _routeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _recenterMap());

    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || _mapController.camera.zoom != _lastZoom) {
        _hasUserInteractedWithMap = true;
        _lastZoom = _mapController.camera.zoom;
      }
    });
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        setState(() => _errorMessage = "Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          setState(() => _errorMessage = "Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        setState(
          () => _errorMessage = "Location permissions are permanently denied.",
        );
      return;
    }
  }

  void _startVictimLocationUpdates() {
    _victimLocationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) async {
        if (!mounted) return;
        setState(() {
          _emergencyLocation = latlong.LatLng(
            position.latitude,
            position.longitude,
          );
          _updateDistanceToRescuer();
        });

        final database = FirebaseDatabase.instance.ref();
        final updateData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        };

        int retries = 3;
        while (retries > 0) {
          try {
            await database
                .child('reports/${widget.reportId}/location')
                .set(updateData);
            if (!_hasUserInteractedWithMap && _autoRecenter) {
              _fetchRoutePoints();
              _recenterMap();
            }
            debugPrint(
              'Victim location updated: (${position.latitude}, ${position.longitude})',
            );
            break;
          } catch (e) {
            retries--;
            if (retries == 0 && mounted) {
              setState(
                () => _errorMessage = "Error updating victim location: $e",
              );
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      },
      onError: (e) {
        if (mounted)
          setState(() => _errorMessage = "Error fetching victim location: $e");
      },
    );
  }

  void _updateDistanceToRescuer() {
    final rescuerLoc = _rescuerLocation.value;
    if (rescuerLoc != null) {
      _distanceToRescuer = Geolocator.distanceBetween(
        _emergencyLocation.latitude,
        _emergencyLocation.longitude,
        rescuerLoc.latitude,
        rescuerLoc.longitude,
      );
    }
  }

  Future<void> _fetchInitialRescuerData() async {
    try {
      final database = FirebaseDatabase.instance.ref();
      final snapshot =
          await database
              .child('reports/${widget.reportId}/assignedRescuer')
              .get();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null && data.isNotEmpty) {
          _isRescuerAssigned.value = true;
          final rescuerId = data.keys.first;
          final rescuerData = Map<String, dynamic>.from(data[rescuerId]);
          final double? latitude = rescuerData['latitude']?.toDouble();
          final double? longitude = rescuerData['longitude']?.toDouble();
          final int? eta = rescuerData['eta']?.toInt();
          final String? status = rescuerData['status']?.toString();
          _rescuerPhoneNumber = rescuerData['phoneNumber']?.toString();

          if (latitude != null && longitude != null) {
            _rescuerLocation.value = latlong.LatLng(latitude, longitude);
            _etaSeconds.value = eta ?? 300;
            _statusStep.value = status == 'arrived' ? 1 : 0;
            _fetchRoutePoints();
            _updateDistanceToRescuer();
          } else {
            _errorMessage = "Invalid rescuer location data";
          }
        } else {
          _isRescuerAssigned.value = false;
          _errorMessage = "Waiting for rescuer to be assigned";
        }
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _isRescuerAssigned.value = false;
          _errorMessage = "Error fetching initial rescuer data: $e";
        });
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
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null && data.isNotEmpty) {
                _isRescuerAssigned.value = true;
                final rescuerId = data.keys.first;
                final rescuerData = Map<String, dynamic>.from(data[rescuerId]);
                final double? latitude = rescuerData['latitude']?.toDouble();
                final double? longitude = rescuerData['longitude']?.toDouble();
                final int? eta = rescuerData['eta']?.toInt();
                final String? status = rescuerData['status']?.toString();
                _rescuerPhoneNumber = rescuerData['phoneNumber']?.toString();

                if (latitude != null && longitude != null) {
                  _rescuerLocation.value = latlong.LatLng(latitude, longitude);
                  _etaSeconds.value = eta ?? _etaSeconds.value;
                  _updateDistanceToRescuer();

                  double distance = _distanceToRescuer ?? 0;
                  int newStatusStep = _statusStep.value;
                  if (distance < 100 && newStatusStep == 0) {
                    newStatusStep = 1; // At Scene
                  } else if (newStatusStep == 1 && distance > 100) {
                    newStatusStep = 2; // Transporting Patient
                  } else if (newStatusStep == 2 && distance > 1000) {
                    newStatusStep = 3; // Arrived at Hospital
                  } else if (status == 'arrived' && newStatusStep < 1) {
                    newStatusStep = 1;
                  }
                  _statusStep.value = newStatusStep;

                  if (!_hasUserInteractedWithMap && _autoRecenter) {
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
                _isRescuerAssigned.value = false;
                _errorMessage = "Waiting for rescuer to be assigned";
              }
            });
          },
          onError: (error) {
            if (mounted)
              setState(() {
                _isLoading = false;
                _isRescuerAssigned.value = false;
                _errorMessage = "Error fetching rescuer data: $error";
              });
          },
        );
  }

  Future<void> _fetchRoutePoints() async {
    if (_lastRouteFetch != null &&
        DateTime.now().difference(_lastRouteFetch!).inSeconds < 15) {
      return;
    }
    _lastRouteFetch = DateTime.now();

    final rescuerLoc = _rescuerLocation.value;
    if (rescuerLoc == null || !_isRescuerAssigned.value) {
      _routePoints.value = [];
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=${rescuerLoc.longitude},${rescuerLoc.latitude}&end=${_emergencyLocation.longitude},${_emergencyLocation.latitude}',
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
        _routePoints.value = newRoutePoints;
      } else {
        _routePoints.value = [rescuerLoc, _emergencyLocation];
        if (mounted)
          setState(
            () => _errorMessage = "Failed to fetch route, using direct path",
          );
      }
    } catch (e) {
      _routePoints.value = [rescuerLoc, _emergencyLocation];
      if (mounted)
        setState(
          () => _errorMessage = "Error fetching route, using direct path",
        );
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
            width: size.w,
            height: size.h,
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
            child: Icon(icon, color: color, size: size.w * 0.6),
          ),
        );
      },
    );
  }

  void _recenterMap() {
    final rescuerLoc = _rescuerLocation.value;
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

  Future<void> _callRescuer() async {
    if (_rescuerPhoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rescuer phone number not available")),
      );
      return;
    }
    // Note: Requires url_launcher package. Comment out if not added.
    // final Uri uri = Uri(scheme: 'tel', path: _rescuerPhoneNumber);
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri);
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text("Unable to make call")),
    //   );
    // }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Call feature requires url_launcher package")),
    );
  }

  @override
  void dispose() {
    _rescuerSubscription.cancel();
    _victimLocationSubscription?.cancel();
    _pulseController.dispose();
    _routeController.dispose();
    _rescuerLocation.dispose();
    _etaSeconds.dispose();
    _statusStep.dispose();
    _routePoints.dispose();
    _isRescuerAssigned.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
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
                  ValueListenableBuilder<List<latlong.LatLng>>(
                    valueListenable: _routePoints,
                    builder: (context, routePoints, _) {
                      return AnimatedBuilder(
                        animation: _routeAnimation,
                        builder: (context, child) {
                          int visiblePoints =
                              (routePoints.length * _routeAnimation.value)
                                  .round();
                          List<latlong.LatLng> visibleRoute =
                              routePoints.take(visiblePoints).toList();
                          return PolylineLayer(
                            polylines: [
                              if (visibleRoute.length >= 2 &&
                                  _isRescuerAssigned.value)
                                Polyline(
                                  points: visibleRoute,
                                  color: Colors.redAccent.withOpacity(0.8),
                                  strokeWidth: 4.0,
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<latlong.LatLng?>(
                    valueListenable: _rescuerLocation,
                    builder: (context, rescuerLoc, _) {
                      return MarkerLayer(
                        markers: [
                          Marker(
                            width: 50.w,
                            height: 50.h,
                            point: _emergencyLocation,
                            child: _buildCustomMarker(
                              icon: Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 50,
                              isPulsing: true,
                            ),
                          ),
                          if (rescuerLoc != null && _isRescuerAssigned.value)
                            Marker(
                              width: 45.w,
                              height: 45.h,
                              point: rescuerLoc,
                              child: ValueListenableBuilder<int>(
                                valueListenable: _statusStep,
                                builder: (_, statusStep, __) {
                                  return _buildCustomMarker(
                                    icon: Icons.local_hospital,
                                    color: _statuses[statusStep]["color"],
                                    size: 45,
                                    isPulsing: false,
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 150.h,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10.h,
                left: 20.w,
                right: 20.w,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
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
                    SizedBox(width: 15.w),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 16.w,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(25.r),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          "Track Rescuer",
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(width: 15.w),
                    GestureDetector(
                      onTap:
                          () => setState(() => _autoRecenter = !_autoRecenter),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color:
                              _autoRecenter
                                  ? Colors.blue.withOpacity(0.9)
                                  : Colors.grey.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.center_focus_strong,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20.w,
                bottom: 230.h,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "recenter",
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: _recenterMap,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    FloatingActionButton(
                      heroTag: "zoomIn",
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed:
                          () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          ),
                      child: const Icon(Icons.add, color: Colors.black),
                    ),
                    SizedBox(height: 10.h),
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed:
                          () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          ),
                      child: const Icon(Icons.remove, color: Colors.black),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 30.h,
                left: 20.w,
                right: 20.w,
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ValueListenableBuilder<bool>(
                          valueListenable: _isRescuerAssigned,
                          builder: (context, isRescuerAssigned, _) {
                            return _errorMessage != null && !isRescuerAssigned
                                ? Container(
                                  padding: EdgeInsets.all(20.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20.r),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      color:
                                          _errorMessage ==
                                                  "Waiting for rescuer to be assigned"
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                                : Container(
                                  padding: EdgeInsets.all(20.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20.r),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ValueListenableBuilder<int>(
                                        valueListenable: _statusStep,
                                        builder: (context, statusStep, _) {
                                          return Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(12.w),
                                                decoration: BoxDecoration(
                                                  color:
                                                      _statuses[statusStep]["color"]
                                                          .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                ),
                                                child: Icon(
                                                  _statuses[statusStep]["icon"],
                                                  color:
                                                      _statuses[statusStep]["color"],
                                                  size: 24.sp,
                                                ),
                                              ),
                                              SizedBox(width: 15.w),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _statuses[statusStep]["text"],
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 18.sp,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade800,
                                                          ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                    Text(
                                                      "Rescuer Unit #${FirebaseAuth.instance.currentUser?.uid.substring(0, 6) ?? 'RES-001'}",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14.sp,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                    ),
                                                    if (_distanceToRescuer !=
                                                        null)
                                                      Text(
                                                        "Distance: ${(_distanceToRescuer! / 1000).toStringAsFixed(1)} km",
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 14.sp,
                                                              color:
                                                                  Colors
                                                                      .grey
                                                                      .shade600,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              ValueListenableBuilder<int>(
                                                valueListenable: _etaSeconds,
                                                builder: (context, eta, _) {
                                                  return Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 8.h,
                                                          horizontal: 16.w,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.redAccent,
                                                          Colors.red.shade700,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20.r,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      "ETA: ${(eta ~/ 60).clamp(1, 15)} min",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14.sp,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      SizedBox(height: 15.h),
                                      ValueListenableBuilder<int>(
                                        valueListenable: _statusStep,
                                        builder: (context, statusStep, _) {
                                          return Container(
                                            height: 6.h,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(3.r),
                                            ),
                                            child: FractionallySizedBox(
                                              widthFactor:
                                                  (statusStep + 1) /
                                                  _statuses.length,
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.redAccent,
                                                      Colors.red.shade700,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        3.r,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      SizedBox(height: 10.h),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: _callRescuer,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 12.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  border: Border.all(
                                                    color:
                                                        Colors.green.shade300,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.call,
                                                      color:
                                                          Colors.green.shade700,
                                                      size: 20.sp,
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Text(
                                                      "Call Rescuer",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14.sp,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                Colors
                                                                    .green
                                                                    .shade700,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      "Messaging not implemented",
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 12.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.blue.shade300,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.message,
                                                      color:
                                                          Colors.blue.shade700,
                                                      size: 20.sp,
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Text(
                                                      "Message",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14.sp,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                Colors
                                                                    .blue
                                                                    .shade700,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
