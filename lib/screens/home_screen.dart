import 'package:emergency_app/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:emergency_app/screens/track_rescue.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  Map<String, dynamic>? latestReport; // Store latest report data

  @override
  void initState() {
    super.initState();
    _fetchLatestReport();
  }

  // Fetch the latest report for the current user
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
        print(snapshot);
        setState(() {
          latestReport = {
            'reportId': reportId,
            'emergencyLat': reportData['location']['latitude'] as double,
            'emergencyLon': reportData['location']['longitude'] as double,
          };
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

  // Build widget options dynamically based on latestReport
  List<Widget> get widgetOptions {
    return [
      const DashboardScreen(),
      latestReport != null
          ? TrackRescuerScreen(
            reportId: latestReport!['reportId'],
            emergencyLat: latestReport!['emergencyLat'],
            emergencyLon: latestReport!['emergencyLon'],
          )
          : Center(
            child: Text(
              "No active report to track",
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Center(child: widgetOptions[selectedIndex])),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital, size: 18.sp),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on, size: 18.sp), // Icon for tracking
            label: 'Track',
          ),
        ],
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
        ),
      ),
    );
  }
}
