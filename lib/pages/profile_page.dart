import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/pages/Login/login_page.dart';
import 'package:temple_app/pages/User/contact_us_page.dart';
import 'package:temple_app/pages/privacy_policy.dart';
import 'package:temple_app/pages/terms_and_conditions.dart';
import 'dart:io';

import 'package:temple_app/provider/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String userRole = "guest";
  String userName = "Guest User";
  String appVersion = "Fetching...";

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _fetchAppVersion();
  }

  Future<void> _loadUserPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString("role") ?? "guest";
      userName = prefs.getString("user_name") ?? "Guest User";
    });
  }

  Future<void> _fetchAppVersion() async {
    String platform = Platform.isAndroid ? "android" : "iOS";
    try {
      DocumentSnapshot versionSnapshot = await FirebaseFirestore.instance
          .collection("version")
          .doc(platform)
          .get();

      if (versionSnapshot.exists) {
        setState(() {
          appVersion = "Version ${versionSnapshot.get("version")}";
        });
      } else {
        setState(() {
          appVersion = "Version not found";
        });
      }
    } catch (e) {
      setState(() {
        appVersion = "Error fetching version";
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    String firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : "?";

    return Scaffold(
      appBar: AppBar(
        title: Text("Profile", style: GoogleFonts.poppins()),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Picture & Name
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.orangeAccent,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            firstLetter,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Namasthe $userName",
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(user?.email ?? " ", style: GoogleFonts.poppins()),
                  const SizedBox(height: 20),

                  // Dark Mode Toggle
                  ListTile(
                    leading:
                        const Icon(Icons.dark_mode, color: Colors.orangeAccent),
                    title: Text("Dark Mode", style: GoogleFonts.poppins()),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme(value);
                      },
                    ),
                  ),

                  // Contact Us
                  ListTile(
                    leading: const Icon(Icons.contact_mail,
                        color: Colors.blueAccent),
                    title: Text("Contact Us", style: GoogleFonts.poppins()),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ContactUsPage(), // Navigate to ContactUsPage
                        ),
                      );
                    },
                  ),

                  // Terms & Conditions
                  ListTile(
                    leading: const Icon(Icons.article, color: Colors.green),
                    title: Text("Terms & Conditions",
                        style: GoogleFonts.poppins()),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => TermsAndConditionsPage()));
                    },
                  ),

                  // Privacy Policy
                  ListTile(
                    leading:
                        const Icon(Icons.privacy_tip, color: Colors.purple),
                    title: Text("Privacy Policy", style: GoogleFonts.poppins()),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrivacyPolicyPage()));
                    },
                  ),

                  // Logout (Only for logged-in users)
                  if (userRole != "guest") ...[
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Colors.redAccent),
                      title: Text("Logout",
                          style: GoogleFonts.poppins(color: Colors.redAccent)),
                      onTap: _logout,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Copyright & App Version - Aligned Center
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  "© 2025 Manapullikavu Bhagavathi Temple",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: themeProvider.isDarkMode
                        ? Colors.white70
                        : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Under Malabar Devasom Board",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: themeProvider.isDarkMode
                        ? Colors.white70
                        : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  appVersion,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.orangeAccent
                        : Colors.deepOrange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
