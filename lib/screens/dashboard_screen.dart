import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:emergency_app/screens/sos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String currentLocation = "Fetching location...";
  String userName = "John";
  String temperature = "20°C";
  late AnimationController _animationController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ringAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
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
        print('Location permission denied');
      }
    } else if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      print('Location permission permanently denied');
      openAppSettings();
    }
  }

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
                "${place.name}, ${place.locality}, ${place.administrativeArea}";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFDCEDC8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Card
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30.r,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          userName[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome, $userName",
                              style: GoogleFonts.poppins(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.grey.shade600,
                                  size: 20.sp,
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    currentLocation.length > 30
                                        ? '${currentLocation.substring(0, 30)}...'
                                        : currentLocation,
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade600,
                                      fontSize: 14.sp,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Icon(
                            Icons.wb_sunny,
                            color: Colors.orange.shade600,
                            size: 24.sp,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            temperature,
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30.h),

                // SOS Button
                Center(
                  child: AnimatedSosButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const SosScreen(selectedIndex: 6),
                        ),
                      );
                    },
                    ringAnimation: _ringAnimation,
                  ),
                ),
                SizedBox(height: 40.h),

                // Emergency Services Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 15.w,
                  mainAxisSpacing: 15.h,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.1,
                  children: [
                    EmergencyCard(
                      icon: Icons.local_hospital,
                      title: "Health Care",
                      color: Colors.green,
                      index: 0,
                      onTap: (index) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SosScreen(selectedIndex: index),
                          ),
                        );
                      },
                    ),
                    EmergencyCard(
                      icon: Icons.car_crash,
                      title: "Accident",
                      color: Colors.red,
                      index: 3,
                      onTap: (index) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SosScreen(selectedIndex: index),
                          ),
                        );
                      },
                    ),
                    EmergencyCard(
                      icon: Icons.local_fire_department,
                      title: "Fire & Safety",
                      color: Colors.orange,
                      index: 2,
                      onTap: (index) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SosScreen(selectedIndex: index),
                          ),
                        );
                      },
                    ),
                    EmergencyCard(
                      icon: Icons.local_police,
                      title: "Police",
                      color: Colors.blue,
                      index: 1,
                      onTap: (index) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SosScreen(selectedIndex: index),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmergencyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final int index;
  final Function(int) onTap;

  const EmergencyCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.color,
    required this.index,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30.sp, color: color),
            SizedBox(height: 8.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedSosButton extends StatelessWidget {
  final VoidCallback onTap;
  final Animation<double> ringAnimation;

  const AnimatedSosButton({
    Key? key,
    required this.onTap,
    required this.ringAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Ring 2 (Largest)
          AnimatedBuilder(
            animation: ringAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: ringAnimation.value * 1.3,
                child: Container(
                  width: 130.w,
                  height: 130.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.shade300.withOpacity(0.4),
                      width: 5.w,
                    ),
                  ),
                ),
              );
            },
          ),
          // Outer Ring 1
          AnimatedBuilder(
            animation: ringAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: ringAnimation.value * 1.15,
                child: Container(
                  width: 110.w,
                  height: 110.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.shade400.withOpacity(0.6),
                      width: 5.w,
                    ),
                  ),
                ),
              );
            },
          ),
          // Main SOS Button
          Container(
            width: 90.w,
            height: 90.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade300.withOpacity(0.6),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                "SOS",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
