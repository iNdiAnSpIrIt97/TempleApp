import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
// import 'package:temple_app/pages/Admin/admin_notification_page.dart';
import 'package:temple_app/pages/Admin/customer_message_page.dart';
import 'package:temple_app/pages/Admin/event_page_admin.dart';
import 'package:temple_app/pages/Admin/profile_admin.dart';
import 'package:temple_app/pages/Admin/rooms/room_booking_admin.dart';
import 'package:temple_app/pages/Admin/update_offerings.dart';
import 'package:temple_app/pages/Admin/user_list.dart';
import 'package:temple_app/pages/Admin/view_donations.dart';
import 'package:temple_app/pages/Login/login_page.dart';
import 'package:temple_app/pages/admin/pooja_management.dart';
import 'package:temple_app/pages/admin/store_management.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<String> _bannerUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBannerUrls();
  }

  Future<void> _fetchBannerUrls() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('banner').get();

      List<String> urls = snapshot.docs
          .map((doc) => doc['url'] as String)
          .where((url) => url.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _bannerUrls = urls;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching banner URLs: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    bool confirmLogout = await _showLogoutConfirmationDialog();
    if (confirmLogout) {
      await FirebaseAuth.instance.signOut();
      await _clearSharedPreferences();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void settingsNav() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const AdminProfile()));
  }

  Future<void> _clearSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> _showLogoutConfirmationDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to logout?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text("Logout", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _onWillPop() async {
    bool confirmLogout = await _showLogoutConfirmationDialog();
    if (confirmLogout) {
      await FirebaseAuth.instance.signOut();
      await _clearSharedPreferences();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
    return false;
  }

  void _deleteBanner(String url) async {
    try {
      await FirebaseFirestore.instance
          .collection('banner')
          .where('url', isEqualTo: url)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });

      final storageRef = FirebaseStorage.instance.refFromURL(url);
      await storageRef.delete();

      setState(() {
        _bannerUrls.remove(url);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Banner deleted successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting banner: $e")),
      );
    }
  }

  Future<void> _uploadBanner() async {
    try {
      // Pick an image from the gallery
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        print("No image selected");
        return; // User canceled the picker
      }

      // Convert XFile to File
      final File imageFile = File(image.path);
      print("Image path: ${imageFile.path}");
      print("File exists: ${await imageFile.exists()}");

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading banner...")),
      );

      // Upload to Firebase Storage (without compression for now)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('banners/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(imageFile);
      final String downloadUrl = await storageRef.getDownloadURL();
      print("Download URL: $downloadUrl");

      // Save URL to Firestore
      await FirebaseFirestore.instance.collection('banner').add({
        'url': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        _bannerUrls.add(downloadUrl);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Banner uploaded successfully!")),
      );
    } catch (e) {
      print("Error in _uploadBanner: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading banner: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: settingsNav,
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _buildImageSlider(),
            const SizedBox(height: 20),
            Expanded(child: _buildModernList()),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider() {
    return SizedBox(
      height: 200,
      child: _isLoading
          ? _buildShimmerEffect()
          : (_bannerUrls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "No Banners Available",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _uploadBanner,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 40,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Add Banner",
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                )
              : CarouselSlider(
                  options: CarouselOptions(
                    height: 200,
                    autoPlay: true,
                    enlargeCenterPage: true,
                    aspectRatio: 16 / 9,
                    autoPlayInterval: const Duration(seconds: 3),
                  ),
                  items: [
                    ..._bannerUrls.map((url) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildShimmerEffect();
                              },
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _showBannerOptions(url),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    GestureDetector(
                      onTap: _uploadBanner,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add,
                            size: 40,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
    );
  }

  void _showBannerOptions(String url) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text("Delete Banner"),
            onTap: () {
              _deleteBanner(url);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text("Upload New Banner"),
            onTap: () {
              _uploadBanner();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildModernList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _dashboardItems.length,
      itemBuilder: (context, index) {
        final item = _dashboardItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildDashboardTile(item),
        );
      },
    );
  }

  Widget _buildDashboardTile(DashboardItem item) {
    return GestureDetector(
      onTap: () => _navigateTo(item.page),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              item.color.withOpacity(0.9),
              item.color.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}

class DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;

  DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.page,
  });
}

final List<DashboardItem> _dashboardItems = [
  DashboardItem(
      title: "User List",
      icon: Icons.people,
      color: Colors.blue,
      page: const UserListPage()),
  DashboardItem(
      title: "View Donations",
      icon: Icons.attach_money,
      color: Colors.green,
      page: const DonationsPage()),
  DashboardItem(
      title: "Update Offerings",
      icon: Icons.list,
      color: Colors.orange,
      page: const OfferingsPage()),
  DashboardItem(
      title: "Manage Events",
      icon: Icons.event,
      color: Colors.purple,
      page: const EventManagementPage()),
  DashboardItem(
      title: "Pooja Management",
      icon: Icons.temple_hindu,
      color: Colors.brown,
      page: const PoojaManagementPage()),
  DashboardItem(
      title: "Room Management",
      icon: Icons.hotel,
      color: Colors.teal,
      page: const RoomManagementPage()),
  DashboardItem(
      title: "Store Management",
      icon: Icons.store,
      color: Colors.deepOrange,
      page: const StoreManagementPage()),
  DashboardItem(
      title: "Messages",
      icon: Icons.message,
      color: Colors.pink,
      page: const CustomerMessagePage()),
  // DashboardItem(
  //     title: "Notification",
  //     icon: Icons.notification_add,
  //     color: const Color.fromARGB(255, 5, 207, 150),
  //     page: const AdminNotificationsPage()),
];
