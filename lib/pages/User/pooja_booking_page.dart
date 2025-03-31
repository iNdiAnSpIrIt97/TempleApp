import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../config/razorpay_config.dart';
import 'dart:developer' as developer;

class PoojaBookingPage extends StatefulWidget {
  final String poojaId;
  final DateTime selectedDate;
  final String title;
  final int amount;

  const PoojaBookingPage({
    required this.poojaId,
    required this.selectedDate,
    required this.title,
    required this.amount,
    super.key,
  });

  @override
  _PoojaBookingPageState createState() => _PoojaBookingPageState();
}

class _PoojaBookingPageState extends State<PoojaBookingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Razorpay _razorpay;
  List<Map<String, String>> _participants = [
    {'name': '', 'star': ''}
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _saveBooking(response.paymentId!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Successful: ${response.paymentId}')),
    );
    Navigator.popUntil(
        context, (route) => route.isFirst); // Return to the initial screen
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    developer.log('Payment failed: ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    developer.log('External wallet used: ${response.walletName}');
  }

  Future<void> _saveBooking(String paymentId) async {
    final bookingData = {
      'poojaId': widget.poojaId,
      'title': widget.title,
      'amount': widget.amount,
      'selectedDate': Timestamp.fromDate(widget.selectedDate),
      'paymentId': paymentId,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': _auth.currentUser?.uid,
      'participants': _participants,
    };

    try {
      // Save to global pooja_bookings collection
      final globalRef =
          await _firestore.collection('pooja_bookings').add(bookingData);
      developer.log('Saved to global pooja_bookings with ID: ${globalRef.id}');

      // Save to user's pooja_booking subcollection
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('pooja_booking')
            .doc(globalRef.id)
            .set({
          ...bookingData,
          'bookingId': globalRef.id,
        });
        developer.log(
            'Saved to user\'s pooja_booking subcollection with ID: ${globalRef.id}');
      }

      // Update booked_dates in pooja_list
      await _firestore.collection('pooja_list').doc(widget.poojaId).update({
        'booked_dates':
            FieldValue.arrayUnion([widget.selectedDate.toIso8601String()])
      });
    } catch (e) {
      developer.log('Error saving booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving booking: $e')),
      );
    }
  }

  void _addParticipant() {
    if (_participants.length < 5) {
      setState(() {
        _participants.add({'name': '', 'star': ''});
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 participants allowed.')),
      );
    }
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants.removeAt(index);
    });
  }

  void _initiatePayment() {
    var options = {
      'key': Config.razorpayKey,
      'amount': widget.amount * 100, // Convert to paise
      'currency': 'INR',
      'name': widget.title,
      'description': 'Pooja Booking',
      'prefill': {
        'contact': _auth.currentUser?.phoneNumber ?? '1234567890',
        'email': _auth.currentUser?.email ?? 'test@example.com',
      },
      'theme': {'color': '#F37254'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      developer.log('Error initiating payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating payment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Participant Details'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _participants[index]['name'] = value;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Star (Nakshatra)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _participants[index]['star'] = value;
                            },
                          ),
                          if (index > 0)
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () => _removeParticipant(index),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _participants.length < 5 ? _addParticipant : null,
              child: const Text('Add Participant'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_participants.every(
                    (p) => p['name']!.isNotEmpty && p['star']!.isNotEmpty)) {
                  _initiatePayment();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all participant details.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Proceed to Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
