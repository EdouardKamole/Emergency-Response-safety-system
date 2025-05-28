import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Fetch user data exclusively from Firestore
  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _nameController.text =
              doc.exists && doc.get('fullName') != null
                  ? doc.get('fullName')
                  : '';
          _phoneController.text =
              doc.exists && doc.get('phone') != null ? doc.get('phone') : '';
          _emergencyContactController.text =
              doc.exists && doc.get('emergencyContact') != null
                  ? doc.get('emergencyContact')
                  : '';
          _bloodTypeController.text =
              doc.exists && doc.get('bloodType') != null
                  ? doc.get('bloodType')
                  : '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Save updated data to Firestore
  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      }
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
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _bloodTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.blue[400],
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 10.w),
            child: MaterialButton(
              color: Colors.amber[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              onPressed:
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
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.save : Icons.edit,
                    size: 15.sp,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _isEditing ? 'Save' : 'Edit Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: Colors.blue[400],
                  strokeWidth: 3.w,
                ),
              )
              : Padding(
                padding: EdgeInsets.all(16.w),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Profile Picture Placeholder
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50.r,
                              backgroundColor: Colors.grey[300],
                              child: const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 15.r,
                                  backgroundColor: Colors.blue[400],
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 15.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        enabled: _isEditing,
                        validator:
                            (value) =>
                                value!.isEmpty
                                    ? 'Please enter your name'
                                    : null,
                      ),
                      SizedBox(height: 16.h),
                      // Phone Number Field
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: 'Enter your phone number',
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator:
                            (value) =>
                                value!.isEmpty
                                    ? 'Please enter your phone number'
                                    : null,
                      ),
                      SizedBox(height: 16.h),
                      // Emergency Contact Field
                      _buildTextField(
                        controller: _emergencyContactController,
                        label: 'Emergency Contact',
                        hint: 'Enter an emergency contact number',
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator:
                            (value) =>
                                value!.isEmpty
                                    ? 'Please enter an emergency contact'
                                    : null,
                      ),
                      SizedBox(height: 16.h),
                      // Blood Type Field
                      _buildTextField(
                        controller: _bloodTypeController,
                        label: 'Blood Type',
                        hint: 'Enter your blood type (e.g., A+, O-)',
                        enabled: _isEditing,
                        validator:
                            (value) =>
                                value!.isEmpty
                                    ? 'Please enter your blood type'
                                    : null,
                      ),
                      SizedBox(height: 20.h),
                      if (_isEditing)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 15.h,
                            ),
                            backgroundColor: Colors.green[400],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          onPressed: _isLoading ? null : _saveUserData,
                          child:
                              _isLoading
                                  ? SizedBox(
                                    height: 20.h,
                                    width: 20.w,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    'Save Profile',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  // Helper method to build text fields with consistent styling
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.grey[600],
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.grey[400],
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.blue[400]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
      enabled: enabled,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.black87),
      validator: validator,
    );
  }
}
