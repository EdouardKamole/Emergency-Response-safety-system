import 'dart:async';
import 'dart:io';
import 'package:emergency_app/screens/track_rescue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SosScreen extends StatefulWidget {
  final int? selectedIndex;

  const SosScreen({Key? key, this.selectedIndex}) : super(key: key);

  @override
  _SosScreenState createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  int selectedIndex = -1;
  String currentLocation = "Fetching Location...";
  String notes = "";
  Position? _currentPosition;
  List<Map<String, dynamic>> gridItems = [
    {'icon': Icons.medical_services, 'label': 'Medical'},
    {'icon': Icons.local_police, 'label': 'Police'},
    {'icon': Icons.fire_truck, 'label': 'Fire'},
    {'icon': Icons.car_crash, 'label': 'Accident'},
    {'icon': Icons.warning, 'label': 'Hazard'},
    {'icon': Icons.other_houses, 'label': 'Other'},
    {'icon': Icons.sos, 'label': 'SOS'},
  ];

  List<Map<String, dynamic>> mediaItems = [];
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.selectedIndex != null) {
      selectedIndex = widget.selectedIndex!;
    }
    _requestLocationPermission();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      if (await Permission.location.request().isGranted) {
        _getCurrentLocation();
      } else {
        if (mounted) {
          setState(() {
            currentLocation = "Location permission denied";
          });
        }
      }
    } else if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          currentLocation = "Location permission permanently denied";
        });
      }
      openAppSettings();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            currentLocation =
                "${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            currentLocation = "No address found for these coordinates";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentLocation = "Error fetching location: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final ImagePicker picker = ImagePicker();

    if (source == ImageSource.camera) {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Camera permission denied")),
            );
          }
          return;
        }
      }
    } else {
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Storage permission denied")),
            );
          }
          return;
        }
      }
    }

    try {
      if (source == ImageSource.camera) {
        if (isVideo) {
          final XFile? video = await picker.pickVideo(source: source);
          if (video != null && mounted) {
            setState(() {
              mediaItems.add({'file': File(video.path), 'isVideo': true});
            });
          }
        } else {
          final XFile? image = await picker.pickImage(source: source);
          if (image != null && mounted) {
            setState(() {
              mediaItems.add({'file': File(image.path), 'isVideo': false});
            });
          }
        }
      } else {
        try {
          final List<XFile> media = await picker.pickMultipleMedia();
          if (media.isNotEmpty && mounted) {
            setState(() {
              for (var item in media) {
                mediaItems.add({
                  'file': File(item.path),
                  'isVideo': item.mimeType?.contains('video') ?? false,
                });
              }
            });
          }
        } catch (e) {
          final XFile? image = await picker.pickImage(source: source);
          if (image != null && mounted) {
            setState(() {
              mediaItems.add({'file': File(image.path), 'isVideo': false});
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking media: ${e.toString()}")),
        );
      }
    }
  }

  void _removeMedia(int index) {
    if (mounted) {
      setState(() {
        mediaItems.removeAt(index);
      });
    }
  }

  Future<void> _submitReport() async {
    if (selectedIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an emergency type")),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Location not available")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not authenticated")));
      return;
    }

    try {
      // Upload media to Firebase Storage
      final storage = FirebaseStorage.instance;
      final mediaUrls = <String>[];
      for (final media in mediaItems) {
        final file = media['file'] as File;
        final storageRef = storage.ref().child(
          'reports/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}',
        );
        await storageRef.putFile(file);
        final url = await storageRef.getDownloadURL();
        mediaUrls.add(url);
      }

      // Save report to Realtime Database
      final database = FirebaseDatabase.instance.ref();
      final reportRef = database.child('reports').push();
      await reportRef.set({
        'reportedBy': user.uid,
        'location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'media': mediaUrls,
        'status': 'reported',
        'type': gridItems[selectedIndex]['label'],
        'notes': notes,
        'assignedRescuer': {}, // Initially empty
      });

      // Insert fake rescuer data
      const fakeRescuerId = 'fake_rescuer_001';
      // Start rescuer slightly offset from emergency location (e.g., 0.01 degrees ~ 1km)
      final fakeRescuerLocation = {
        'latitude': _currentPosition!.latitude + 0.01,
        'longitude': _currentPosition!.longitude + 0.01,
        'timestamp': DateTime.now().toIso8601String(),
        'eta': 300, // Fake ETA: 5 minutes in seconds
      };

      // Add fake rescuer to assignedRescuer
      await reportRef
          .child('assignedRescuer/$fakeRescuerId')
          .set(fakeRescuerLocation);

      // Add fake rescuer to activeRescuers
      await database.child('activeRescuers/$fakeRescuerId').set({
        'latitude': fakeRescuerLocation['latitude'],
        'longitude': fakeRescuerLocation['longitude'],
        'timestamp': fakeRescuerLocation['timestamp'],
        'status': 'en_route',
      });

      // Start simulating rescuer movement
      _simulateRescuerUpdates(
        reportId: reportRef.key!,
        rescuerId: fakeRescuerId,
        emergencyLat: _currentPosition!.latitude,
        emergencyLon: _currentPosition!.longitude,
      );

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Emergency report submitted successfully"),
          ),
        );

        // Navigate to TrackRescuerScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => TrackRescuerScreen(
                  reportId: reportRef.key!,
                  emergencyLat: _currentPosition!.latitude,
                  emergencyLon: _currentPosition!.longitude,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting report: ${e.toString()}")),
        );
      }
    }
  }

  // Simulate rescuer moving toward the emergency location
  void _simulateRescuerUpdates({
    required String reportId,
    required String rescuerId,
    required double emergencyLat,
    required double emergencyLon,
  }) {
    double currentLat = emergencyLat + 0.01; // Starting position
    double currentLon = emergencyLon + 0.01;
    const step = 0.001; // Move 0.001 degrees (~100m) per update
    const interval = Duration(seconds: 5); // Update every 5 seconds

    Timer.periodic(interval, (timer) async {
      // Calculate distance to emergency
      double distance = Geolocator.distanceBetween(
        currentLat,
        currentLon,
        emergencyLat,
        emergencyLon,
      );

      // Stop if close to emergency (within 100 meters)
      if (distance < 100) {
        timer.cancel();
        return;
      }

      // Move toward emergency
      if (currentLat > emergencyLat) {
        currentLat -= step;
      } else if (currentLat < emergencyLat) {
        currentLat += step;
      }
      if (currentLon > emergencyLon) {
        currentLon -= step;
      } else if (currentLon < emergencyLon) {
        currentLon += step;
      }

      // Calculate fake ETA based on distance (assuming 10 meters/second speed)
      int etaSeconds = (distance / 10).round();

      final database = FirebaseDatabase.instance.ref();
      final updateData = {
        'latitude': currentLat,
        'longitude': currentLon,
        'timestamp': DateTime.now().toIso8601String(),
        'eta': etaSeconds,
      };

      // Update assignedRescuer
      await database
          .child('reports/$reportId/assignedRescuer/$rescuerId')
          .update(updateData);

      // Update activeRescuers
      await database.child('activeRescuers/$rescuerId').update({
        ...updateData,
        'status': 'en_route',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String selectedCategory =
        selectedIndex >= 0 && selectedIndex < gridItems.length
            ? gridItems[selectedIndex]['label']
            : "Not Selected";

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          "Report Emergency",
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
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Emergency Type",
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedIndex >= 0 && selectedIndex < gridItems.length
                            ? gridItems[selectedIndex]['icon']
                            : Icons.warning,
                        size: 24.sp,
                        color: Colors.red.shade500,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        selectedCategory,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Location",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _showLocationDrawer(context);
                      },
                      child: Text(
                        "Change",
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.red.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_pin,
                        size: 20.sp,
                        color: Colors.red.shade500,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          currentLocation.length > 50
                              ? '${currentLocation.substring(0, 50)}...'
                              : currentLocation,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Text(
                      "Upload Media",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      "(optional)",
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildMediaSection(),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Text(
                      "Additional Notes",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      "(optional)",
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      notes = value;
                    });
                  },
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Enter any additional details here...",
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: Colors.red.shade500),
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedIndex == -1 ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      backgroundColor: Colors.red.shade500,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 16.h,
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      "Submit Report",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                "Add Media",
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  title: Text(
                    "Take with Camera",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20.r),
                        ),
                      ),
                      backgroundColor: Colors.transparent,
                      builder: (BuildContext context) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, Colors.grey.shade50],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20.r),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40.w,
                                height: 5.h,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              SizedBox(height: 20.h),
                              Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.shade400,
                                          Colors.red.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 24.sp,
                                    ),
                                  ),
                                  title: Text(
                                    "Take Photo",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    _pickMedia(ImageSource.camera);
                                  },
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.shade400,
                                          Colors.red.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.videocam,
                                      color: Colors.white,
                                      size: 24.sp,
                                    ),
                                  ),
                                  title: Text(
                                    "Record Video",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    _pickMedia(
                                      ImageSource.camera,
                                      isVideo: true,
                                    );
                                  },
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey.shade400,
                                          Colors.grey.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.cancel,
                                      color: Colors.white,
                                      size: 24.sp,
                                    ),
                                  ),
                                  title: Text(
                                    "Cancel",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                              SizedBox(height: 16.h),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  title: Text(
                    "Pick from Gallery",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.gallery);
                  },
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey.shade400, Colors.grey.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cancel, color: Colors.white, size: 24.sp),
                  ),
                  title: Text(
                    "Cancel",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade200.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(int index) {
    File file = mediaItems[index]['file'];
    bool isVideo = mediaItems[index]['isVideo'];

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          height: 100.h,
          width: 100.w,
          margin: EdgeInsets.only(right: 12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child:
                isVideo
                    ? Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: Icon(
                          Icons.videocam,
                          size: 40.sp,
                          color: Colors.white,
                        ),
                      ),
                    )
                    : Image.file(file, fit: BoxFit.cover),
          ),
        ),
        GestureDetector(
          onTap: () => _removeMedia(index),
          child: Container(
            margin: EdgeInsets.all(5.w),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.red.shade500,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.close, size: 16.sp, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mediaItems.isNotEmpty)
            SizedBox(
              height: 100.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mediaItems.length,
                itemBuilder: (context, index) {
                  return _buildMediaThumbnail(index);
                },
              ),
            ),
          if (mediaItems.isNotEmpty) SizedBox(height: 12.h),
          _buildMediaButton(
            icon: Icons.add_a_photo,
            text: mediaItems.isEmpty ? "Add Media" : "Add More",
            onPressed: _showMediaOptions,
          ),
        ],
      ),
    );
  }

  void _showLocationDrawer(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: ListView(
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  "Select Location",
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.gps_fixed,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  title: Text(
                    "Use Current GPS Location",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _requestLocationPermission();
                  },
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.search, color: Colors.white, size: 24.sp),
                  ),
                  title: Text(
                    "Type Location",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showLocationInputDialog(context);
                  },
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  void _showLocationInputDialog(BuildContext context) {
    String typedLocation = "";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          backgroundColor: Colors.white,
          title: Text(
            "Enter Location",
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: TextField(
            onChanged: (value) {
              typedLocation = value;
            },
            decoration: InputDecoration(
              hintText: "Type location here",
              hintStyle: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.red.shade500),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(
                "OK",
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade500,
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                if (typedLocation.isNotEmpty) {
                  try {
                    List<Location> locations = await locationFromAddress(
                      typedLocation,
                    );
                    if (locations.isNotEmpty && mounted) {
                      setState(() {
                        _currentPosition = Position(
                          latitude: locations[0].latitude,
                          longitude: locations[0].longitude,
                          timestamp: DateTime.now(),
                          accuracy: 0,
                          altitude: 0,
                          heading: 0,
                          speed: 0,
                          speedAccuracy: 0,
                          altitudeAccuracy: 0,
                          headingAccuracy: 0,
                        );
                        currentLocation = typedLocation;
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Error finding location: ${e.toString()}",
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
