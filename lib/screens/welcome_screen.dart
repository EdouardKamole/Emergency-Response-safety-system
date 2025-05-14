import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.health_and_safety,
            color: Colors.red,
            size: 40.r,
          ),
          Text(
            "Emergency",
            style: TextStyle(
                color: Colors.red,
                fontSize: 35.sp,
                fontWeight: FontWeight.w700),
          ),
          Text(
            "Response System",
            style: TextStyle(color: Colors.red, fontSize: 20.sp),
          )
        ],
      ),
    ));
  }
}
