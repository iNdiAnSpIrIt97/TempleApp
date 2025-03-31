import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/razorpay_config.dart';
import 'dart:developer' as developer;

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  _DonationPageState createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  late Razorpay _razorpay;
  final TextEditingController _customAmountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  String? _userEmail;
  String? _userName;
  bool _guestUser = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkUserStatus();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool? isGuest = prefs.getBool('isGuest');
    _userId = prefs.getString('uid');

    setState(() {
      _guestUser = isGuest ?? true;
    });

    if (_auth.currentUser != null) {
      setState(() {
        _userId = _auth.currentUser!.uid;
        _userEmail = _auth.currentUser!.email ?? 'N/A';
        _userName = _auth.currentUser!.displayName ?? 'User';
        _guestUser = false;
      });
    } else if (_userId != null) {
      setState(() {
        _userEmail = 'guest@example.com';
        _userName = 'Guest User';
      });
    } else {
      setState(() {
        _userEmail = 'N/A';
        _userName = 'Anonymous';
      });
    }

    developer.log('User status check:');
    developer.log('isGuest: $_guestUser');
    developer.log('User ID: $_userId');
    developer.log('Firebase currentUser: ${_auth.currentUser?.uid}');
  }

  void openCheckout(int amount, String donationType) {
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Amount must be greater than 0")),
      );
      return;
    }

    var options = {
      'key': Config.razorpayKey,
      'amount': amount * 100, // Convert to paise
      'currency': 'INR',
      'name': 'Donation',
      'description': donationType,
      'prefill': {
        'contact': _auth.currentUser?.phoneNumber ?? '1234567890',
        'email': _userEmail ?? 'test@example.com',
      },
      'theme': {'color': '#F37254'},
    };

    try {
      _razorpay.open(options);
      // Define the success handler here to capture amount and donationType
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
        _handlePaymentSuccess(response, amount, donationType);
      });
      developer
          .log('Initiating payment for amount: $amount, type: $donationType');
    } catch (e) {
      developer.log('Error initiating payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating payment: $e')),
      );
    }
  }

  void _handlePaymentSuccess(
      PaymentSuccessResponse response, int amount, String donationType) {
    int finalAmount = amount;
    String finalDonationType = donationType;

    // If custom amount was entered, override with it
    if (_customAmountController.text.isNotEmpty) {
      finalAmount = int.tryParse(_customAmountController.text) ?? amount;
      finalDonationType = "Custom Amount";
    }

    _saveDonation(response.paymentId!, finalDonationType, finalAmount);
    developer.log(
        'Payment success - Amount: $finalAmount, Type: $finalDonationType');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Successful: ${response.paymentId}")),
    );
    _customAmountController.clear(); // Clear the field after success
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    developer.log('Payment failed: ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    developer.log('External wallet used: ${response.walletName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet: ${response.walletName}")),
    );
  }

  Future<void> _saveDonation(
      String paymentId, String donationType, int amount) async {
    try {
      final donationData = {
        'paymentId': paymentId,
        'donationType': donationType,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': _userEmail,
        'userName': _userName,
        'userId': _userId,
      };

      final donationRef =
          await _firestore.collection('donations').add(donationData);
      developer.log(
          'Saved to global donations collection with ID: ${donationRef.id}');

      if (_userId != null) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('donations')
            .doc(donationRef.id)
            .set({
          ...donationData,
          'donationId': donationRef.id,
        });
        developer.log(
            'Saved to user\'s donations subcollection with ID: ${donationRef.id}');
      } else {
        developer
            .log('No user ID available, skipping user subcollection save.');
      }
    } catch (e) {
      developer.log('Error saving donation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving donation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Donations")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('donation_list')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No donation types available"));
                  }
                  var donations = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: donations.length,
                    itemBuilder: (context, index) {
                      var donation = donations[index];
                      return _buildDonationCard(
                        donation['Title'] ?? 'No Title',
                        'Amount: ₹${donation['Amount'] ?? '0'}',
                        int.tryParse(donation['Amount']?.toString() ?? '0') ??
                            0,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Other Amount (₹)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                int? customAmount = int.tryParse(_customAmountController.text);
                if (customAmount != null && customAmount > 0) {
                  openCheckout(customAmount, "Custom Amount");
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter a valid amount")),
                  );
                }
              },
              child: const Text("Donate Custom Amount",
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationCard(String title, String subtitle, int amount) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            Text(subtitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => openCheckout(amount, title),
          child: const Text("Donate", style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
