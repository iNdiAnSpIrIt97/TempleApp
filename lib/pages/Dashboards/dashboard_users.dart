import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:temple_app/pages/login/login_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  String _bannerUrl = "";

  @override
  void initState() {
    super.initState();
    _fetchBannerUrl();
  }

  Future<void> _fetchBannerUrl() async {
    DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('banner').doc('image').get();
    if (snapshot.exists) {
      setState(() {
        _bannerUrl = snapshot['url'];
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout"),
        content: Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  Widget _buildBanner() {
    return Stack(
      children: [
        ClipPath(
          clipper: BannerClipper(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              image: _bannerUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_bannerUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.grey[300],
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Icon(Icons.notifications, size: 30, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMenuGrid() {
    List<Map<String, dynamic>> menuItems = [
      {'icon': Icons.favorite, 'label': 'Donations'},
      {'icon': Icons.local_fire_department, 'label': 'Vazhipaadu'},
      {'icon': Icons.event, 'label': 'Events'},
      {'icon': Icons.store, 'label': 'Store'},
      {'icon': Icons.calendar_today, 'label': 'Special Days'},
      {'icon': Icons.book_online, 'label': 'Bookings'},
    ];

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade100,
              ),
              child:
                  Icon(menuItems[index]['icon'], size: 32, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text(menuItems[index]['label']),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("User Dashboard"),
        actions: [
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          _buildBanner(),
          Expanded(child: _buildMenuGrid()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "Bookings"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "Settings"),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: "Cart"),
        ],
      ),
    );
  }
}

class BannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
