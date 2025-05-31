import 'package:emergency_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _loadUserData();
    _slideController.forward();
    _fadeController.forward();
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
      if (mounted) {
        _showSnackBar('User not authenticated', isError: true);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
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
          _lastUpdated = data['updatedAt']?.toDate();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading profile: ${e.toString()}', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    User? user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('User not authenticated', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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
        'profileImageUrl': _profileImageUrl,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
        _showSnackBar('Profile updated successfully', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving profile: ${e.toString()}', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        // TODO: Upload to Firebase Storage and get URL
        // _uploadProfileImage();
      }
    } catch (e) {
      _showSnackBar('Error selecting image: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } catch (e) {
      _showSnackBar('Error signing out: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
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
                        setState(() {
                          _isEditing = true;
                        });
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
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF1565C0),
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
                _buildEmergencyToggle(),
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
      position: Tween<Offset>(begin: Offset(0, -1), end: Offset.zero).animate(
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
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60.r,
                  backgroundColor: Color(0xFF1565C0).withOpacity(0.1),
                  backgroundImage:
                      _profileImage != null ? FileImage(_profileImage!) : null,
                  child:
                      _profileImage == null && _profileImageUrl == null
                          ? Icon(
                            Icons.person,
                            size: 60.sp,
                            color: Color(0xFF1565C0),
                          )
                          : null,
                ),
              ),
              if (_isEditing)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Color(0xFF1565C0),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF1565C0).withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 18.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : "Emergency User",
            style: GoogleFonts.poppins(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _auth.currentUser?.email ?? "No email",
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyToggle() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _emergencyMode
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            _emergencyMode
                ? Colors.red.withOpacity(0.05)
                : Colors.green.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color:
              _emergencyMode
                  ? Colors.red.withOpacity(0.3)
                  : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color:
                  _emergencyMode
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _emergencyMode ? Icons.emergency : Icons.verified_user,
              color: _emergencyMode ? Colors.red : Colors.green,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _emergencyMode ? "Emergency Mode ON" : "Emergency Mode OFF",
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: _emergencyMode ? Colors.red : Colors.green,
                  ),
                ),
                Text(
                  _emergencyMode
                      ? "Quick access to emergency features"
                      : "Normal mode - tap to enable emergency features",
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _emergencyMode,
            onChanged:
                _isEditing
                    ? (value) {
                      setState(() {
                        _emergencyMode = value;
                      });
                    }
                    : null,
            activeColor: Colors.red,
            inactiveThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      title: "Personal Information",
      icon: Icons.person_outline,
      children: [
        _buildEnhancedTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person,
          enabled: _isEditing,
          validator:
              (value) => value!.isEmpty ? 'Please enter your name' : null,
        ),
        SizedBox(height: 16.h),
        _buildEnhancedTextField(
          controller: _addressController,
          label: 'Address',
          hint: 'Enter your address',
          icon: Icons.location_on,
          enabled: _isEditing,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildMedicalInfoSection() {
    return _buildSection(
      title: "Medical Information",
      icon: Icons.local_hospital,
      children: [
        _buildEnhancedTextField(
          controller: _bloodTypeController,
          label: 'Blood Type',
          hint: 'e.g., A+, O-, B+',
          icon: Icons.bloodtype,
          enabled: _isEditing,
          validator:
              (value) => value!.isEmpty ? 'Please enter your blood type' : null,
        ),
        SizedBox(height: 16.h),
        _buildEnhancedTextField(
          controller: _allergiesController,
          label: 'Allergies',
          hint: 'List any allergies (e.g., Penicillin, Nuts)',
          icon: Icons.warning_amber,
          enabled: _isEditing,
          maxLines: 2,
        ),
        SizedBox(height: 16.h),
        _buildEnhancedTextField(
          controller: _medicalConditionsController,
          label: 'Medical Conditions',
          hint: 'List any medical conditions',
          icon: Icons.medical_services,
          enabled: _isEditing,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      title: "Contact Information",
      icon: Icons.phone,
      children: [
        _buildEnhancedTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
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
          hint: 'Enter emergency contact number',
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
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16.r),
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
                    color: Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: Color(0xFF1565C0), size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color:
              enabled
                  ? Color(0xFF1565C0).withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: enabled ? Color(0xFF1565C0) : Colors.grey,
            size: 20.sp,
          ),
          labelStyle: GoogleFonts.poppins(
            fontSize: 14.sp,
            color: enabled ? Color(0xFF1565C0) : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.poppins(
            fontSize: 14.sp,
            color: Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Color(0xFF1565C0), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.withOpacity(0.1),
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
          Container(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1565C0),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 4,
              ),
              onPressed: _isLoading ? null : _saveUserData,
              child:
                  _isLoading
                      ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'Save Changes',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
            ),
          ),
        SizedBox(height: 16.h),
        Container(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red, width: 1.5),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
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
    if (_lastUpdated == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.update, size: 16.sp, color: Colors.blue),
          SizedBox(width: 8.w),
          Text(
            'Last updated: ${_lastUpdated!.day}/${_lastUpdated!.month}/${_lastUpdated!.year}',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
