import 'package:emergency_app/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:emergency_app/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
          title: 'Emergency App',
          theme: ThemeData(
            primarySwatch: Colors.red,
            textTheme: TextTheme(
              bodyLarge: GoogleFonts.poppins(fontSize: 16.sp),
              bodyMedium: GoogleFonts.poppins(fontSize: 14.sp),
            ),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

// Wrapper to handle authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          // User is signed in, navigate to the home screen
          return const HomeScreen();
        } else {
          // User is not signed in, show login screen
          return const LoginScreen();
        }
      },
    );
  }
}
