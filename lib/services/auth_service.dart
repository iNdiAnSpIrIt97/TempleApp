import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:temple_app/pages/Dashboards/dashboard_admin.dart';
import 'package:temple_app/pages/Dashboards/dashboard_users.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Login method (unchanged)
  Future<void> login(
      String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        if (!user.emailVerified) {
          _showVerificationPopup(user, context);
          return;
        }
        await _checkUserRole(user.uid, context);
      }
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      throw Exception("An unexpected error occurred. Please try again.");
    }
  }

  // New SignUp method
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e; // Let the caller handle specific Firebase errors
    } catch (e) {
      throw Exception("An unexpected error occurred during registration.");
    }
  }

  /// Show a popup to inform the user to verify their email
  void _showVerificationPopup(User user, BuildContext context) {
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
            onPressed: () => _resendVerificationEmail(user, context),
            child: const Text("Resend Verification Email"),
          ),
        ],
      ),
    );
  }

  /// Resend verification email
  Future<void> _resendVerificationEmail(User user, BuildContext context) async {
    try {
      await user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification email sent!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to resend verification email: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkUserRole(String uid, BuildContext context) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw FirebaseAuthException(
          code: "role-not-found",
          message: "User role not found. Please contact support.",
        );
      }

      String role = userDoc['role'];
      if (role == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => AdminDashboard()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => UserDashboardContent()));
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: "role-fetch-error",
        message: "Failed to retrieve user role. Please try again.",
      );
    }
  }
}
