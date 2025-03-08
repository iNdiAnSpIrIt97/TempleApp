import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:temple_app/pages/Dashboards/dashboard_admin.dart';
import 'package:temple_app/pages/Dashboards/dashboard_users.dart';
import 'package:temple_app/pages/Login/login_landing.dart';
import 'package:temple_app/pages/Login/login_page.dart';
import 'package:temple_app/pages/User/bookings_page.dart';
import 'firebase_options.dart';
import 'package:temple_app/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("🔥 Firebase Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temple App',
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        primaryColor: AppColors.lightOther,
        iconTheme: IconThemeData(color: AppColors.lightIcons),
        textTheme: TextTheme(bodyMedium: TextStyle(color: AppColors.lightText)),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: AppColors.lightOther,
          unselectedItemColor: Colors.grey,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black),
          hintStyle: TextStyle(color: Colors.black54),
          prefixIconColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        primaryColor: AppColors.darkOther,
        iconTheme: IconThemeData(color: AppColors.darkIcons),
        textTheme: TextTheme(bodyMedium: TextStyle(color: AppColors.darkText)),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: AppColors.darkOther,
          unselectedItemColor: Colors.grey,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black),
          hintStyle: TextStyle(color: Colors.black54),
          prefixIconColor: Colors.black,
        ),
      ),
      initialRoute: '/', // Default route
      routes: {
        '/': (context) => LoginLanding(),
        '/login': (context) => LoginPage(),
        '/dashboard_admin': (context) => AdminDashboard(),
        '/dashboard_user': (context) => UserDashboard(),
        '/bookings_user': (context) => BookingPage(),
      },
    );
  }
}
