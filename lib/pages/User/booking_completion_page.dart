import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:temple_app/config/razorpay_config.dart';
import 'package:temple_app/models/room.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/pages/Login/login_landing.dart';
import 'dart:developer' as developer;

class GuestDetails {
  TextEditingController nameController = TextEditingController();
  TextEditingController ageController = TextEditingController();
  TextEditingController idNumberController = TextEditingController();
  String? idType;

  GuestDetails({String? initialName}) {
    if (initialName != null) nameController.text = initialName;
  }

  Map<String, dynamic> toJson() => {
        'name': nameController.text,
        'age': int.tryParse(ageController.text) ?? 0,
        'id_number': idNumberController.text,
        'id_type': idType ?? 'AADHAAR',
      };
}

class BookingCompletionPage extends StatefulWidget {
  final Room room;
  final DateTime fromDate;
  final DateTime? toDate;
  final int persons;

  const BookingCompletionPage({
    Key? key,
    required this.room,
    required this.fromDate,
    this.toDate,
    required this.persons,
  }) : super(key: key);

  @override
  _BookingCompletionPageState createState() => _BookingCompletionPageState();
}

class _BookingCompletionPageState extends State<BookingCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  List<GuestDetails> _guestDetails = [];
  bool _isGuest = true;
  late Razorpay _razorpay;
  String? _userId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkUserStatus();
    _initializeUserDetails();
    _initializeGuestFields();
  }

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('uid');
    final user = _auth.currentUser;
    setState(() {
      _isGuest = user == null;
    });
  }

  Future<void> _initializeUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          setState(() {
            _nameController.text = data['user_name'] ?? '';
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            if (_guestDetails.isNotEmpty) {
              _guestDetails[0].nameController.text = _nameController.text;
            }
          });
        }
      } catch (e) {
        developer.log('Error fetching user details: $e');
      }
    }
  }

  void _initializeGuestFields() {
    _guestDetails = [GuestDetails(initialName: _nameController.text)];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    for (var guest in _guestDetails) {
      guest.nameController.dispose();
      guest.ageController.dispose();
      guest.idNumberController.dispose();
    }
    _razorpay.clear();
    super.dispose();
  }

  int _calculateTotalAmount() {
    final int rate = int.parse(widget.room.amount);
    final int days = widget.toDate != null
        ? widget.toDate!.difference(widget.fromDate).inDays + 1
        : 1;
    return rate * days;
  }

  void _initiatePayment() {
    int amountInPaise = (_calculateTotalAmount() * 100).toInt();

    var options = {
      'key': Config.razorpayKey,
      'amount': amountInPaise,
      'name': 'Room Booking',
      'description': 'Booking for ${widget.room.title}',
      'prefill': {
        'contact': _phoneController.text,
        'email': _emailController.text,
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

  Future<void> _submitBooking({required String? paymentId}) async {
    // Changed to String?
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final epochFrom = (widget.fromDate.millisecondsSinceEpoch / 1000).round();
      final epochTo = widget.toDate != null
          ? (widget.toDate!.millisecondsSinceEpoch / 1000).round()
          : epochFrom;

      final roomDoc =
          await _firestore.collection('room').doc(widget.room.roomId).get();
      final allRooms = List<String>.from(roomDoc.data()?['room_nos'] ?? []);
      if (allRooms.isEmpty) {
        throw Exception('No rooms defined for this room type.');
      }

      final availabilityRef = _firestore
          .collection('room_availability')
          .doc(widget.room.roomId)
          .collection('date_wise_booking')
          .doc(epochFrom.toString());

      final availabilityDoc = await availabilityRef.get();
      List<String> availableRooms;
      List<String> bookedRooms;
      List<String> bookingIds;
      int totalBookings;

      if (!availabilityDoc.exists) {
        availableRooms = List.from(allRooms);
        bookedRooms = [];
        bookingIds = [];
        totalBookings = 0;
      } else {
        final data = availabilityDoc.data()!;
        availableRooms = List<String>.from(data['room_nos_available'] ?? []);
        bookedRooms = List<String>.from(data['booked_rooms'] ?? []);
        bookingIds = List<String>.from(data['booking_id'] ?? []);
        totalBookings = data['total_bookings'] ?? 0;
      }

      if (availableRooms.isEmpty) {
        throw Exception('No rooms available for booking on this date.');
      }

      final roomToBook = availableRooms.first;

      final bookingData = {
        'room_id': widget.room.roomId,
        'room_title': widget.room.title,
        'room_type': widget.room.type,
        'from_date': Timestamp.fromDate(widget.fromDate),
        'to_date': widget.toDate != null
            ? Timestamp.fromDate(widget.toDate!)
            : Timestamp.fromDate(widget.fromDate),
        'persons': _guestDetails.length,
        'amount': _calculateTotalAmount(),
        'user_name': _nameController.text,
        'user_email': _emailController.text,
        'user_phone': _phoneController.text,
        'guests': _guestDetails.map((g) => g.toJson()).toList(),
        'booking_date': Timestamp.now(),
        'status': 'confirmed',
        'user_id': _userId,
        'payment_status': true,
        'allocated_room': roomToBook,
        if (paymentId != null) 'payment_id': paymentId, // Only add if not null
      };

      final bookingRef =
          await _firestore.collection('room_bookings').add(bookingData);

      if (_userId != null) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('room_booking')
            .doc(bookingRef.id)
            .set({
          ...bookingData,
          'booking_id': bookingRef.id,
        });
      }

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(availabilityRef);

        if (!snapshot.exists) {
          transaction.set(availabilityRef, {
            'booked_rooms': [roomToBook],
            'booking_id': [bookingRef.id],
            'room_nos_available': allRooms..remove(roomToBook),
            'total_bookings': 1,
          });
        } else {
          bookedRooms.add(roomToBook);
          bookingIds.add(bookingRef.id);
          availableRooms.remove(roomToBook);
          totalBookings += 1;

          transaction.update(availabilityRef, {
            'booked_rooms': bookedRooms,
            'booking_id': bookingIds,
            'room_nos_available': availableRooms,
            'total_bookings': totalBookings,
          });
        }
      });

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Booking Confirmed'),
          content: Text(
              'Your booking has been successfully confirmed! Booking ID: ${bookingRef.id}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      developer.log('Error submitting booking: $e',
          stackTrace: StackTrace.current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete booking: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _submitBooking(paymentId: response.paymentId); // paymentId is String?
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
    setState(() {
      _isSubmitting = false;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    developer.log('External wallet used: ${response.walletName}');
  }

  Future<void> _navigateToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginLanding()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final totalAmount = _calculateTotalAmount();

    if (_isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text('Complete Booking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rooms are available, please login or register to proceed with booking',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _navigateToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: Size(200, 50),
                ),
                child: Text('Login', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Complete Booking')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Details',
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 8),
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room: ${widget.room.title} (${widget.room.type})'),
                      Text('From: ${dateFormat.format(widget.fromDate)}'),
                      Text(
                          'To: ${widget.toDate != null ? dateFormat.format(widget.toDate!) : dateFormat.format(widget.fromDate)}'),
                      Text('Total Amount: ₹$totalAmount'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text('Your Details',
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter your name';
                  return null;
                },
                onChanged: (value) {
                  if (_guestDetails.isNotEmpty) {
                    setState(() {
                      _guestDetails[0].nameController.text = value;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter your email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                    return 'Please enter a valid email';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter your phone number';
                  if (!RegExp(r'^\+?\d{10,13}$').hasMatch(value))
                    return 'Please enter a valid phone number';
                  return null;
                },
              ),
              SizedBox(height: 20),
              if (widget.room.occupancy > 1) ...[
                Text('Guest Details (Max ${widget.room.occupancy})',
                    style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 8),
                ..._guestDetails.asMap().entries.map((entry) {
                  final index = entry.key;
                  final guest = entry.value;
                  return _buildGuestForm(index, guest);
                }).toList(),
                if (_guestDetails.length < widget.room.occupancy)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _guestDetails.add(GuestDetails());
                      });
                    },
                    child: Text('Add Guest'),
                  ),
              ],
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _initiatePayment();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Pay Now', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestForm(int index, GuestDetails guest) {
    final idTypes = ['AADHAAR', 'Voter ID', 'Driving License'];

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guest ${index + 1}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextFormField(
              controller: guest.nameController,
              decoration: InputDecoration(
                labelText: 'Guest Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter guest name';
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: guest.ageController,
              decoration: InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter age';
                final age = int.tryParse(value);
                if (age == null || age <= 0) return 'Please enter a valid age';
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: guest.idNumberController,
              decoration: InputDecoration(
                labelText: 'ID Number',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter ID number';
                return null;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: guest.idType ?? idTypes[0],
              items: idTypes
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  guest.idType = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'ID Type',
                border: OutlineInputBorder(),
              ),
            ),
            if (index > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    _guestDetails.removeAt(index);
                  });
                },
                child:
                    Text('Remove Guest', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
