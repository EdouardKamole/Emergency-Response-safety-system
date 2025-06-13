import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/screens/home_screen.dart';
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
import 'package:http/http.dart' as http;
import 'dart:convert';

// SosScreen: Stateful widget for emergency reporting
class SosScreen extends StatefulWidget {
  final int? selectedIndex;

  const SosScreen({Key? key, this.selectedIndex}) : super(key: key);

  @override
  _SosScreenState createState() => _SosScreenState();
}

// _SosScreenState: Manages state for SosScreen, animations, and data
class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  // State variables
  int selectedIndex = -1;
  String currentLocation = "Fetching location...";
  String notes = "";
  Position? _currentPosition;
  // Emergency type options with icons, labels, and colors
  List<Map<String, dynamic>> gridItems = [
    {
      'icon': Icons.medical_services_rounded,
      'label': 'Medical',
      'color': Colors.green,
    },
    {
      'icon': Icons.local_police_rounded,
      'label': 'Police',
      'color': Colors.blue,
    },
    {'icon': Icons.fire_truck_rounded, 'label': 'Fire', 'color': Colors.orange},
    {
      'icon': Icons.car_crash_rounded,
      'label': 'Accident',
      'color': Colors.purple,
    },
    {'icon': Icons.warning_rounded, 'label': 'Hazard', 'color': Colors.amber},
    {
      'icon': Icons.other_houses_rounded,
      'label': 'Other',
      'color': Colors.grey,
    },
    {'icon': Icons.sos_rounded, 'label': 'SOS', 'color': Colors.red},
  ];

  List<Map<String, dynamic>> mediaItems = [];
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Cloudinary configuration for media upload
  final String cloudName = 'dsojq0cm2';
  final String uploadPreset = 'ml_default';

  @override
  void initState() {
    super.initState();
    // Set initial selected index if provided
    if (widget.selectedIndex != null) {
      selectedIndex = widget.selectedIndex!;
    }

    // Request permissions if widget is mounted
    if (mounted) {
      _requestNecessaryPermissions();
    }

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    // Clean up animation controller
    _animationController.dispose();
    super.dispose();
  }

  // Request location and camera permissions
  Future<void> _requestNecessaryPermissions() async {
    if (!mounted) return;

    // Check and request location permission
    var locationStatus = await Permission.location.status;
    if (locationStatus.isDenied) {
      if (await Permission.location.request().isGranted) {
        await _getCurrentLocation();
      } else {
        setState(() {
          currentLocation = "Location permission denied";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please grant location permission",
              style: GoogleFonts.poppins(fontSize: 15.sp),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (locationStatus.isGranted) {
      await _getCurrentLocation();
    } else if (locationStatus.isPermanentlyDenied) {
      setState(() {
        currentLocation = "Location permission permanently denied";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please enable location in app settings",
            style: GoogleFonts.poppins(fontSize: 15.sp),
          ),
          backgroundColor: Colors.red,
        ),
      );
      await openAppSettings();
    }

    // Check and request camera permission
    var cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      if (await Permission.camera.request().isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Camera permission denied",
              style: GoogleFonts.poppins(fontSize: 15.sp),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (cameraStatus.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please enable camera in app settings",
            style: GoogleFonts.poppins(fontSize: 15.sp),
          ),
          backgroundColor: Colors.red,
        ),
      );
      await openAppSettings();
    }
  }

  // Fetch current location using Geolocator
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            currentLocation = "Location services are disabled";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Please enable location services",
                style: GoogleFonts.poppins(fontSize: 15.sp),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          currentLocation =
              "Lat: ${position.latitude}, Lon: ${position.longitude}";
        });
      }

      // Convert coordinates to address
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException("Geocoding timed out");
          },
        );

        if (placemarks.isNotEmpty && mounted) {
          Placemark place = placemarks[0];
          String address =
              [
                place.name ?? '',
                place.locality ?? '',
                place.administrativeArea ?? '',
                place.country ?? '',
              ].where((e) => e.isNotEmpty).join(", ").trim();
          setState(() {
            currentLocation =
                address.isNotEmpty
                    ? address
                    : "Address unavailable (${position.latitude}, ${position.longitude})";
          });
        } else {
          if (mounted) {
            setState(() {
              currentLocation =
                  "Address unavailable (${position.latitude}, ${position.longitude})";
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            currentLocation =
                "Address unavailable (${position.latitude}, ${position.longitude})";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Unable to get address: $e",
                style: GoogleFonts.poppins(fontSize: 15.sp),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentLocation = "Error fetching location: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Location error: $e",
              style: GoogleFonts.poppins(fontSize: 15.sp),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pick media (image or video) from camera or gallery
  Future<void> _pickMediaFromSource(
    ImageSource source, {
    bool isVideo = false,
  }) async {
    final picker = ImagePicker();
    const int maxMediaLimit = 4; // Maximum of 4 media items allowed

    // Check camera permission if source is camera
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (status.isDenied) {
        status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Camera permission is required.',
                  style: GoogleFonts.poppins(fontSize: 15.sp),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          print('Camera permission denied: $status');
          return;
        }
      }
    }

    try {
      print('Launching media picker for: $source, isVideo: $isVideo');
      List<XFile>? mediaFiles = [];

      if (source == ImageSource.gallery) {
        // Multi-media selection from gallery (images and videos)
        final List<XFile>? selectedMedia = await picker.pickMultipleMedia(
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );
        if (selectedMedia == null || selectedMedia.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No media selected',
                  style: GoogleFonts.poppins(fontSize: 15.sp),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          print('No media selected');
          return;
        }

        // Check if adding media exceeds limit
        if (mediaItems.length + selectedMedia.length > maxMediaLimit) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You can select up to $maxMediaLimit media items.',
                  style: GoogleFonts.poppins(fontSize: 15.sp),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          print(
            'Media limit exceeded: ${mediaItems.length + selectedMedia.length}',
          );
          return;
        }

        mediaFiles = selectedMedia;
      } else {
        // Single image or video from camera
        if (mediaItems.length >= maxMediaLimit) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You can select up to $maxMediaLimit media items.',
                  style: GoogleFonts.poppins(fontSize: 15.sp),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          print('Media limit exceeded: ${mediaItems.length + 1}');
          return;
        }

        XFile? media;
        if (isVideo) {
          media = await picker.pickVideo(source: source);
        } else {
          media = await picker.pickImage(
            source: source,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 80,
          );
        }

        if (media == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isVideo ? 'No video selected' : 'No image selected',
                  style: GoogleFonts.poppins(fontSize: 15.sp),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          print('No media selected');
          return;
        }

        mediaFiles = [media];
      }

      // Verify and add media files
      for (final media in mediaFiles) {
        File mediaFile = File(media.path);
        if (!await mediaFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Selected media file does not exist',
                  style: GoogleFonts.poppins(fontSize: 15.sp),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          print('Media file does not exist: ${media.path}');
          continue;
        }

        // Determine if the file is a video based on extension
        bool isVideoFile =
            media.path.toLowerCase().endsWith('.mp4') ||
            media.path.toLowerCase().endsWith('.mov') ||
            media.path.toLowerCase().endsWith('.avi');

        if (mounted) {
          setState(() {
            mediaItems.add({
              'file': mediaFile,
              'isVideo': isVideo || isVideoFile,
            });
          });
          print(
            'Media added: ${media.path}, isVideo: ${isVideo || isVideoFile}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking media: $e',
              style: GoogleFonts.poppins(fontSize: 15.sp),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error in _pickMediaFromSource: $e');
    }
  }

  // Remove media from list
  void _removeMedia(int index) {
    if (mounted && index >= 0 && index < mediaItems.length) {
      setState(() {
        mediaItems.removeAt(index);
      });
      print('Media removed at index: $index');
    }
  }

  // Show dialog to choose media source
  void _showMediaSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Select Media Source',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.blue,
                  size: 24.sp,
                ),
                title: Text(
                  'Camera',
                  style: GoogleFonts.poppins(fontSize: 16.sp),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickMediaFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.videocam_rounded,
                  color: Colors.red,
                  size: 24.sp,
                ),
                title: Text(
                  'Video',
                  style: GoogleFonts.poppins(fontSize: 16.sp),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickMediaFromSource(ImageSource.camera, isVideo: true);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Submit emergency report to Cloudinary and Firebase
  Future<void> _submitReport() async {
    // Validate emergency type
    if (selectedIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please select an emergency type",
            style: GoogleFonts.poppins(fontSize: 15.sp),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate location
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Location not available",
            style: GoogleFonts.poppins(fontSize: 15.sp),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate user authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "User not authenticated",
            style: GoogleFonts.poppins(fontSize: 15.sp),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Upload media to Cloudinary
      final mediaUrls = <String>[];
      for (final media in mediaItems) {
        final file = media['file'] as File;
        try {
          var request =
              http.MultipartRequest(
                  'POST',
                  Uri.parse(
                    'https://api.cloudinary.com/v1_1/$cloudName/upload',
                  ),
                )
                ..fields['upload_preset'] = uploadPreset
                ..files.add(
                  await http.MultipartFile.fromPath('file', file.path),
                );

          print('Uploading to Cloudinary: ${file.path}');
          var response = await request.send();
          var responseBody = await response.stream.bytesToString();
          var data = json.decode(responseBody);

          print(
            'Cloudinary response: status=${response.statusCode}, body=$responseBody',
          );

          if (response.statusCode == 200 && data['secure_url'] != null) {
            mediaUrls.add(data['secure_url']);
            print('Upload successful: ${data['secure_url']}');
          } else {
            print(
              'Cloudinary upload error: ${data['error']?['message'] ?? 'Unknown error'}',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to upload media: ${data['error']?['message'] ?? 'Unknown error'}',
                    style: GoogleFonts.poppins(fontSize: 15.sp),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } catch (e) {
          print('Cloudinary upload exception: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to upload media: $e',
                  style: GoogleFonts.poppins(fontSize: 15.sp),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
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
        'assignedRescuer': {},
      });
      print('Report saved to Realtime Database: ${reportRef.key}');

      // Save report to Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergencyReports')
          .doc(reportRef.key)
          .set({
            'reportType': gridItems[selectedIndex]['label'],
            'description': notes,
            'status': 'Pending',
            'createdAt': Timestamp.now(),
            'media': mediaUrls,
            'location': {
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
              'address': currentLocation,
            },
          }, SetOptions(merge: true));
      print('Report saved to Firestore: ${reportRef.key}');

      // Show success and navigate to TrackRescuerScreen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Emergency report submitted successfully",
              style: GoogleFonts.poppins(fontSize: 15.sp),
            ),
            backgroundColor: Colors.green,
          ),
        );

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
          SnackBar(
            content: Text(
              "Error submitting report: $e",
              style: GoogleFonts.poppins(fontSize: 15.sp),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error in _submitReport: $e');
    }
  }

  // Build the main UI
  @override
  Widget build(BuildContext context) {
    String selectedCategory =
        selectedIndex >= 0 && selectedIndex < gridItems.length
            ? gridItems[selectedIndex]['label']
            : "Not Selected";

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white, Colors.red.shade50],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and title
              SlideTransition(
                position: _slideAnimation,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomeScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              "Emergency Report",
                              style: GoogleFonts.poppins(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "Get help immediately",
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade200,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.emergency_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 16.h,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Emergency type selection
                          _buildSectionHeader(
                            title: "Emergency Type",
                            icon: Icons.category_rounded,
                          ),
                          SizedBox(height: 12.h),
                          SizedBox(height: 12.h),
                          // Selected emergency type display
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              gradient:
                                  selectedIndex >= 0
                                      ? LinearGradient(
                                        colors: [
                                          gridItems[selectedIndex]['color']
                                              .withOpacity(0.1),
                                          gridItems[selectedIndex]['color']
                                              .withOpacity(0.05),
                                        ],
                                      )
                                      : LinearGradient(
                                        colors: [
                                          Colors.grey.shade100,
                                          Colors.grey.shade50,
                                        ],
                                      ),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color:
                                    selectedIndex >= 0
                                        ? gridItems[selectedIndex]['color']
                                        : Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      selectedIndex >= 0
                                          ? gridItems[selectedIndex]['color']
                                              .withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color:
                                        selectedIndex >= 0
                                            ? gridItems[selectedIndex]['color']
                                            : Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(12.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            selectedIndex >= 0
                                                ? gridItems[selectedIndex]['color']
                                                    .withOpacity(0.3)
                                                : Colors.grey.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    selectedIndex >= 0 &&
                                            selectedIndex < gridItems.length
                                        ? gridItems[selectedIndex]['icon']
                                        : Icons.warning_rounded,
                                    size: 24.sp,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedCategory,
                                        style: GoogleFonts.poppins(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              selectedIndex >= 0
                                                  ? gridItems[selectedIndex]['color']
                                                  : Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        selectedIndex >= 0
                                            ? "Emergency type selected"
                                            : "Please select emergency type",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedIndex >= 0)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: gridItems[selectedIndex]['color'],
                                    size: 20.sp,
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 28.h),
                          // Location section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader(
                                title: "Current Location",
                                icon: Icons.location_on_rounded,
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade500,
                                      Colors.blue.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.shade200,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: GestureDetector(
                                  onTap: () => _showLocationDrawer(context),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 14.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        "Change",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade100.withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10.w),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.shade400,
                                        Colors.red.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Icon(
                                    Icons.my_location_rounded,
                                    size: 20.sp,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Your Location",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        currentLocation.length > 50
                                            ? '${currentLocation.substring(0, 50)}...'
                                            : currentLocation,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_currentPosition != null)
                                  Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Icon(
                                      Icons.gps_fixed_rounded,
                                      color: Colors.green.shade600,
                                      size: 16.sp,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 28.h),
                          // Media section
                          _buildSectionHeader(
                            title: "Evidence & Media",
                            icon: Icons.photo_camera_rounded,
                            isOptional: true,
                          ),
                          SizedBox(height: 12.h),
                          _buildPremiumMediaSection(),
                          SizedBox(height: 28.h),
                          // Notes section
                          _buildSectionHeader(
                            title: "Additional Details",
                            icon: Icons.notes_rounded,
                            isOptional: true,
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade100,
                                  blurRadius: 15,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextField(
                              onChanged: (value) {
                                setState(() {
                                  notes = value;
                                });
                              },
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText:
                                    "Describe the emergency situation in detail...",
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  color: Colors.grey.shade500,
                                ),
                                filled: false,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade500,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.all(16.w),
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          SizedBox(height: 32.h),
                          // Submit button
                          Container(
                            width: double.infinity,
                            height: 60.h,
                            decoration: BoxDecoration(
                              gradient:
                                  selectedIndex == -1
                                      ? LinearGradient(
                                        colors: [
                                          Colors.grey.shade300,
                                          Colors.grey.shade400,
                                        ],
                                      )
                                      : LinearGradient(
                                        colors: [
                                          Colors.red.shade500,
                                          Colors.red.shade700,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow:
                                  selectedIndex != -1
                                      ? [
                                        BoxShadow(
                                          color: Colors.red.shade300
                                              .withOpacity(0.5),
                                          blurRadius: 20,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                      : [],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16.r),
                                onTap:
                                    selectedIndex == -1 ? null : _submitReport,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                    vertical: 16.h,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.emergency,
                                        color: Colors.white,
                                        size: 24.sp,
                                      ),
                                      SizedBox(width: 12.w),
                                      Text(
                                        "Submit Emergency Report",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16.sp,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build section header widget
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    bool isOptional = false,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade500, Colors.blue.shade700],
            ),
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16.sp),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        if (isOptional) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Text(
              "Optional",
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Build media section
  Widget _buildPremiumMediaSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 20,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Media buttons
          Row(
            children: [
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera",
                  color: Colors.blue,
                  onTap: () => _pickMediaFromSource(ImageSource.camera),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.videocam_rounded,
                  label: "Video",
                  color: Colors.red,
                  onTap:
                      () => _pickMediaFromSource(
                        ImageSource.camera,
                        isVideo: true,
                      ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  color: Colors.green,
                  onTap: () => _pickMediaFromSource(ImageSource.gallery),
                ),
              ),
            ],
          ),
          // Display attached media
          if (mediaItems.isNotEmpty) ...[
            SizedBox(height: 20.h),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.attachment_rounded,
                      color: Colors.blue.shade600,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Attached Media (${mediaItems.length})",
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 1,
                  ),
                  itemCount:
                      mediaItems.length < 4
                          ? mediaItems.length + 1
                          : mediaItems.length,
                  itemBuilder: (context, index) {
                    if (index == mediaItems.length && mediaItems.length < 4) {
                      return _buildAddMediaButton();
                    }
                    if (index < mediaItems.length) {
                      return _buildMediaPreview(index);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ] else ...[
            // Empty media state
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(50.r),
                    ),
                    child: Icon(
                      Icons.cloud_upload_rounded,
                      size: 32.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "No media attached",
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Add photos or videos to help emergency responders understand the situation better",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Build media button widget
  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24.sp),
                SizedBox(height: 8.h),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build add media button widget
  Widget _buildAddMediaButton() {
    return GestureDetector(
      onTap: _showMediaSourceDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.add_circle_outline_rounded,
            color: Colors.grey.shade600,
            size: 32.sp,
          ),
        ),
      ),
    );
  }

  // Build media preview widget
  Widget _buildMediaPreview(int index) {
    if (index < 0 || index >= mediaItems.length) {
      return const SizedBox.shrink();
    }
    final media = mediaItems[index];
    final file = media['file'] as File;
    final isVideo = media['isVideo'] as bool;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isVideo
                          ? [Colors.red.shade300, Colors.red.shade500]
                          : [Colors.blue.shade300, Colors.blue.shade500],
                ),
              ),
              child:
                  isVideo
                      ? Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 32.sp,
                      )
                      : Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade400,
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.grey.shade500,
                              size: 24.sp,
                            ),
                          );
                        },
                      ),
            ),
          ),
          Positioned(
            top: 6.h,
            left: 6.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                    color: Colors.white,
                    size: 10.sp,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    isVideo ? "VID" : "IMG",
                    style: GoogleFonts.poppins(
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 6.h,
            right: 6.w,
            child: GestureDetector(
              onTap: () => _removeMedia(index),
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade200,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 12.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show location settings drawer
  void _showLocationDrawer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (BuildContext context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.r),
                topRight: Radius.circular(24.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 12.h),
                  width: 50.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(20.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade500,
                              Colors.blue.shade300,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location Settings',
                              style: GoogleFonts.poppins(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Manage your emergency location',
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.grey.shade600,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.my_location_rounded,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Current Location',
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        currentLocation,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    children: [
                      _buildLocationActionButton(
                        icon: Icons.refresh_rounded,
                        title: 'Refresh Location',
                        subtitle: 'Get current GPS coordinates',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _getCurrentLocation();
                        },
                      ),
                      SizedBox(height: 16.h),
                      _buildLocationActionButton(
                        icon: Icons.settings_rounded,
                        title: 'Location Settings',
                        subtitle: 'Open device settings',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue.shade600,
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'For emergency response, we use high-accuracy GPS to ensure rescuers can find you quickly.',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.blue.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Build location action button widget
  Widget _buildLocationActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.8), color],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400,
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
