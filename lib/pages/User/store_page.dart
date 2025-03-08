import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temple_app/pages/Login/login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: GoogleFonts.poppins()),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (user != null) ...[
              CircleAvatar(
                radius: 40,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : AssetImage("assets/default_profile.png") as ImageProvider,
              ),
              SizedBox(height: 10),
              Text(
                user.displayName ?? "User Name",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(user.email ?? "No Email", style: GoogleFonts.poppins()),
              SizedBox(height: 20),
            ],
            ListTile(
              leading: Icon(Icons.edit, color: Colors.orangeAccent),
              title: Text("Edit Profile", style: GoogleFonts.poppins()),
              onTap: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => EditProfilePage()),
                // );
              },
            ),
            ListTile(
              leading: Icon(Icons.contact_mail, color: Colors.orangeAccent),
              title: Text("Contact Us", style: GoogleFonts.poppins()),
              onTap: () {
                // Implement Contact Us
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.redAccent),
              title: Text("Logout",
                  style: GoogleFonts.poppins(color: Colors.redAccent)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
