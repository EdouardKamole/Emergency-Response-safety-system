import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emergency_app/components/input_field.dart';
import 'package:emergency_app/screens/login_screen.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 100.h),
            Text(
              "Let's sign you up",
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 34.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 15.h),
            Text(
              "Welcome",
              textAlign: TextAlign.left,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20.h),
            InputField(label: "Full Name", hintText: "your name"),
            SizedBox(height: 20.h),
            InputField(label: "Email", hintText: "Your email"),
            SizedBox(height: 20.h),
            InputField(label: "Password", hintText: "password"),
            SizedBox(height: 100.h),
            SizedBox(
              width: double.infinity,
              child: MaterialButton(
                onPressed: () {},
                color: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    10.r,
                  ), // Adjust the radius as needed
                ),
                child: Text(
                  "Sign up",
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
                  "Already a member?",
                  style: GoogleFonts.poppins(fontSize: 13.sp),
                ),
                SizedBox(width: 3.w),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  child: Text(
                    "Login",
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
