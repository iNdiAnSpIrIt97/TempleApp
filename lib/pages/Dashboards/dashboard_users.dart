import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:temple_app/pages/User/bookings_page.dart';
import 'package:temple_app/pages/User/donations_page.dart';
import 'package:temple_app/pages/User/store_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const UserDashboardContent(),
    const BookingPage(),
    const SettingsPage(),
    const Scaffold(body: Center(child: Text("Cart Page"))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
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

class UserDashboardContent extends StatefulWidget {
  const UserDashboardContent({super.key});

  @override
  State<UserDashboardContent> createState() => _UserDashboardContentState();
}

class _UserDashboardContentState extends State<UserDashboardContent> {
  int _currentBannerIndex = 0;
  List<String> _bannerUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchBannerUrls());
  }

  Future<void> _fetchBannerUrls() async {
    try {
      var snapshot =
          await FirebaseFirestore.instance.collection('banner').get();

      if (!mounted) return; // Prevent setState on unmounted widget

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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildBanner() {
    double bannerHeight = MediaQuery.of(context).size.height * 0.55;

    return Stack(
      children: [
        // Banner Carousel
        _isLoading
            ? Container(
                height: bannerHeight,
                width: double.infinity,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    color: Colors.grey[300],
                  ),
                ),
              )
            : _bannerUrls.isNotEmpty
                ? CarouselSlider(
                    options: CarouselOptions(
                      height: bannerHeight,
                      autoPlay: true,
                      enlargeCenterPage: true,
                      viewportFraction: 1.0,
                      onPageChanged: (index, reason) {
                        if (mounted) {
                          setState(() {
                            _currentBannerIndex = index;
                          });
                        }
                      },
                    ),
                    items: _bannerUrls.map((url) {
                      return Container(
                        height: bannerHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(url),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Container(
                    height: bannerHeight,
                    color: Colors.black12,
                    child: const Center(
                      child: Text(
                        "No Banners Available",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),

        // Notification Icon
        Positioned(
          top: 20,
          right: 20,
          child: IconButton(
            icon:
                const Icon(Icons.notifications, color: Colors.white, size: 40),
            onPressed: () {
              // Handle notification click
            },
          ),
        ),

        // Dots Indicator
        if (_bannerUrls.isNotEmpty)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_bannerUrls.length, (index) {
                return Container(
                  width: _currentBannerIndex == index ? 12.0 : 8.0,
                  height: _currentBannerIndex == index ? 12.0 : 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentBannerIndex == index
                        ? Colors.orangeAccent
                        : Colors.black,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuGrid() {
    List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.money,
        'label': 'Donations',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DonationPage()),
          );
        },
      },
      {
        'icon': Icons.book_online,
        'label': 'Bookings',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookingPage()),
          );
        },
      },
      {'icon': Icons.festival, 'label': 'Events'},
      {'icon': Icons.store, 'label': 'Store'},
      {'icon': Icons.calendar_today, 'label': 'Special Days'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 30,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: menuItems[index]['onTap'],
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: const LinearGradient(
                colors: [Color(0xFFD55959), Color(0xFFAC530A)],
              ),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 5, offset: Offset(3, 3)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(menuItems[index]['icon'], size: 20, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  menuItems[index]['label'],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBanner(),
          const SizedBox(height: 20),
          _buildMenuGrid(),
        ],
      ),
    );
  }
}
