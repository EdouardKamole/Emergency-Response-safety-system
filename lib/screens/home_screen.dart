import 'package:emergency_app/screens/history_screen.dart';
import 'package:emergency_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  String currentLocation = "Fetching location..."; // Initial state for location

  @override
  void initState() {
    super.initState();
    _fetchLatestReport();
    _fetchUserData();
    _requestLocationPermission(); // Request and fetch location

    // Initialize animations
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Fetch user data for personalization
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final database = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await database.get();

      if (snapshot.exists && mounted) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          userName = userData['name'] ?? userData['fullName'] ?? "User";
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  // Request location permission
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
        print('Location permission denied');
      }
    } else if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          currentLocation = "Location permission permanently denied";
        });
      }
      print('Location permission permanently denied');
      openAppSettings(); // Prompt user to enable in settings
    }
  }

  // Fetch current location
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            currentLocation =
                "${place.name ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}"
                    .trim()
                    .replaceAll(RegExp(r',\s*,'), ',')
                    .replaceAll(RegExp(r'^\s*,'), '')
                    .replaceAll(RegExp(r',\s*$'), '');
            if (currentLocation.isEmpty) {
              currentLocation = "Location found, but address unavailable";
            }
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
      print("Error fetching location: $e");
    }
  }

  // Enhanced fetch latest report with status tracking
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
              (reportData['status'] == 'active' ||
                  reportData['status'] == 'dispatched');
        });
      }
    } catch (e) {
      print("Error fetching latest report: $e");
    }
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  // Enhanced widget options with better UI
  List<Widget> get widgetOptions {
    return [
      _buildEnhancedDashboard(),
      latestReport != null
          ? TrackRescuerScreen(
            reportId: latestReport!['reportId'],
            emergencyLat: latestReport!['emergencyLat'],
            emergencyLon: latestReport!['emergencyLon'],
          )
          : _buildNoActiveReport(),
      HistoryScreen(),
      ProfileScreen(),
    ];
  }

  Widget _buildEnhancedDashboard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF001970)],
        ),
      ),
      child: SingleChildScrollView(
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
    );
  }

  Widget _buildEnhancedHeader() {
    return SlideTransition(
      position: Tween<Offset>(begin: Offset(0, -1), end: Offset.zero).animate(
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
                    Text(
                      userName.isNotEmpty ? userName : "Emergency User",
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
                    borderRadius: BorderRadius.circular(50),
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
                    decoration: BoxDecoration(
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
    if (!isEmergencyActive) return SizedBox.shrink();

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
                decoration: BoxDecoration(
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
                  color: Colors.orange,
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
    // Map titles to indices for SosScreen
    int getIndexForTitle(String title) {
      switch (title) {
        case "Emergency":
          return 0; // General emergency, maps to Health Care
        case "Ambulance":
          return 3; // Maps to Accident
        default:
          return 6; // Fallback for general SOS
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
              blurRadius: 10,
              offset: Offset(0, 4),
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
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Emergency Services",
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.2,
            children: [
              _buildServiceCard(
                icon: Icons.local_hospital,
                title: "Health Care",
                color: Color(0xFF4CAF50),
              ),
              _buildServiceCard(
                icon: Icons.local_fire_department,
                title: "Fire & Safety",
                color: Color(0xFFFF5722),
              ),
              _buildServiceCard(
                icon: Icons.security,
                title: "Police",
                color: Color(0xFF2196F3),
              ),
              _buildServiceCard(
                icon: Icons.medication,
                title: "Accident",
                color: Color(0xFF9C27B0),
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
    // Map titles to indices for SosScreen
    int getIndexForTitle(String title) {
      switch (title) {
        case "Health Care":
          return 0;
        case "Fire & Safety":
          return 2;
        case "Police":
          return 1;
        case "Accident":
          return 3;
        default:
          return 6; // Fallback for general SOS
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
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 4),
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
                  fontSize: 18.sp,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => onItemTapped(2), // Navigate to history
                child: Text(
                  "View All",
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          latestReport != null
              ? _buildActivityItem()
              : Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Text(
                    "No recent activity",
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildActivityItem() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emergency, color: Colors.blue, size: 16.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Emergency Report",
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Status: ${latestReport!['status'] ?? 'Unknown'}",
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildNoActiveReport() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_searching,
                size: 48.sp,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              "No Active Report to Track",
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "When you submit an emergency report,\nyou'll be able to track it here",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.grey),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 0
                          ? Color(0xFF1565C0).withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.local_hospital, size: 20.sp),
              ),
              label: 'Emergency',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 1
                          ? Color(0xFF1565C0).withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.location_on, size: 20.sp),
              ),
              label: 'Track',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 2
                          ? Color(0xFF1565C0).withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.history, size: 20.sp),
              ),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color:
                      selectedIndex == 3
                          ? Color(0xFF1565C0).withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.person, size: 20.sp),
              ),
              label: 'Profile',
            ),
          ],
          currentIndex: selectedIndex,
          onTap: onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12.sp,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }
}
