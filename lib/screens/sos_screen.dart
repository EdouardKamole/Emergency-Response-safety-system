import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({Key? key}) : super(key: key);

  @override
  _SosScreenState createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  int selectedIndex = -1;
  String currentLocation = "Fetching location...";
  List<Map<String, dynamic>> gridItems = [
    {'icon': Icons.medical_services, 'label': 'Medical'},
    {'icon': Icons.local_police, 'label': 'Police'},
    {'icon': Icons.fire_truck, 'label': 'Fire'},
    {'icon': Icons.car_crash, 'label': 'Accident'},
    {'icon': Icons.warning, 'label': 'Hazard'},
    {'icon': Icons.other_houses, 'label': 'Other'},
  ];

  File? _image;
  File? _video;
  String? _videoThumbnailPath;
  File? _audio;

  @override
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
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 40.w,
        title: Text(
          "Emergency Report",
          style: GoogleFonts.poppins(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Select Emergency Type",
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: gridItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4.w,
                  mainAxisSpacing: 2.h,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          // Added Container for background
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                selectedIndex == index
                                    ? Colors.red
                                    : Colors
                                        .grey
                                        .shade200, // Light grey background
                          ),
                          padding: EdgeInsets.all(8.w),
                          child: Icon(
                            gridItems[index]['icon'],
                            size: 35.sp,
                            color:
                                selectedIndex == index
                                    ? Colors.white
                                    : Colors.black,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          gridItems[index]['label'],
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color:
                                selectedIndex == index
                                    ? Colors.red
                                    : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 10.h),
              Text(
                "Location",
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 17.sp),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      currentLocation.length >
                              50 // Check if the text is longer than 50 characters
                          ? '${currentLocation.substring(0, 50)}...' // Truncate and add ellipsis
                          : currentLocation, // Otherwise, show the full text
                      style: GoogleFonts.poppins(fontSize: 13.sp),
                      overflow: TextOverflow.ellipsis,
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
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Text(
                "Upload Evidence",
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 10.h),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceAround,
              //   children: [
              //     _buildMediaButton(
              //       icon: Icons.image,
              //       text: "Image",
              //       onPressed: _pickImage,
              //     ),
              //     _buildMediaButton(
              //       icon: Icons.videocam,
              //       text: "Video",
              //       onPressed: _pickVideo,
              //     ),
              //     _buildMediaButton(
              //       icon: Icons.mic,
              //       text: "Voice",
              //       onPressed: _pickAudio,
              //     ),
              //   ],
              // ),
              SizedBox(height: 10.h),
              _buildThumbnail(),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: Text(
                    "Submit",
                    style: GoogleFonts.poppins(fontSize: 16.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(iconSize: 40.sp, icon: Icon(icon), onPressed: onPressed),
        Text(text, style: GoogleFonts.poppins(fontSize: 12.sp)),
      ],
    );
  }

  Widget _buildThumbnail() {
    if (_image != null) {
      return Image.file(_image!, height: 100.h);
    } else if (_videoThumbnailPath != null) {
      return Image.file(File(_videoThumbnailPath!), height: 100.h);
    } else {
      return SizedBox.shrink();
    }
  }

  void _showLocationDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Location",
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 20.h),
              ListTile(
                leading: Icon(Icons.gps_fixed),
                title: Text(
                  "Use Current GPS Location",
                  style: GoogleFonts.poppins(fontSize: 14.sp),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _requestLocationPermission();
                },
              ),
              ListTile(
                leading: Icon(Icons.search),
                title: Text(
                  "Type Location",
                  style: GoogleFonts.poppins(fontSize: 14.sp),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLocationInputDialog(context);
                },
              ),
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
          title: Text(
            "Enter Location",
            style: GoogleFonts.poppins(fontSize: 16.sp),
          ),
          content: TextField(
            onChanged: (value) {
              typedLocation = value;
            },
            decoration: InputDecoration(hintText: "Type location here"),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  currentLocation = typedLocation;
                });
              },
            ),
          ],
        );
      },
    );
  }
}
