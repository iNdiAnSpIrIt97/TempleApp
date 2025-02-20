import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:temple_app/pages/Dashboards/dashboard_admin.dart';
import 'package:temple_app/pages/Dashboards/dashboard_users.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> login(
      String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        await _checkUserRole(user.uid, context);
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> _checkUserRole(String uid, BuildContext context) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      String role = userDoc['role'];
      if (role == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => AdminDashboard()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => UserDashboard()));
      }
    }
  }
}
