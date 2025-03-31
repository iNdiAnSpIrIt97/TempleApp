import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class UserBookingsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const UserBookingsPage(
      {Key? key, required this.userId, required this.userName})
      : super(key: key);

  @override
  _UserBookingsPageState createState() => _UserBookingsPageState();
}

class _UserBookingsPageState extends State<UserBookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedBookingType = 'Room'; // Default selection

  // List of booking types for the dropdown
  final List<String> _bookingTypes = [
    'Room',
    'Pooja',
    'Orders',
    'Donations',
    'Offerings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.userName}'s Bookings",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Dropdown to select booking type
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: _selectedBookingType,
              isExpanded: true,
              items: _bookingTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedBookingType = newValue;
                  });
                }
              },
              hint: const Text('Select Booking Type'),
              underline: Container(
                height: 2,
                color: Colors.orange,
              ),
            ),
          ),
          // Load the appropriate bookings based on the selected type
          Expanded(
            child: _buildBookingList(),
          ),
        ],
      ),
    );
  }

  // Helper method to build the booking list based on the selected type
  Widget _buildBookingList() {
    switch (_selectedBookingType) {
      case 'Room':
        return RoomBookingTab(firestore: _firestore, userId: widget.userId);
      case 'Pooja':
        return PoojaBookingTab(firestore: _firestore, userId: widget.userId);
      case 'Orders':
        return OrdersTab(firestore: _firestore, userId: widget.userId);
      case 'Donations':
        return DonationsTab(firestore: _firestore, userId: widget.userId);
      case 'Offerings':
        return OfferingsTab(firestore: _firestore, userId: widget.userId);
      default:
        return const Center(child: Text('Select a booking type to view.'));
    }
  }
}

// Widget for Room Booking List
class RoomBookingTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String userId;

  const RoomBookingTab(
      {required this.firestore, required this.userId, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('users')
          .doc(userId)
          .collection('room_booking')
          .orderBy('booking_date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No room bookings found.'));
        }

        final bookings = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index].data() as Map<String, dynamic>;

            // Format guests as a string
            List<dynamic> guests = booking['guests'] ?? [];
            String guestsString = guests.isNotEmpty
                ? guests
                    .map((g) =>
                        '${g['name']} (Age: ${g['age']}, ID: ${g['id_type']} ${g['id_number']})')
                    .join(', ')
                : 'No guests';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                leading: const Icon(Icons.room, color: Colors.orange),
                title: Text(
                  booking['room_title'] ?? 'Unnamed Room Booking',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount: ₹${booking['amount'] ?? 0}'),
                    Text(
                      'From: ${booking['from_date'] != null ? (booking['from_date'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'} - To: ${booking['to_date'] != null ? (booking['to_date'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking ID: ${booking['booking_id'] ?? 'N/A'}'),
                        Text('Room Type: ${booking['room_type'] ?? 'N/A'}'),
                        Text('Persons: ${booking['persons'] ?? 'N/A'}'),
                        Text('Guests: $guestsString'),
                        Text('Status: ${booking['status'] ?? 'N/A'}'),
                        Text(
                            'Payment Status: ${booking['payment_status'] == true ? 'Paid' : 'Unpaid'}'),
                        Text(
                          'Booked On: ${booking['booking_date'] != null ? (booking['booking_date'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Widget for Pooja Booking List
class PoojaBookingTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String userId;

  const PoojaBookingTab(
      {required this.firestore, required this.userId, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('users')
          .doc(userId)
          .collection('pooja_booking')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pooja bookings found.'));
        }

        final bookings = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index].data() as Map<String, dynamic>;

            // Format participants as a string
            List<dynamic> participants = booking['participants'] ?? [];
            String participantsString = participants.isNotEmpty
                ? participants
                    .map((p) => '${p['name']} (${p['star']})')
                    .join(', ')
                : 'No participants';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                leading: const Icon(Icons.temple_hindu, color: Colors.orange),
                title: Text(
                  booking['title'] ?? 'Unnamed Pooja Booking',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount: ₹${booking['amount'] ?? 0}'),
                    Text(
                      'Date of Pooja: ${booking['selectedDate'] != null ? (booking['selectedDate'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking ID: ${booking['bookingId'] ?? 'N/A'}'),
                        Text('Payment ID: ${booking['paymentId'] ?? 'N/A'}'),
                        Text('People: $participantsString'),
                        Text(
                          'Booked On: ${booking['timestamp'] != null ? (booking['timestamp'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Widget for Orders List
class OrdersTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String userId;

  const OrdersTab({required this.firestore, required this.userId, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('users')
          .doc(userId)
          .collection('store_bookings')
          .orderBy('purchase_date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No orders found.'));
        }

        final bookings = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(
                  booking['item_name'] ?? 'Unnamed Order',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${booking['booking_id'] ?? 'N/A'}'),
                    Text('Amount: ₹${booking['total_amount'] ?? 0}'),
                    Text(
                      'Date: ${booking['purchase_date'] != null ? (booking['purchase_date'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                    ),
                    Text('Status: ${booking['status'] ?? 'N/A'}'),
                  ],
                ),
                trailing: const Icon(Icons.receipt, color: Colors.orange),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Tapped on ${booking['item_name']}')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// Widget for Donations List
class DonationsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String userId;

  const DonationsTab({required this.firestore, required this.userId, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('users')
          .doc(userId)
          .collection('donations')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No donations found.'));
        }

        final donations = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: donations.length,
          itemBuilder: (context, index) {
            final donation = donations[index].data() as Map<String, dynamic>;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading:
                    const Icon(Icons.monetization_on, color: Colors.orange),
                title: Text(
                  donation['donationType'] ?? 'Unnamed Donation',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount: ₹${donation['amount'] ?? 0}'),
                    Text(
                      'Date: ${donation['timestamp'] != null ? (donation['timestamp'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                    ),
                    Text('Payment ID: ${donation['paymentId'] ?? 'N/A'}'),
                  ],
                ),
                trailing: const Icon(Icons.receipt, color: Colors.orange),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Tapped on ${donation['donationType'] ?? 'Donation'}'),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// Widget for Offerings List
class OfferingsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String userId;

  const OfferingsTab({required this.firestore, required this.userId, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('users')
          .doc(userId)
          .collection('offering_booking')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No offerings found.'));
        }

        final bookings = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index].data() as Map<String, dynamic>;

            // Format participants as a string
            List<dynamic> participants = booking['participants'] ?? [];
            String participantsString = participants.isNotEmpty
                ? participants
                    .map((p) => '${p['name']} (${p['star']})')
                    .join(', ')
                : 'No participants';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                leading: const Icon(Icons.local_florist, color: Colors.orange),
                title: Text(
                  booking['offeringName'] ?? 'Unnamed Offering',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount: ₹${booking['amount'] ?? 0}'),
                    Text(
                      'Date: ${booking['timestamp'] != null ? (booking['timestamp'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deity: ${booking['deity'] ?? 'N/A'}'),
                        Text('Quantity: ${booking['quantity'] ?? 'N/A'}'),
                        Text('Participants: $participantsString'),
                        Text('Payment ID: ${booking['paymentId'] ?? 'N/A'}'),
                        Text('Offering ID: ${booking['offeringId'] ?? 'N/A'}'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
