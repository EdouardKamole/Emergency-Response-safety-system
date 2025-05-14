import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emergency_app/components/input_field.dart';
import 'package:emergency_app/screens/home_screen.dart';
import 'package:emergency_app/screens/signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        margin: EdgeInsets.all(20),
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
            SizedBox(height: 14.h),
            Text("Welcome back", style: GoogleFonts.poppins(fontSize: 13.sp)),
            SizedBox(height: 20.h),
            InputField(label: "Email", hintText: "Your email"),
            SizedBox(height: 20.h),
            InputField(label: "Password", hintText: "password"),
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
            SizedBox(height: 30.h),
            SizedBox(
              width: double.infinity,
              child: MaterialButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
                },
                color: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    10.r,
                  ), // Adjust the radius as needed
                ),
                child: Text(
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
                      MaterialPageRoute(builder: (context) => SignupScreen()),
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
          ],
        ),
      ),
    );
  }
}
