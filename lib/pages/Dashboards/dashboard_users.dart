import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:temple_app/pages/Admin/update_offerings.dart';
import 'package:temple_app/pages/Login/login_landing.dart';
import 'package:temple_app/pages/User/bookings_page.dart';
import 'package:temple_app/pages/User/contact_us_page.dart';
import 'package:temple_app/pages/User/donations_page.dart';
import 'package:temple_app/pages/User/events_page.dart';
import 'package:temple_app/pages/User/my_booking_page.dart';
import 'package:temple_app/pages/User/offerings_page.dart';
import 'package:temple_app/pages/User/pooja_booking_page.dart';
import 'package:temple_app/pages/User/pooja_list_page.dart';
import 'package:temple_app/pages/profile_page.dart';
import 'package:temple_app/pages/User/store_home_page.dart';
import 'package:temple_app/pages/User/store_page.dart';
import 'package:temple_app/pages/admin/store_management.dart';
import 'package:temple_app/constants.dart';

class UserDashboardContent extends StatefulWidget {
  const UserDashboardContent({super.key});

  @override
  State<UserDashboardContent> createState() => _UserDashboardContentState();
}

class _UserDashboardContentState extends State<UserDashboardContent> {
  int _currentBannerIndex = 0;
  List<String> _bannerUrls = [];
  bool _isLoading = true;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _fetchBannerUrls();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isGuest = user == null || user.isAnonymous;
    });
  }

  Future<void> _fetchBannerUrls() async {
    try {
      var snapshot =
          await FirebaseFirestore.instance.collection('banner').get();
      if (!mounted) return;
      List<String> urls = snapshot.docs
          .map((doc) => doc['url'] as String? ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
      setState(() {
        _bannerUrls = urls;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching banner URLs: $e");
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBanner() {
    double bannerHeight = MediaQuery.of(context).size.height * 0.35;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: bannerHeight,
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.darkCardBackground
            : AppColors.lightCardBackground,
      ),
      child: Stack(
        children: [
          _isLoading
              ? Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    height: bannerHeight,
                    color: Colors.grey[300],
                  ),
                )
              : _bannerUrls.isNotEmpty
                  ? CarouselSlider(
                      options: CarouselOptions(
                        height: bannerHeight,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 4),
                        enlargeCenterPage: true,
                        viewportFraction: 1.0,
                        onPageChanged: (index, reason) {
                          if (mounted)
                            setState(() => _currentBannerIndex = index);
                        },
                      ),
                      items: _bannerUrls.map((url) {
                        return ClipRRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                url,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  (loadingProgress
                                                          .expectedTotalBytes ??
                                                      1)
                                              : null,
                                    ),
                                  );
                                },
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.2),
                                      Colors.black.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : Container(
                      height: bannerHeight,
                      color: isDarkMode
                          ? AppColors.darkCardBackground
                          : AppColors.lightCardBackground,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported,
                                size: 40, color: Colors.grey[600]),
                            const SizedBox(height: 10),
                            Text(
                              "No Banners Available",
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                decoration: TextDecoration.none,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _fetchBannerUrls(),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Retry",
                                  style: GoogleFonts.poppins(
                                    color: isDarkMode
                                        ? AppColors.darkAccent
                                        : AppColors.lightAccent,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: isDarkMode
                          ? AppColors.darkIcons
                          : AppColors.lightIcons,
                      size: 28,
                    ),
                    onPressed: _handleBackOrLogout,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.notifications,
                      color: isDarkMode
                          ? AppColors.darkIcons
                          : AppColors.lightIcons,
                      size: 28,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Notifications coming soon")),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_bannerUrls.isNotEmpty)
            Positioned(
              bottom: 15,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_bannerUrls.length, (index) {
                  return Container(
                    width: _currentBannerIndex == index ? 10 : 8,
                    height: _currentBannerIndex == index ? 10 : 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentBannerIndex == index
                          ? (isDarkMode
                              ? AppColors.darkAccent
                              : AppColors.lightAccent)
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.darkCardBackground
            : AppColors.lightCardBackground,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? AppColors.darkShadow : AppColors.lightShadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  isDarkMode ? AppColors.darkAccent : AppColors.lightAccent,
                  Colors.deepOrange
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDarkMode
                  ? AppColors.darkCardBackground
                  : AppColors.lightCardBackground,
              child: Text(
                "U",
                style: GoogleFonts.poppins(
                  color:
                      isDarkMode ? AppColors.darkAccent : AppColors.lightAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Namaste, Devotee!",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color:
                        isDarkMode ? AppColors.darkText : AppColors.lightText,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  "Your spiritual journey continues",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTiles() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.volunteer_activism_rounded,
        'title': 'Offerings',
        'color': Colors.redAccent,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CustomerOfferingsPage())),
      },
      {
        'icon': Icons.hotel,
        'title': 'Room Bookings',
        'color': Colors.blueAccent,
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BookingPage())),
      },
      {
        'icon': Icons.event,
        'title': 'Events',
        'color': isDarkMode ? AppColors.darkAccent : AppColors.lightAccent,
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => EventsPage())),
      },
      {
        'icon': Icons.shopping_bag,
        'title': 'Store',
        'color': Colors.purpleAccent,
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StoreHomePage())),
      },
      {
        'icon': Icons.local_florist,
        'title': 'Pooja Booking',
        'color': Colors.orange,
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => PoojaListPage())),
      },
      {
        'icon': Icons.money,
        'title': 'Donations',
        'color': Colors.green,
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const DonationPage())),
      },
      if (_isGuest)
        {
          'icon': Icons.support_agent,
          'title': 'Contact Us',
          'color': Colors.teal,
          'onTap': () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ContactUsPage())),
        }
      else
        {
          'icon': Icons.contact_mail,
          'title': 'My Bookings',
          'color': Colors.teal,
          'onTap': () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyBookingsPage())),
        },
      {
        'icon': Icons.person,
        'title': 'Profile',
        'color': Colors.indigo,
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => SettingsPage())),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 14,
          childAspectRatio: 1.2,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: menuItems[index]['onTap'],
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    menuItems[index]['color'].withOpacity(0.9),
                    menuItems[index]['color'].withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -10,
                    right: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            menuItems[index]['icon'],
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          menuItems[index]['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _logout() async {
    bool confirmLogout = await _showLogoutConfirmationDialog();
    if (confirmLogout) {
      await FirebaseAuth.instance.signOut();
      await _clearSharedPreferences();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginLanding()),
        (route) => false,
      );
    }
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

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Exit"),
            content: const Text("Are you sure you want to exit?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Exit", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _handleBackOrLogout() {
    if (_isGuest) {
      _handleExit();
    } else {
      _logout();
    }
  }

  void _handleExit() async {
    bool confirmExit = await _showExitConfirmationDialog();
    if (confirmExit) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginLanding()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_isGuest) {
          _handleExit();
        } else {
          _logout();
        }
        return false;
      },
      child: Container(
        color:
            isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        child: RefreshIndicator(
          color: isDarkMode ? AppColors.darkAccent : AppColors.lightAccent,
          onRefresh: _fetchBannerUrls,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBanner(),
                _buildUserHeader(),
                _buildMenuTiles(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
