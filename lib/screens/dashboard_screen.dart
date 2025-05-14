import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emergency_app/screens/sos_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String currentLocation = "Fetching location...";

  void initState() {
    super.initState();
    _requestLocationPermission(); // Request permission on init
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      // We didn't ask for permission yet or the permission has been denied before but not permanently.
      if (await Permission.location.request().isGranted) {
        // Permission granted
        _getCurrentLocation();
      } else {
        // Permission denied
        print('Location permission denied');
      }
    } else if (status.isGranted) {
      // Permission already granted
      _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied, open app settings
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

      if (placemarks != null && placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          currentLocation =
              "${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
        });
      } else {
        setState(() {
          currentLocation = "No address found for these coordinates";
        });
      }
    } catch (e) {
      setState(() {
        currentLocation = "Error fetching location: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    // or Flexible
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_pin, color: Colors.red),
                            SizedBox(width: 5.w),
                            Expanded(
                              child: Text(
                                currentLocation.length > 30
                                    ? '${currentLocation.substring(0, 30)}...'
                                    : currentLocation,
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30.sp),
                    child: Image.network(
                      'https://avatar.iran.liara.run/public/8',
                      width: 44.sp,
                      height: 44.sp,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 80.h),
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Help is just a click away",
                  style: GoogleFonts.poppins(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Click",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      "SOS button",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      "to call for help",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 70.h),
              Align(
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260.w, // Adjust size as needed
                      height: 260.h, // Adjust size as needed
                      decoration: BoxDecoration(
                        color: Colors.red.shade100, // Lightest shade
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 230.w, // Adjust size as needed
                      height: 230.h, // Adjust size as needed
                      decoration: BoxDecoration(
                        color: Colors.red.shade200, // Medium shade
                        shape: BoxShape.circle,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SosScreen()),
                        );
                      },
                      child: Container(
                        width: 200.w, // Adjust size as needed
                        height: 200.h, // Adjust size as needed
                        decoration: BoxDecoration(
                          color: Colors.red, // Darkest shade
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "SOS",
                            style: GoogleFonts.poppins(
                              fontSize: 30.sp, // Adjust font size as needed
                              color: Colors.white, // Text color
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
