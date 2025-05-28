import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:emergency_app/screens/signup_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(408, 883),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flutter ScreenUtil Demo',
          theme: ThemeData(
            primarySwatch: Colors.red,
            textTheme: TextTheme(
              bodyLarge: GoogleFonts.poppins(fontSize: 16.sp),
              bodyMedium: GoogleFonts.poppins(fontSize: 14.sp),
            ),
          ),
          home: SignupScreen(),
        );
      },
    );
  }
}
