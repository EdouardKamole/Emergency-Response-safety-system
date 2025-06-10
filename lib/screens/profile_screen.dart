import 'package:emergency_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  File? _profileImage;

  late AnimationController _slideController;
  late AnimationController _fadeController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicalConditionsController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  String? _profileImageUrl;
  DateTime? _lastUpdated;
  bool _emergencyMode = false;

  // Cloudinary configuration (replace with your credentials)
  final String cloudName = 'dsojq0cm2';
  final String uploadPreset = 'ml_default';

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) _showSnackBar('User not authenticated', isError: true);
      print('Error: User not authenticated'); // Debug log
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _nameController.text = data['fullName'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _emergencyContactController.text = data['emergencyContact'] ?? '';
            _bloodTypeController.text = data['bloodType'] ?? '';
            _allergiesController.text = data['allergies'] ?? '';
            _medicalConditionsController.text = data['medicalConditions'] ?? '';
            _addressController.text = data['address'] ?? '';
            _profileImageUrl = data['profileImageUrl'];
            _emergencyMode = data['emergencyMode'] ?? false;
            _lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();
            _isLoading = false;
          });
          print('User data loaded successfully'); // Debug log
        }
      } else {
        setState(() => _isLoading = false);
        print('No user data found in Firestore'); // Debug log
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading profile: $e', isError: true);
        setState(() => _isLoading = false);
      }
      print('Error in _loadUserData: $e'); // Debug log
    }
  }

  Future<bool> _requestPermission(ImageSource source) async {
    Permission permission =
        source == ImageSource.camera ? Permission.camera : Permission.photos;

    print('Requesting permission: $permission'); // Debug log
    var status = await permission.status;
    print('Initial permission status: $status'); // Debug log

    if (!status.isGranted) {
      try {
        status = await permission.request();
        print('Permission request result: $status'); // Debug log
      } catch (e) {
        if (mounted)
          _showSnackBar('Error requesting permission: $e', isError: true);
        print('Error requesting permission: $e'); // Debug log
        return false;
      }
    }

    if (status.isPermanentlyDenied && mounted) {
      print('Permission permanently denied'); // Debug log
      _showSnackBar(
        'Please enable ${source == ImageSource.camera ? 'camera' : 'gallery'} access in settings.',
        isError: true,
      );
      await openAppSettings();
      return false;
    } else if (status.isDenied && mounted) {
      print('Permission denied'); // Debug log
      _showSnackBar(
        '${source == ImageSource.camera ? 'Camera' : 'Gallery'} permission denied.',
        isError: true,
      );
      return false;
    }

    print('Permission granted: $status'); // Debug log
    return status.isGranted;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      print('Initiating image pick from: $source'); // Debug log
      bool permissionGranted = await _requestPermission(source);
      if (!permissionGranted) {
        print('Permission not granted for $source'); // Debug log
        return;
      }

      print('Launching image picker for: $source'); // Debug log
      XFile? image;
      try {
        image = await _picker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );
      } on PlatformException catch (e) {
        if (mounted) {
          String errorMsg =
              'Error accessing ${source == ImageSource.camera ? 'camera' : 'gallery'}: ${e.message}';
          if (e.code == 'camera_access_denied') {
            errorMsg = 'Camera access denied. Please enable in settings.';
          } else if (e.code == 'photo_access_denied') {
            errorMsg = 'Gallery access denied. Please enable in settings.';
          }
          _showSnackBar(errorMsg, isError: true);
        }
        print(
          'PlatformException in image picker: code=${e.code}, message=${e.message}',
        ); // Debug log
        return;
      } catch (e) {
        if (mounted)
          _showSnackBar(
            'Unexpected error accessing ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e',
            isError: true,
          );
        print('Unexpected error in image picker: $e'); // Debug log
        return;
      }

      if (image == null || image.path.isEmpty) {
        if (mounted) _showSnackBar('No image selected', isError: true);
        print('No image selected or empty path'); // Debug log
        return;
      }

      print('Image selected: ${image.path}'); // Debug log
      File imageFile = File(image.path);
      if (!await imageFile.exists()) {
        if (mounted)
          _showSnackBar('Selected image file does not exist', isError: true);
        print('Image file does not exist: ${image.path}'); // Debug log
        return;
      }

      setState(() {
        _profileImage = imageFile;
        _isLoading = true;
      });

      String? imageUrl = await _uploadImageToCloudinary(imageFile);
      if (imageUrl != null && mounted) {
        await _saveProfileImage(imageUrl);
        setState(() {
          _profileImageUrl = imageUrl;
          _isLoading = false;
        });
        _showSnackBar('Profile picture updated successfully', isError: false);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error selecting image: $e', isError: true);
        setState(() => _isLoading = false);
      }
      print('Error in _pickImage: $e'); // Debug log
    }
  }

  Future<String?> _uploadImageToCloudinary(File image) async {
    if (!await image.exists()) {
      if (mounted) _showSnackBar('Invalid image file', isError: true);
      print('Error: Image file does not exist'); // Debug log
      return null;
    }

    if (cloudName == 'your_cloud_name' ||
        uploadPreset == 'your_upload_preset') {
      if (mounted)
        _showSnackBar('Invalid Cloudinary credentials', isError: true);
      print('Error: Invalid Cloudinary credentials'); // Debug log
      return null;
    }

    try {
      print(
        'Uploading to Cloudinary: cloudName=$cloudName, uploadPreset=$uploadPreset',
      ); // Debug log
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      print('Sending Cloudinary request'); // Debug log
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print(
        'Cloudinary response: status=${response.statusCode}, body=$responseBody',
      ); // Debug log

      try {
        var data = jsonDecode(responseBody);
        if (response.statusCode == 200 && data['secure_url'] != null) {
          print('Upload successful: ${data['secure_url']}'); // Debug log
          return data['secure_url'] as String;
        } else {
          String error = 'Upload failed';
          if (data['error'] != null && data['error']['message'] != null) {
            error += ': ${data['error']['message']}';
          } else {
            error += ': Status ${response.statusCode}, Body: $responseBody';
          }
          if (mounted) _showSnackBar(error, isError: true);
          print('Error: $error'); // Debug log
          return null;
        }
      } catch (e) {
        if (mounted)
          _showSnackBar('Error parsing Cloudinary response: $e', isError: true);
        print('Error parsing Cloudinary response: $e'); // Debug log
        return null;
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error uploading image: $e', isError: true);
      print('Error in _uploadImageToCloudinary: $e'); // Debug log
      return null;
    }
  }

  Future<void> _saveProfileImage(String imageUrl) async {
    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) _showSnackBar('User not authenticated', isError: true);
      print('Error: No authenticated user'); // Debug log
      return;
    }

    try {
      print('Saving profile image URL to Firestore'); // Debug log
      await _firestore.collection('users').doc(user.uid).set({
        'profileImageUrl': imageUrl,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      print('Profile image saved successfully'); // Debug log
    } catch (e) {
      if (mounted)
        _showSnackBar('Error saving profile image: $e', isError: true);
      print('Error in _saveProfileImage: $e'); // Debug log
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed'); // Debug log
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) _showSnackBar('User not authenticated', isError: true);
      print('Error: No authenticated user'); // Debug log
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('Saving profile data to Firestore'); // Debug log
      await _firestore.collection('users').doc(user.uid).set({
        'fullName': _nameController.text.trim(),
        'email': user.email ?? '',
        'phone': _phoneController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'bloodType': _bloodTypeController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'medicalConditions': _medicalConditionsController.text.trim(),
        'address': _addressController.text.trim(),
        'emergencyMode': _emergencyMode,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
        _showSnackBar('Profile updated successfully', isError: false);
        print('Profile data saved successfully'); // Debug log
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving profile: $e', isError: true);
        setState(() => _isLoading = false);
      }
      print('Error in _saveUserData: $e'); // Debug log
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 15.sp)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
    print('SnackBar: $message (isError: $isError)'); // Debug log
  }

  Future<void> _signOut() async {
    try {
      print('Signing out user'); // Debug log
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error signing out: $e', isError: true);
      print('Error in _signOut: $e'); // Debug log
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10.r,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12.h),
                  Container(
                    width: 40.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2.5.r),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Select Image Source',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  Divider(height: 1.h, color: Colors.grey[300]),
                  _buildOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  Divider(height: 1.h, color: Colors.grey[300]),
                  _buildOption(
                    icon: Icons.cancel,
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                    color: Colors.red[400],
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (color ?? const Color(0xFF1565C0)).withOpacity(0.1),
                    Colors.grey[100]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey[300]!,
                    blurRadius: 4.r,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 24.sp,
                color: color ?? const Color(0xFF1565C0),
              ),
            ),
            SizedBox(width: 15.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF001970)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child:
                    _isLoading ? _buildLoadingState() : _buildProfileContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
          Text(
            'My Profile',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap:
                _isLoading
                    ? null
                    : () {
                      if (_isEditing) {
                        _saveUserData();
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color:
                    _isEditing
                        ? Colors.green.withOpacity(0.8)
                        : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                _isEditing ? Icons.save : Icons.edit,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(40.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFF1565C0),
              strokeWidth: 3.w,
            ),
            SizedBox(height: 20.h),
            Text(
              'Loading your profile...',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return Container(
      margin: EdgeInsets.only(top: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          topRight: Radius.circular(30.r),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildProfileHeader(),
                SizedBox(height: 30.h),
                _buildPersonalInfoSection(),
                SizedBox(height: 24.h),
                _buildMedicalInfoSection(),
                SizedBox(height: 24.h),
                _buildContactInfoSection(),
                SizedBox(height: 30.h),
                _buildActionButtons(),
                SizedBox(height: 20.h),
                _buildLastUpdated(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60.r,
                  backgroundColor: Colors.grey[400],
                  backgroundImage:
                      _profileImage != null
                          ? FileImage(_profileImage!)
                          : _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                  child:
                      _profileImage == null && _profileImageUrl == null
                          ? Icon(
                            Icons.person,
                            size: 60.sp,
                            color: const Color(0xFF1565C0),
                          )
                          : null,
                ),
              ),
              GestureDetector(
                onTap: _showImagePickerDialog,
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.3),
                        blurRadius: 8.r,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.edit, size: 16.sp, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'Emergency User',
            style: GoogleFonts.poppins(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1565C0),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _auth.currentUser?.email ?? 'No email',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _buildEnhancedTextField(
          controller: _nameController,
          label: 'Full Name',
          hintText: 'Enter your full name',
          icon: Icons.person,
          enabled: _isEditing,
          validator:
              (value) => value!.isEmpty ? 'Please enter your name' : null,
        ),
        SizedBox(height: 16.h),
        _buildEnhancedTextField(
          controller: _addressController,
          label: 'Address',
          hintText: 'Enter your address',
          icon: Icons.location_on,
          enabled: _isEditing,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildMedicalInfoSection() {
    return _buildSection(
      title: 'Medical Information',
      icon: Icons.local_hospital,
      children: [
        _buildEnhancedTextField(
          controller: _bloodTypeController,
          label: 'Blood Type',
          hintText: 'e.g., A+, O-, B+',
          icon: Icons.bloodtype,
          enabled: _isEditing,
          validator:
              (value) => value!.isEmpty ? 'Please enter your blood type' : null,
        ),
        SizedBox(height: 16.h),
        _buildEnhancedTextField(
          controller: _allergiesController,
          label: 'Allergies',
          hintText: 'List any allergies (e.g., Penicillin, Nuts)',
          icon: Icons.warning,
          enabled: _isEditing,
          maxLines: 2,
        ),
        SizedBox(height: 16.h),
        _buildEnhancedTextField(
          controller: _medicalConditionsController,
          label: 'Medical Conditions',
          hintText: 'List any medical conditions',
          icon: Icons.medical_services,
          enabled: _isEditing,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      title: 'Contact Information',
      icon: Icons.phone,
      children: [
        _buildEnhancedTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hintText: 'Enter your phone number',
          icon: Icons.phone,
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
          validator:
              (value) =>
                  value!.isEmpty ? 'Please enter your phone number' : null,
        ),
        SizedBox(height: 16.h),
        _buildEnhancedTextField(
          controller: _emergencyContactController,
          label: 'Emergency Contact',
          hintText: 'Enter emergency contact number',
          icon: Icons.emergency,
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
          validator:
              (value) =>
                  value!.isEmpty ? 'Please enter an emergency contact' : null,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF1565C0),
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color:
              enabled
                  ? const Color(0xFF1565C0).withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(
            icon,
            color: enabled ? Colors.black87 : Colors.grey,
            size: 20.sp,
          ),
          labelStyle: GoogleFonts.poppins(
            fontSize: 14.sp,
            color: enabled ? Colors.black.withOpacity(0.7) : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.poppins(
            fontSize: 14.sp,
            color: Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.withOpacity(0.05),
        ),
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_isEditing)
          Column(
            children: [
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _saveUserData,
                  child:
                      _isLoading
                          ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Save Changes',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        Container(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.5),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: _signOut,
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastUpdated() {
    if (_lastUpdated == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.update, size: 15.sp, color: const Color(0xFF1565C0)),
          SizedBox(width: 8.w),
          Text(
            'Last updated: ${_lastUpdated!.day}/${_lastUpdated!.month}/${_lastUpdated!.year}',
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: const Color(0xFF1565C0),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
