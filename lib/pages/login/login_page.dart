import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:temple_app/pages/Login/forgor_password.dart';
import 'package:temple_app/pages/Login/login_landing.dart';
import 'package:temple_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showToast("Email and Password cannot be empty", Colors.red);
      return;
    }

    if (!_isValidEmail(email)) {
      _showToast("Enter a valid email address", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call login function without expecting a return value
      await _authService.login(email, password, context);

      // Since login succeeds, get the current user
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Check if the user's email is verified
        if (!user.emailVerified) {
          // Show a popup to inform the user to verify their email
          _showVerificationPopup(user);
          return; // Prevent further actions if the user is not verified
        }

        // Fetch user data from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // Check if the user is verified in Firestore
          bool isVerifiedInFirestore = userData['verified'] ?? false;

          // If the user is verified in Firebase Auth but not in Firestore, update Firestore
          if (user.emailVerified && !isVerifiedInFirestore) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'verified': true});
            print(
                "Updated Firestore 'verified' field to true for UID: ${user.uid}");
          }

          // Store user data in SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('email', userData['email'] ?? '');
          await prefs.setString('phone', userData['phone'] ?? '');
          await prefs.setString('role', userData['role'] ?? '');
          await prefs.setString('user_name', userData['user_name'] ?? '');

          // Print statements to verify the saved preferences
          print("Saved Email: ${prefs.getString('email')}");
          print("Saved Phone: ${prefs.getString('phone')}");
          print("Saved Role: ${prefs.getString('role')}");
          print("Saved User Name: ${prefs.getString('user_name')}");

          // Navigate to the dashboard only if the user is verified
          if (user.emailVerified) {
            _showToast("Login Successful!", Colors.green);
            // TODO: Navigate to Home/Dashboard screen after login
          } else {
            _showToast("Please verify your email to proceed.", Colors.red);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      _showToast("An unexpected error occurred", Colors.red);
      print("Login error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Show a popup to inform the user to verify their email
  void _showVerificationPopup(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Account Not Verified"),
        content: const Text(
            "Your account is not verified. Please verify your email to continue."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () => _resendVerificationEmail(user),
            child: const Text("Resend Verification Email"),
          ),
        ],
      ),
    );
  }

  /// Resend verification email
  Future<void> _resendVerificationEmail(User user) async {
    try {
      await user.sendEmailVerification();
      _showToast("Verification email sent!", Colors.green);
    } catch (e) {
      _showToast("Failed to resend verification email", Colors.red);
      print("Error resending verification email: $e");
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(email);
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case "invalid-email":
        message = "Invalid email format.";
        break;
      case "user-not-found":
        message = "No user found for this email.";
        break;
      case "wrong-password":
        message = "Incorrect password.";
        break;
      case "too-many-requests":
        message = "Too many failed attempts. Try again later.";
        break;
      default:
        message = "Login failed. Please try again.";
    }
    _showToast(message, Colors.red);
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _navigateToResetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ResetPasswordPage()),
    );
  }

  void _navigateToLoginLanding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginLanding()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _navigateToLoginLanding,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/images/mpk.png'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Welcome Back!",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _navigateToResetPassword,
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
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
