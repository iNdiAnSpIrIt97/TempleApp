import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/config/razorpay_config.dart';

class VazhipaaduBookingPage extends StatefulWidget {
  final String offeringId;
  final String offeringName;
  final double offeringAmount;
  final String deity;

  const VazhipaaduBookingPage({
    super.key,
    required this.offeringId,
    required this.offeringName,
    required this.offeringAmount,
    required this.deity,
  });

  @override
  State<VazhipaaduBookingPage> createState() => _VazhipaaduBookingPageState();
}

class _VazhipaaduBookingPageState extends State<VazhipaaduBookingPage> {
  final _formKey = GlobalKey<FormState>();
  int _quantity = 1;
  late Razorpay _razorpay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<TextEditingController> _nameControllers = [TextEditingController()];
  List<TextEditingController> _starControllers = [TextEditingController()];
  final int _maxQuantity = 10;

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
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    for (var controller in _starControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateControllers() {
    int currentLength = _nameControllers.length;
    if (_quantity > currentLength) {
      for (int i = currentLength; i < _quantity; i++) {
        _nameControllers.add(TextEditingController());
        _starControllers.add(TextEditingController());
      }
    } else if (_quantity < currentLength) {
      for (int i = currentLength - 1; i >= _quantity; i--) {
        _nameControllers[i].dispose();
        _starControllers[i].dispose();
        _nameControllers.removeAt(i);
        _starControllers.removeAt(i);
      }
    }
  }

  Future<bool> _isGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    // Assuming you store guest status as a boolean with key 'isGuest'
    // Return true if guest, false if not guest
    return prefs.getBool('isGuest') ?? true; // Default to true if not set
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    List<Map<String, String>> participants = [];
    for (int i = 0; i < _quantity; i++) {
      participants.add({
        'name': _nameControllers[i].text,
        'star': _starControllers[i].text,
      });
    }

    final bookingData = {
      'offeringId': widget.offeringId,
      'offeringName': widget.offeringName,
      'amount': widget.offeringAmount * _quantity,
      'quantity': _quantity,
      'deity': widget.deity,
      'participants': participants,
      'paymentId': response.paymentId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    bool isGuest = await _isGuestUser();

    if (isGuest) {
      // Guest booking
      await _firestore.collection('offering_bookings').add({
        ...bookingData,
        'isGuest': true,
      });
    } else {
      // Non-guest user booking
      if (_auth.currentUser != null) {
        // First, add to user's pooja_booking subcollection
        final poojaBookingRef = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('offering_booking')
            .add({
          ...bookingData,
          'userId': _auth.currentUser!.uid,
        });

        // Then add to offering_bookings with the pooja_booking ID
        await _firestore.collection('offering_bookings').add({
          ...bookingData,
          'isGuest': false,
          'userId': _auth.currentUser!.uid,
          'poojaBookingId':
              poojaBookingRef.id, // Store the subcollection booking ID
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Booking successful!")),
    );
    Navigator.pop(context);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _initiatePayment() {
    int amountInPaise = (widget.offeringAmount * _quantity * 100).toInt();

    var options = {
      'key': Config.razorpayKey,
      'amount': amountInPaise,
      'name': widget.offeringName,
      'description': 'Offering to ${widget.deity}',
      'prefill': {
        'contact': _auth.currentUser?.phoneNumber ?? '',
        'email': _auth.currentUser?.email ?? '',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.offeringName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Deity: ${widget.deity}",
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Quantity:"),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1
                            ? () {
                                setState(() {
                                  _quantity--;
                                  _updateControllers();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text("$_quantity"),
                      IconButton(
                        onPressed: _quantity < _maxQuantity
                            ? () {
                                setState(() {
                                  _quantity++;
                                  _updateControllers();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _quantity,
                  itemBuilder: (context, index) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Participant ${index + 1}"),
                        TextFormField(
                          controller: _nameControllers[index],
                          decoration: const InputDecoration(labelText: "Name"),
                          validator: (value) =>
                              value!.isEmpty ? "Required" : null,
                        ),
                        TextFormField(
                          controller: _starControllers[index],
                          decoration:
                              const InputDecoration(labelText: "Star of Birth"),
                          validator: (value) =>
                              value!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
              Text(
                "Total Amount: ₹${(widget.offeringAmount * _quantity).toStringAsFixed(2)}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _initiatePayment();
                    }
                  },
                  child: const Text("Proceed to Pay"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
