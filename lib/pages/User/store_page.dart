import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:temple_app/config/razorpay_config.dart';
import 'package:temple_app/pages/User/add_address.dart';
import 'package:temple_app/pages/User/cart_page.dart';

class StorePurchasePage extends StatefulWidget {
  final Map<String, dynamic> itemData;

  const StorePurchasePage({Key? key, required this.itemData}) : super(key: key);

  @override
  _StorePurchasePageState createState() => _StorePurchasePageState();
}

class _StorePurchasePageState extends State<StorePurchasePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Razorpay _razorpay;
  bool _isLoading = false;
  int _cartQuantity = 0;
  bool _guestUser = true;
  String? _userId;
  int _selectedImageIndex = 0; // To track the selected image index

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkGuestUser();
  }

  Future<void> _checkGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    bool? isGuest = prefs.getBool('isGuest');
    _userId = prefs.getString('uid');

    setState(() {
      _guestUser = isGuest ?? true;
    });

    developer.log('Guest status check:');
    developer.log('isGuest: $_guestUser');
    developer.log('User ID from SharedPrefs: $_userId');
    developer.log('Firebase currentUser: ${_auth.currentUser?.uid}');
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _addToCart() {
    if (_cartQuantity < 3) {
      setState(() {
        _cartQuantity++;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum 3 items per user')),
      );
    }
  }

  void _removeFromCart() {
    if (_cartQuantity > 0) {
      setState(() {
        _cartQuantity--;
      });
    }
  }

  Future<void> _addToCartCollection() async {
    if (_cartQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select quantity')),
      );
      return;
    }

    if (_guestUser) {
      _showLoginPrompt();
      return;
    }

    try {
      final cartData = {
        'item_id': widget.itemData['id'],
        'item_name': widget.itemData['name'],
        'quantity': _cartQuantity,
        'price': int.parse(widget.itemData['price']),
        'image': widget.itemData['images'][0],
        'added_at': Timestamp.now(),
      };

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .doc(widget.itemData['id'])
          .set(cartData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item added to cart')),
      );

      setState(() {
        _cartQuantity = 0;
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CartScreen()),
      );
    } catch (e) {
      developer.log('Error adding to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding to cart: $e')),
      );
    }
  }

  Future<void> _initiateBuyNow() async {
    if (_cartQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select quantity')),
      );
      return;
    }

    if (_guestUser) {
      _showLoginPrompt();
      return;
    }

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ID not available')),
      );
      return;
    }

    try {
      // Temporarily add the item to the cart collection
      final cartData = {
        'item_id': widget.itemData['id'],
        'item_name': widget.itemData['name'],
        'quantity': _cartQuantity,
        'price': int.parse(widget.itemData['price']),
        'image': widget.itemData['images'][0],
        'added_at': Timestamp.now(),
      };

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .doc(widget.itemData['id'])
          .set(cartData);

      // Fetch the item as a QueryDocumentSnapshot
      QuerySnapshot cartSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .where('item_id', isEqualTo: widget.itemData['id'])
          .get();

      if (cartSnapshot.docs.isEmpty) {
        throw Exception('Failed to fetch cart item for Buy Now');
      }

      List<QueryDocumentSnapshot> tempCartItems = cartSnapshot.docs;

      // Calculate total amount and convert to double
      double totalAmount = (int.parse(widget.itemData['price']) * _cartQuantity).toDouble();

      // Navigate to AddAddressPage with the fetched cart data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddAddressPage(
            cartItems: tempCartItems,
            totalAmount: totalAmount,
          ),
        ),
      );
    } catch (e) {
      developer.log('Error in Buy Now flow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error proceeding to address selection: $e')),
      );
    }
  }

  void _initiatePayment() {
    if (_cartQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add items to cart')),
      );
      return;
    }

    if (_guestUser) {
      _showLoginPrompt();
      return;
    }

    int amountInPaise =
        (int.parse(widget.itemData['price']) * _cartQuantity * 100).toInt();

    var options = {
      'key': Config.razorpayKey,
      'amount': amountInPaise,
      'name': 'Store Purchase',
      'description': 'Purchase of ${widget.itemData['name']} x$_cartQuantity',
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

    try {
      final bookingData = {
        'item_id': widget.itemData['id'],
        'item_name': widget.itemData['name'],
        'quantity': _cartQuantity,
        'total_amount': int.parse(widget.itemData['price']) * _cartQuantity,
        'payment_id': response.paymentId,
        'purchase_date': Timestamp.now(),
        'status': 'completed',
        'user_id': _userId,
        'guest_user': _guestUser,
      };

      final bookingRef =
          await _firestore.collection('store_bookings').add(bookingData);
      developer.log('Store booking created with ID: ${bookingRef.id}');

      if (!_guestUser && _userId != null) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('store_bookings')
            .doc(bookingRef.id)
            .set({
          ...bookingData,
          'booking_id': bookingRef.id,
        });
        developer.log(
            'Saved to user\'s store_bookings subcollection with ID: ${bookingRef.id}');
      }

      await _firestore.collection('store').doc(widget.itemData['id']).update({
        'quantity':
            (int.parse(widget.itemData['quantity']) - _cartQuantity).toString(),
      });
      developer.log('Store quantity updated');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Purchase successful! Booking ID: ${bookingRef.id}')),
      );

      setState(() {
        _cartQuantity = 0;
        widget.itemData['quantity'] =
            (int.parse(widget.itemData['quantity']) - _cartQuantity).toString();
      });
      Navigator.pop(context); // Return to store home
    } catch (e) {
      developer.log('Error saving booking: $e', stackTrace: StackTrace.current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing purchase: $e')),
      );
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

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Login Required'),
        content: Text('Please login or register to complete your purchase.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to login page
              // Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));
            },
            child: Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemData['name'],
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(_auth.currentUser?.uid)
                .collection('cart')
                .snapshots(),
            builder: (context, snapshot) {
              int cartCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_cart),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CartScreen()),
                      );
                    },
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '$cartCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section with Thumbnails
                  Container(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Image
                        Container(
                          height: 300,
                          width: double.infinity,
                          child: Image.network(
                            widget.itemData['images'][_selectedImageIndex],
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Thumbnails Row
                        Container(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                (widget.itemData['images'] as List).length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImageIndex = index;
                                  });
                                },
                                child: Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedImageIndex == index
                                          ? Colors.blue
                                          : Colors.grey,
                                      width:
                                          _selectedImageIndex == index ? 2 : 1,
                                    ),
                                  ),
                                  child: Image.network(
                                    widget.itemData['images'][index],
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemData['name'],
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '₹${widget.itemData['price']}',
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Available Quantity: ${widget.itemData['quantity']}',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: _removeFromCart,
                                    icon: Icon(Icons.remove, size: 20),
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('$_cartQuantity',
                                        style: TextStyle(fontSize: 18)),
                                  ),
                                  IconButton(
                                    onPressed: _addToCart,
                                    icon: Icon(Icons.add, size: 20),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Total: ₹${int.parse(widget.itemData['price']) * _cartQuantity}',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _addToCartCollection,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Add to Cart',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _initiateBuyNow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Buy Now',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        // You May Also Like Section
                        Text(
                          'You May Also Like',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          height: 200,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('store')
                                .limit(5)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                    child: Text('No items available'));
                              }

                              // Filter out the current item based on document ID
                              final filteredItems = snapshot.data!.docs
                                  .where(
                                      (doc) => doc.id != widget.itemData['id'])
                                  .toList();

                              if (filteredItems.isEmpty) {
                                return Center(
                                    child: Text('No other items available'));
                              }

                              return ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index].data()
                                      as Map<String, dynamic>;
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StorePurchasePage(itemData: {
                                            ...item,
                                            'id': filteredItems[index].id,
                                          }),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 150,
                                      margin: EdgeInsets.only(right: 10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height: 120,
                                            child: Image.network(
                                              item['images'][0],
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Text(
                                            item['name'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            '₹${item['price']}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}