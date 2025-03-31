import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:temple_app/provider/theme_provider.dart';
import 'firebase_options.dart';
import 'package:temple_app/constants.dart';
import 'package:temple_app/pages/Dashboards/dashboard_admin.dart';
import 'package:temple_app/pages/Dashboards/dashboard_users.dart';
import 'package:temple_app/pages/Login/login_landing.dart';
import 'package:temple_app/pages/Login/login_page.dart';
import 'package:temple_app/pages/User/bookings_page.dart';

// Background message handler (must be a top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? userRole = prefs.getString('role');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Messaging
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications (iOS requires this, Android may prompt)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Enable foreground notification presentation options (iOS specific)
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Run the app with Provider
    runApp(
      ChangeNotifierProvider(
        create: (context) => ThemeProvider(),
        child: MyApp(isLoggedIn: isLoggedIn, userRole: userRole),
      ),
    );
  } catch (e) {
    debugPrint("🔥 Firebase Initialization Error: $e");
    runApp(const ErrorApp());
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? userRole;

  const MyApp({super.key, required this.isLoggedIn, this.userRole});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    String initialRoute = '/';
    if (isLoggedIn) {
      initialRoute =
          userRole == 'admin' ? '/dashboard_admin' : '/dashboard_user';
    }

    return MaterialApp(
      title: 'Manapullikavu Temple App',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => LoginLanding(),
        '/login': (context) => LoginPage(),
        '/dashboard_admin': (context) => AdminDashboard(),
        '/dashboard_user': (context) => UserDashboardContent(),
        '/bookings_user': (context) => BookingPage(),
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            "Failed to initialize Firebase. Please restart the app.",
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
