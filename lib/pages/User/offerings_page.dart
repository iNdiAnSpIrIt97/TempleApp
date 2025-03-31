import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'vazhipaadu_booking.dart';

class CustomerOfferingsPage extends StatefulWidget {
  const CustomerOfferingsPage({super.key});

  @override
  State<CustomerOfferingsPage> createState() => _CustomerOfferingsPageState();
}

class _CustomerOfferingsPageState extends State<CustomerOfferingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedDeity = 'All';
  bool _isGuest = false;

  final List<String> _deities = [
    'All',
    'Devi',
    'Ganesha',
    'Ayyappa',
    'Nagas',
    'Bhairavaa'
  ];

  Stream<QuerySnapshot> _getOfferingsStream(String? deity) {
    Query query = _firestore.collection('offerings');
    if (deity != null && deity != 'All') {
      query = query.where('deity', isEqualTo: deity);
    }
    return query.snapshots();
  }

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      // If user is null or signed in anonymously, consider them a guest
      _isGuest = user == null || user.isAnonymous;
    });
  }

  // Add method to show login required dialog
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to book offerings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // You can add navigation to login page here if you have one
              // For example:
              // Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage()));
            },
            child: const Text("Login", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Temple Offerings"),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: _deities.map((deity) {
                bool isSelected = _selectedDeity == deity;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSelected ? Colors.blue : Colors.grey.shade300,
                      foregroundColor:
                          isSelected ? Colors.white : Colors.black87,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDeity = deity;
                      });
                    },
                    child: Text(deity),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _getOfferingsStream(
                  _selectedDeity == 'All' ? null : _selectedDeity),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No offerings available"));
                }

                var offerings = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: offerings.length,
                  itemBuilder: (context, index) {
                    var offering = offerings[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(offering['name']),
                        subtitle: Text(
                            "₹${offering['amount']} - ${offering['deity']}"),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          if (_isGuest) {
                            _showLoginRequiredDialog();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VazhipaaduBookingPage(
                                  offeringId: offering.id,
                                  offeringName: offering['name'],
                                  offeringAmount:
                                      double.parse(offering['amount']),
                                  deity: offering['deity'],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
