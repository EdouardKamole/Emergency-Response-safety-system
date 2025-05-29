import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.blue[400],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.save : Icons.edit,
              color: Colors.white,
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
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Profile Picture
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60.r,
                            backgroundColor: Colors.grey[300],
                            child: Icon(
                              Icons.person,
                              size: 60.sp,
                              color: Colors.grey,
                            ),
                          ),
                          if (_isEditing)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue[400],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.camera_alt,
                                  size: 20.sp,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  // TODO: Implement image selection
                                },
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 30.h),
                      Expanded(
                        child: ListView(
                          children: [
                            // Full Name
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
                            SizedBox(height: 20.h),

                            // Phone Number
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
                            SizedBox(height: 20.h),

                            // Emergency Contact
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
                            SizedBox(height: 20.h),

                            // Blood Type
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
                            SizedBox(height: 40.h),

                            // Save Button
                            if (_isEditing)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[400],
                                  padding: EdgeInsets.symmetric(vertical: 15.h),
                                  textStyle: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.r),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _saveUserData,
                                child:
                                    _isLoading
                                        ? SizedBox(
                                          height: 25.h,
                                          width: 25.w,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3.w,
                                          ),
                                        )
                                        : Text(
                                          'Save Profile',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: TextFormField(
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
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue[400]!),
            ),
            filled: false,
          ),
          enabled: enabled,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.black87),
          validator: validator,
        ),
      ),
    );
  }
}
