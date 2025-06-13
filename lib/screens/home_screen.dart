import 'dart:async';
import 'package:emergency_app/screens/history_screen.dart';
import 'package:emergency_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emergency_app/screens/track_rescue.dart';
import 'package:emergency_app/screens/sos_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int selectedIndex = 0;
  Map<String, dynamic>? latestReport;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  String userName = "";
  bool isEmergencyActive = false;
  String currentLocation = "Fetching location...";
  Position? _currentPosition;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _fetchLatestReport();
    _fetchUserData();
    _requestLocationPermission();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          userName = "Guest";
          _isLoadingUserData = false;
        });
        _showSnackBar("User not authenticated", isError: true);
      }
      print('Error: User not authenticated');
      return;
    }

    setState(() => _isLoadingUserData = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (mounted && doc.exists) {
        final userData = doc.data();
        setState(() {
          userName = userData?['fullName'] ?? user.email ?? "Guest";
          _isLoadingUserData = false;
        });
      } else {
        if (mounted) {
          setState(() {
            userName = user.email ?? "Guest";
            _isLoadingUserData = false;
          });
          _showSnackBar("No user data found", isError: false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          userName = user.email ?? "Guest";
          _isLoadingUserData = false;
        });
        _showSnackBar("Error fetching user data: $e", isError: true);
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      if (await Permission.location.request().isGranted) {
        await _getCurrentLocation();
      } else {
        if (mounted) {
          setState(() {
            currentLocation = "Location permission denied";
          });
          _showSnackBar("Please grant location permission", isError: true);
        }
        print('Location permission denied');
      }
    } else if (status.isGranted) {
      await _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          currentLocation = "Location permission permanently denied";
        });
        _showSnackBar("Please enable location in app settings", isError: true);
      }
      print('Location permission permanently denied');
      await openAppSettings();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            currentLocation = "Location services are disabled";
          });
          _showSnackBar("Please enable location services", isError: true);
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _currentPosition = position;
          currentLocation =
              "Lat: ${position.latitude}, Lon: ${position.longitude}";
        });
      }

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException("Geocoding timed out"),
        );

        if (placemarks.isNotEmpty && mounted) {
          Placemark place = placemarks[0];
          String address =
              "${place.name ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}"
                  .trim()
                  .replaceAll(RegExp(r',\s*,'), ',')
                  .replaceAll(RegExp(r'^\s*,'), '')
                  .replaceAll(RegExp(r',\s*$'), '');
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
                  "No address found (${position.latitude}, ${position.longitude})";
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            currentLocation =
                "No address found (${position.latitude}, ${position.longitude})";
          });
          _showSnackBar("Unable to get address: $e", isError: true);
        }
        print('Geocoding error: $e');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentLocation = "Error fetching location: $e";
        });
        _showSnackBar("Location error: $e", isError: true);
      }
      print('Error fetching location: $e');
    }
  }

  Future<void> _fetchLatestReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final database = FirebaseDatabase.instance.ref('reports');
      final snapshot =
          await database
              .orderByChild('reportedBy')
              .equalTo(user.uid)
              .limitToLast(1)
              .get();

      if (snapshot.exists && mounted) {
        final reports = snapshot.value as Map<dynamic, dynamic>;
        final reportId = reports.keys.first;
        final reportData = Map<String, dynamic>.from(reports[reportId]);

        setState(() {
          latestReport = {
            'reportId': reportId,
            'emergencyLat': reportData['location']['latitude'] as double,
            'emergencyLon': reportData['location']['longitude'] as double,
            'status': reportData['status'] ?? 'pending',
            'timestamp': reportData['timestamp'],
          };
          isEmergencyActive =
              reportData['status'] == 'active' ||
              reportData['status'] == 'dispatched';
        });
        print('Latest report loaded: $reportId');
      } else {
        if (mounted) {
          setState(() {
            latestReport = null;
            isEmergencyActive = false;
          });
        }
        print('No reports found');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          latestReport = null;
          isEmergencyActive = false;
        });
        _showSnackBar("Error fetching report: $e", isError: true);
      }
      print('Error in _fetchLatestReport: $e');
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14.sp)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
    print('SnackBar: $message (isError: $isError)');
  }

  Future<void> _onRefresh() async {
    try {
      await Future.wait([
        _fetchUserData(),
        _fetchLatestReport(),
        _getCurrentLocation(),
      ]);
      if (mounted) {
        _showSnackBar("Data refreshed successfully", isError: false);
      }
      print('Refresh completed');
    } catch (e) {
      if (mounted) {
        _showSnackBar("Failed to refresh data: $e", isError: true);
      }
      print('Error during refresh: $e');
    }
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  List<Widget> get widgetOptions {
    return [
      _buildEnhancedDashboard(),
      latestReport != null
          ? TrackRescuerScreen(
            reportId: latestReport!['reportId'] as String,
            emergencyLat: latestReport!['emergencyLat'] as double,
            emergencyLon: latestReport!['emergencyLon'] as double,
          )
          : _buildNoActiveReport(),
      HistoryScreen(),
      ProfileScreen(),
    ];
  }

  Widget _buildEnhancedDashboard() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF001970)],
        ),
      ),
      child: RefreshIndicator(
        color: Colors.white,
        backgroundColor: const Color(0xFF1565C0),
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildEnhancedHeader(),
              _buildEmergencyStatus(),
              _buildQuickActions(),
              SizedBox(height: 20.h),
              _buildServiceCategories(),
              _buildRecentActivity(),
              SizedBox(height: 100.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
      ),
      child: Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome back,",
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    _isLoadingUserData
                        ? Text(
                          "Loading...",
                          style: GoogleFonts.poppins(
                            fontSize: 24.sp,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : Text(
                          userName.isEmpty ? "Guest" : userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 24.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50.r),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 20.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your Location",
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          currentLocation.length > 30
                              ? '${currentLocation.substring(0, 30)}...'
                              : currentLocation,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
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

  Widget _buildEmergencyStatus() {
    if (!isEmergencyActive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(
                  0.3 + (0.2 * _pulseController.value),
                ),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_hospital,
                  color: Colors.red,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Emergency Active",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Help is on the way",
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16.sp),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.emergency,
                  title: "Emergency",
                  subtitle: "Call Now",
                  color: Colors.red,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.local_hospital,
                  title: "Ambulance",
                  subtitle: "Request",
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    int getIndexForTitle(String title) {
      switch (title) {
        case "Emergency":
          return 0;
        case "Ambulance":
          return 3;
        default:
          return 6;
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SosScreen(selectedIndex: getIndexForTitle(title)),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10.r,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCategories() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Emergency Services",
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              color: const Color(0xFF1565C0),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.2,
            children: [
              _buildServiceCard(
                icon: Icons.local_hospital,
                title: "Health Care",
                color: const Color(0xFF4CAF50),
              ),
              _buildServiceCard(
                icon: Icons.local_fire_department,
                title: "Fire & Safety",
                color: const Color(0xFFFF7777),
              ),
              _buildServiceCard(
                icon: Icons.security,
                title: "Police",
                color: const Color(0xFF2196F3),
              ),
              _buildServiceCard(
                icon: Icons.medication,
                title: "Accident",
                color: const Color(0xFF9C27B0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    Map<String, int> titleToIndex = {
      'Health Care': 0,
      'Fire & Safety': 2,
      'Police': 1,
      'Accident': 3,
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SosScreen(selectedIndex: titleToIndex[title] ?? 6),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
          ),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50.r),
              ),
              child: Icon(icon, color: Colors.black54, size: 22.sp),
            ),
            SizedBox(height: 6.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 5.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Activity",
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  color: const Color(0xFF1565C0),
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: () => onItemTapped(2),
                child: Text(
                  "View All",
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          latestReport == null
              ? Center(
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text(
                    "No recent activity",
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
              : _buildActivityItem(),
        ],
      ),
    );
  }

  Widget _buildActivityItem() {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(50.r),
            ),
            child: Icon(
              Icons.warning_amber,
              color: Colors.blue[300],
              size: 18.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Emergency Report",
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "Status: ${latestReport?['status'] ?? 'Unknown'}",
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18.sp, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildNoActiveReport() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(50.r),
              ),
              child: Icon(
                Icons.location_searching,
                size: 36.sp,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              "No reports to track",
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              "Submit an emergency report to start tracking.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: widgetOptions[selectedIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 5.r,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 0 ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Icon(Icons.local_hospital, size: 18.sp),
              ),
              label: "Emergency",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 1 ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Icon(Icons.location_on, size: 18.sp),
              ),
              label: "Track",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 2 ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Icon(Icons.history, size: 18.sp),
              ),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 3 ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Icon(Icons.person, size: 18.sp),
              ),
              label: "Profile",
            ),
          ],
          currentIndex: selectedIndex,
          onTap: onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 11.sp,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            fontSize: 11.sp,
          ),
        ),
      ),
    );
  }
}
