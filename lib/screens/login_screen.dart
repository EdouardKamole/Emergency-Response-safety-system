import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emergency_app/components/input_field.dart';
import 'package:emergency_app/screens/home_screen.dart';
import 'package:emergency_app/screens/signup_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmailAndPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Navigate to HomeScreen after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      print("Error during login: $e");
      setState(() {
        _errorMessage = "An unexpected error occurred.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Google Sign-In cancelled.";
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // Navigate to HomeScreen after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } catch (e) {
      print("Error during Google Sign-In: $e");
      setState(() {
        _errorMessage = "Failed to sign in with Google.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 80.h),
                Text(
                  "Let's sign you in",
                  style: GoogleFonts.poppins(
                    fontSize: 34.sp,
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  "Welcome back",
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20.h),
                InputField(
                  label: "Email",
                  hintText: "Your email",
                  hideText: false,
                  fieldIcon: Icon(Icons.email),
                  controller: _emailController,
                ),
                SizedBox(height: 20.h),
                InputField(
                  label: "Password",
                  hintText: "password",
                  hideText: true,
                  fieldIcon: Icon(Icons.remove_red_eye),
                  controller: _passwordController,
                ),
                SizedBox(height: 10.h),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupScreen()),
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Forgot password?",
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 14.sp),
                    ),
                  ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: MaterialButton(
                    onPressed: _isLoading ? null : _loginWithEmailAndPassword,
                    color: Colors.red,
                    padding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 14.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child:
                        _isLoading
                            ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                            : Text(
                              "Login",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13.5.sp,
                              ),
                            ),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Are you new here?",
                      style: GoogleFonts.poppins(fontSize: 13.sp),
                    ),
                    SizedBox(width: 3.w),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Signup",
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon:
                        _isLoading
                            ? null
                            : FaIcon(
                              FontAwesomeIcons.google,
                              color: Colors.red,
                              size: 20.sp,
                            ),
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    label:
                        _isLoading
                            ? SizedBox(
                              // Show CircularProgressIndicator when loading
                              width: 24.w,
                              height: 24.h,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                              ),
                            )
                            : Text(
                              // Show button text when not loading
                              "Login with Google",
                              style: GoogleFonts.poppins(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 13.5.sp,
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
}
