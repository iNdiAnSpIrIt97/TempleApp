import 'package:flutter/material.dart';
import 'package:temple_app/pages/Dashboards/dashboard_users.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/pages/Login/login_page.dart';
import 'package:temple_app/pages/Login/register_page.dart';

class LoginLanding extends StatelessWidget {
  // Add this method to handle guest login
  Future<void> _handleGuestLogin(BuildContext context) async {
    try {
      // Get instance of SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Clear existing preferences
      await prefs.clear();

      // Set role as guest
      await prefs.setString('role', 'guest');

      // Navigate to UserDashboardContent
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => UserDashboardContent()),
      );
    } catch (e) {
      // Handle any errors that might occur
      print('Error in guest login: $e');
    }
  }

  // Fix the navigation method by adding context as a parameter
  void _navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegistrationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/mpkv.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Sree Manapullikavu Bhagavathy Temple',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 70),
                  CircleAvatar(
                    radius: MediaQuery.of(context).size.width * 0.3,
                    backgroundImage: AssetImage('assets/images/mpk.png'),
                  ),
                  SizedBox(height: 70),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.2,
                          vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => LoginPage()));
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 25),
                  TextButton(
                    onPressed: () =>
                        _handleGuestLogin(context), // Guest login handler
                    child: Text(
                      'Continue as Guest',
                      style: TextStyle(
                          fontSize: 16,
                          color: const Color.fromARGB(255, 251, 197, 127)),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => _navigateToRegister(
                        context), // Fix: Navigate to Register
                    child: Text(
                      'New User?  Register Here',
                      style: TextStyle(
                          fontSize: 16,
                          color: const Color.fromARGB(255, 255, 205, 26)),
                    ),
                  ),
                  Text(
                    'Sree Manapulli Bhagavathy Devaswom, East Yakkara, Manapullikavu, Palakkad - 678701',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '© 2025 All Rights Reserved ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
