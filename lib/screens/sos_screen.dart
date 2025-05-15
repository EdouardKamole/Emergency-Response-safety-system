import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({Key? key}) : super(key: key);

  @override
  _SosScreenState createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  int selectedIndex = -1;
  String currentLocation = "Fetching Location...";
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
    _requestLocationPermission();
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

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _video = null; // Clear video if image is selected
      });
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _video = File(video.path);
        _image = null; // Clear image if video is selected
      });
    }
  }

  void _clearMedia() {
    setState(() {
      _image = null;
      _video = null;
      _videoThumbnailPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hasMedia = _image != null || _video != null;

    return Scaffold(
      appBar: AppBar(titleSpacing: 0, leadingWidth: 40.w),
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Select Emergency",
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: gridItems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10.w,
                    mainAxisSpacing: 8.h,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              gridItems[index]['icon'],
                              size: 30.sp,
                              color:
                                  selectedIndex == index
                                      ? Colors.red
                                      : Colors.black87,
                            ),
                            SizedBox(height: 5.h),
                            Text(
                              gridItems[index]['label'],
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color:
                                    selectedIndex == index
                                        ? Colors.red
                                        : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 30.h),
                Text(
                  "Location",
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.location_pin, size: 20.sp, color: Colors.red),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        currentLocation.length > 50
                            ? '${currentLocation.substring(0, 50)}...'
                            : currentLocation,
                        style: GoogleFonts.poppins(fontSize: 15.sp),
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
                          fontSize: 15.sp,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Upload media",
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "(optional)",
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                _buildMediaSection(),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      "Submit",
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
      return Stack(
        alignment: Alignment.topRight,
        children: [
          SizedBox(
            height: 100.h,
            width: 100.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.file(_image!, fit: BoxFit.cover),
            ),
          ),
          GestureDetector(
            onTap: _clearMedia,
            child: Container(
              margin: EdgeInsets.all(5.0),
              padding: EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 16.sp),
            ),
          ),
        ],
      );
    } else if (_video != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          SizedBox(
            height: 100.h,
            width: 100.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                color: Colors.grey,
                child: Center(
                  child: Icon(Icons.videocam, size: 40.sp, color: Colors.white),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearMedia,
            child: Container(
              margin: EdgeInsets.all(5.0),
              padding: EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 16.sp),
            ),
          ),
        ],
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _buildMediaSection() {
    bool hasMedia = _image != null || _video != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildThumbnail(),
        if (!hasMedia)
          Row(
            children: [
              _buildMediaButton(
                icon: Icons.image,
                text: "Image",
                onPressed: _pickImage,
              ),
              _buildMediaButton(
                icon: Icons.videocam,
                text: "Video",
                onPressed: _pickVideo,
              ),
            ],
          ),
        if (hasMedia)
          Padding(
            padding: EdgeInsets.only(left: 10.w),
            child: _buildMediaButton(
              icon: Icons.add_a_photo,
              text: "Add",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return DraggableScrollableSheet(
                      initialChildSize: 0.3,
                      minChildSize: 0.2,
                      maxChildSize: 0.8,
                      builder: (
                        BuildContext context,
                        ScrollController scrollController,
                      ) {
                        return SafeArea(
                          child: ListView(
                            controller: scrollController,
                            children: <Widget>[
                              ListTile(
                                leading: new Icon(Icons.image),
                                title: new Text('Pick Image'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage();
                                },
                              ),
                              ListTile(
                                leading: new Icon(Icons.videocam),
                                title: new Text('Pick Video'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickVideo();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  void _showLocationDrawer(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20.w),
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                0.6, // Set a maximum height
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Select Location",
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp, // Increased font size
                    fontWeight: FontWeight.w600, // Added font weight
                    color: Colors.black87, // Added color
                  ),
                ),
                SizedBox(height: 20.h),
                ListTile(
                  leading: Icon(
                    Icons.gps_fixed,
                    color: Colors.red,
                  ), // Added color to icon
                  title: Text(
                    "Use Current GPS Location",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ), // Styled text
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _requestLocationPermission();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.search,
                    color: Colors.red,
                  ), // Added color to icon
                  title: Text(
                    "Type Location",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ), // Styled text
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showLocationInputDialog(context);
                  },
                ),
                SizedBox(height: 50.h),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLocationInputDialog(BuildContext context) {
    String typedLocation = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(20.w),
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height *
                  0.6, // Set a maximum height
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Enter Location",
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp, // Increased font size
                      fontWeight: FontWeight.w600, // Added font weight
                      color: Colors.black87, // Added color
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    onChanged: (value) {
                      typedLocation = value;
                    },
                    decoration: InputDecoration(
                      hintText: "Type location here",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ), // Styled hint text
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ), // Added border
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ), // Styled button text
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text(
                          "OK",
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ), // Styled button text
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            currentLocation = typedLocation;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
