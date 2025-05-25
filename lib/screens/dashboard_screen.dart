import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:emergency_app/screens/sos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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

    // Initialize the animation controller for the SOS button rings
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ringAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              SizedBox(
                height: 180.h,
                child: Container(
                  padding: EdgeInsets.all(24.w),
                  color: Colors.blue[300],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome, $userName",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.location_pin,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                              SizedBox(width: 4.w),
                              SizedBox(
                                width: 200.w,
                                child: Text(
                                  currentLocation.length > 25
                                      ? '${currentLocation.substring(0, 25)}...'
                                      : currentLocation,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 16.sp,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.wb_sunny,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            temperature,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Grid Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
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
              ),
              SizedBox(height: 20.h),
              // SOS Button with Outer Rings
              AnimatedSosButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SosScreen(selectedIndex: 6),
                    ),
                  );
                },
                ringAnimation: _ringAnimation,
              ),
              SizedBox(height: 20.h),
            ],
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
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24.sp, color: color),
            SizedBox(height: 6.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
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
                  width: 120.w,
                  height: 120.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.shade300.withOpacity(0.3),
                      width: 4.w,
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
                  width: 100.w,
                  height: 100.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.shade400.withOpacity(0.5),
                      width: 4.w,
                    ),
                  ),
                ),
              );
            },
          ),
          // Main SOS Button
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade300.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                "SOS",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24.sp,
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
