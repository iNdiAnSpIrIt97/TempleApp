import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:temple_app/config/razorpay_config.dart';
import 'dart:developer' as developer;

import 'package:temple_app/pages/User/address_edit_page.dart';

class AddAddressPage extends StatefulWidget {
  final List<QueryDocumentSnapshot> cartItems;
  final double totalAmount;

  const AddAddressPage(
      {super.key, required this.cartItems, required this.totalAmount});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Razorpay _razorpay;
  List<String> _addresses = [];
  String? _selectedAddress;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchAddresses();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchAddresses() async {
    String userId = _auth.currentUser!.uid;
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    setState(() {
      _addresses = List<String>.from(userDoc['saved_addresses'] ?? []);
      if (_addresses.isNotEmpty) {
        _selectedAddress = _addresses.first; // Auto-select the first address
      }
    });
  }

  Future<void> _removeAddress(String address) async {
    String userId = _auth.currentUser!.uid;
    DocumentReference userRef = _firestore.collection('users').doc(userId);

    await userRef.update({
      'saved_addresses': FieldValue.arrayRemove([address]),
    });

    setState(() {
      _addresses.remove(address);
      if (_selectedAddress == address) {
        _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
      }
    });
  }

  void _initiatePayment() {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an address')),
      );
      return;
    }

    int amountInPaise = (widget.totalAmount * 100).toInt();

    var options = {
      'key': Config.razorpayKey,
      'amount': amountInPaise,
      'name': 'Store Purchase',
      'description': 'Payment for cart items',
      'prefill': {
        'contact': _auth.currentUser?.phoneNumber ?? '',
        'email': _auth.currentUser?.email ?? '',
      }
    };

    try {
      _razorpay.open(options);
      developer.log('Payment initiated for amount: $amountInPaise paise');
    } catch (e) {
      developer.log('Payment initiation error: $e',
          stackTrace: StackTrace.current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating payment: $e')),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    developer.log('Payment successful: ${response.paymentId}');
    setState(() {
      _isLoading = true;
    });

    String userId = _auth.currentUser!.uid;
    List<String> bookingIds = [];

    try {
      // Process each cart item and create bookings
      for (var cartItem in widget.cartItems) {
        final itemData = cartItem.data() as Map<String, dynamic>;
        final itemId = itemData['item_id'] as String;
        developer.log('Processing cart item: $itemId');

        final bookingData = {
          'item_id': itemId,
          'item_name': itemData['item_name'],
          'quantity': itemData['quantity'],
          'total_amount': itemData['price'] * (itemData['quantity'] as int),
          'payment_id': response.paymentId,
          'purchase_date': Timestamp.now(),
          'status': 'completed',
          'user_id': userId,
          'address': _selectedAddress,
        };

        // Save to store_bookings collection
        final bookingRef =
            await _firestore.collection('store_bookings').add(bookingData);
        bookingIds.add(bookingRef.id);
        developer.log('Store booking created with ID: ${bookingRef.id}');

        // Save to user's store_bookings subcollection
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('store_bookings')
            .doc(bookingRef.id)
            .set({
          ...bookingData,
          'booking_id': bookingRef.id,
        });
        developer.log(
            'Saved to user\'s store_bookings subcollection with ID: ${bookingRef.id}');

        // Update store quantity
        final storeDoc = await _firestore.collection('store').doc(itemId).get();
        int currentQuantity = int.parse(storeDoc['quantity'] ?? '0');
        int purchasedQuantity = itemData['quantity'] as int;
        if (currentQuantity >= purchasedQuantity) {
          await _firestore.collection('store').doc(itemId).update({
            'quantity': (currentQuantity - purchasedQuantity).toString(),
          });
          developer.log(
              'Store quantity updated to ${(currentQuantity - purchasedQuantity).toString()} for item: $itemId');
        } else {
          developer.log('Insufficient quantity in store for item: $itemId');
          throw Exception('Insufficient quantity in store for item: $itemId');
        }
      }

      // Clear the cart after all bookings are created
      QuerySnapshot cartSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .get();
      for (var doc in cartSnapshot.docs) {
        developer.log('Deleting cart item with ID: ${doc.id}');
        await doc.reference.delete();
      }
      developer.log('Cart cleared for user: $userId');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Purchase successful! Cart cleared. Booking IDs: ${bookingIds.join(", ")}')),
      );

      // Navigate back to the previous screen (e.g., StorePurchasePage)
      Navigator.pop(context);
    } catch (e) {
      developer.log('Error saving booking or clearing cart: $e',
          stackTrace: StackTrace.current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing purchase: $e')),
      );
      // Roll back bookings if an error occurs
      for (var bookingId in bookingIds) {
        await _firestore.collection('store_bookings').doc(bookingId).delete();
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('store_bookings')
            .doc(bookingId)
            .delete();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    developer.log('Payment failed: ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    developer.log('External wallet used: ${response.walletName}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Address")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                // Add Address Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddressEditPage(
                            address: null, // For adding a new address
                            onRemove: _removeAddress,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Address"),
                  ),
                ),

                // Address List with Radio Buttons
                Expanded(
                  child: _addresses.isEmpty
                      ? Center(child: Text("No saved addresses."))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _addresses.length,
                          itemBuilder: (context, index) {
                            String address = _addresses[index];

                            return Card(
                              child: ListTile(
                                title: Text(address),
                                leading: Radio<String>(
                                  value: address,
                                  groupValue: _selectedAddress,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAddress = value;
                                    });
                                  },
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddressEditPage(
                                          address: address,
                                          onRemove: _removeAddress,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Proceed to Payment Button
                if (_addresses.isNotEmpty && _selectedAddress != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _initiatePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: Text(
                        'Proceed to Payment',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
