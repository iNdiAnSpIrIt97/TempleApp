import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:temple_app/pages/Login/forgot_password.dart';
import 'package:temple_app/pages/Login/login_landing.dart';
import 'package:temple_app/pages/Login/register_page.dart';
import 'package:temple_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

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
  DateTime? _lastVerificationEmailSent; // Track the last time an email was sent

  // Method to set user preferences including isGuest
  Future<void> _setUserPreferences(
      User user, Map<String, dynamic> userData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', userData['email'] ?? '');
    await prefs.setString('phone', userData['phone'] ?? '');
    await prefs.setString('role', userData['role'] ?? '');
    await prefs.setString('user_name', userData['user_name'] ?? '');
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool(
        'isGuest', false); // Set as non-guest on successful login
    await prefs.setString('uid', user.uid);

    developer.log('SharedPreferences set after login:');
    developer.log('Email: ${prefs.getString('email')}');
    developer.log('Phone: ${prefs.getString('phone')}');
    developer.log('Role: ${prefs.getString('role')}');
    developer.log('User Name: ${prefs.getString('user_name')}');
    developer.log('isLoggedIn: ${prefs.getBool('isLoggedIn')}');
    developer.log('isGuest: ${prefs.getBool('isGuest')}');
    developer.log('UID: ${prefs.getString('uid')}');
  }

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
      await _authService.login(email, password, context);
      User? user = FirebaseAuth.instance.currentUser;

      developer.log('Login attempt with email: $email');

      if (user != null) {
        developer.log('User logged in with UID: ${user.uid}');
        developer.log('Email verified: ${user.emailVerified}');

        if (!user.emailVerified) {
          _showVerificationPopup(user);
          return;
        }

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          developer.log('User data from Firestore: $userData');

          bool isVerifiedInFirestore = userData['verified'] ?? false;
          if (user.emailVerified && !isVerifiedInFirestore) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'verified': true});
            developer.log(
                "Updated Firestore 'verified' field to true for UID: ${user.uid}");
          }

          await _setUserPreferences(user, userData);

          if (user.emailVerified) {
            _showToast("Login Successful!", Colors.green);
            // TODO: Navigate to Home/Dashboard
          } else {
            _showToast("Please verify your email to proceed.", Colors.red);
          }
        } else {
          developer
              .log('No user document found in Firestore for UID: ${user.uid}');
        }
      } else {
        developer.log('No user returned after login attempt');
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      _showToast("An unexpected error occurred", Colors.red);
      developer.log("Login error: $e", stackTrace: StackTrace.current);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('isGuest', true); // Reset to guest on logout
    await prefs.remove('email');
    await prefs.remove('phone');
    await prefs.remove('role');
    await prefs.remove('user_name');
    await prefs.remove('uid');

    await FirebaseAuth.instance.signOut();

    developer.log('User logged out, preferences reset');
    developer.log('isLoggedIn: ${prefs.getBool('isLoggedIn')}');
    developer.log('isGuest: ${prefs.getBool('isGuest')}');
  }

  void _showVerificationPopup(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Account Not Verified"),
        content: const Text(
            "Your account is not verified. Please verify your email to continue."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () async {
              await _resendVerificationEmail(user, dialogContext);
            },
            child: const Text("Resend Verification Email"),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail(
      User user, BuildContext dialogContext) async {
    try {
      // Check if the user is still signed in
      if (FirebaseAuth.instance.currentUser == null) {
        _showToast("User session expired. Please log in again.", Colors.red);
        Navigator.pop(dialogContext); // Close the dialog
        return;
      }

      // Check for cooldown period (e.g., 1 minute between requests)
      if (_lastVerificationEmailSent != null) {
        final timeSinceLastSent =
            DateTime.now().difference(_lastVerificationEmailSent!);
        if (timeSinceLastSent.inSeconds < 60) {
          _showToast(
              "Please wait ${60 - timeSinceLastSent.inSeconds} seconds before resending.",
              Colors.red);
          Navigator.pop(dialogContext); // Close the dialog even on cooldown
          return;
        }
      }

      // Refresh the user to ensure the latest state
      await user.reload();
      user = FirebaseAuth.instance.currentUser!;

      // Send the verification email
      await user.sendEmailVerification();
      _lastVerificationEmailSent = DateTime.now(); // Update the last sent time
      _showToast("Verification email sent!", Colors.green);
      Navigator.pop(dialogContext); // Close the dialog after success
    } catch (e) {
      // Provide more specific error messages based on the exception
      String errorMessage;
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'too-many-requests':
            errorMessage =
                "Too many requests. Please wait a few minutes before trying again.";
            break;
          case 'network-request-failed':
            errorMessage = "Network error. Please check your connection.";
            break;
          default:
            errorMessage = "Failed to resend verification email: ${e.message}";
        }
      } else {
        errorMessage = "Failed to resend verification email: $e";
      }
      _showToast(errorMessage, Colors.red);
      developer.log("Error resending verification email: $e",
          stackTrace: StackTrace.current);
      Navigator.pop(dialogContext); // Close the dialog after error
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
    developer.log('Auth error: ${e.code} - $message');
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG, // Increase duration for better visibility
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
      resizeToAvoidBottomInset:
          true, // Enable resizing to avoid keyboard overlap
      body: Stack(
        fit: StackFit.expand, // Ensure the stack fills the entire screen
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/mpkv.png'),
                fit: BoxFit.cover, // Ensure the image covers the entire screen
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _navigateToLoginLanding,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                          style: const TextStyle(color: Colors.black),
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
                          style: const TextStyle(color: Colors.black),
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
          ),
        ],
      ),
    );
  }
}
