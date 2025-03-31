import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({Key? key}) : super(key: key);

  @override
  _MyBookingsPageState createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Room'),
              Tab(text: 'Pooja'),
              Tab(text: 'Orders'),
              Tab(text: 'Donations'),
              Tab(text: 'Offerings'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            RoomBookingTab(firestore: _firestore, auth: _auth),
            PoojaBookingTab(firestore: _firestore, auth: _auth),
            OrdersTab(firestore: _firestore, auth: _auth),
            DonationsTab(firestore: _firestore, auth: _auth),
            OfferingsTab(firestore: _firestore, auth: _auth),
          ],
        ),
      ),
    );
  }
}

// Placeholder widget for Room Booking Tab
// Updated widget for Room Booking Tab
class RoomBookingTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const RoomBookingTab({required this.firestore, required this.auth, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: auth.currentUser != null
          ? firestore
              .collection('users')
              .doc(auth.currentUser!.uid)
              .collection('room_booking')
              .orderBy('booking_date', descending: true)
              .snapshots()
          : Stream.empty(),
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
                        // Text(
                        //     'Allocated Room: ${booking['allocated_room'] ?? 'N/A'}'),
                        Text('Booking ID: ${booking['booking_id'] ?? 'N/A'}'),
                        // Text('Room ID: ${booking['room_id'] ?? 'N/A'}'),
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

// Updated widget for Pooja Booking Tab
class PoojaBookingTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const PoojaBookingTab({required this.firestore, required this.auth, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: auth.currentUser != null
          ? firestore
              .collection('users')
              .doc(auth.currentUser!.uid)
              .collection('pooja_booking')
              .orderBy('timestamp', descending: true)
              .snapshots()
          : Stream.empty(),
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
                        // Text('Pooja ID: ${booking['poojaId'] ?? 'N/A'}'),
                        Text('Payment ID: ${booking['paymentId'] ?? 'N/A'}'),
                        Text('People: $participantsString'),
                        Text(
                          'Booked On: ${booking['timestamp'] != null ? (booking['timestamp'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                        ),
                        // Text('User ID: ${booking['userId'] ?? 'N/A'}'),
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

// Placeholder widget for Orders Tab
class OrdersTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const OrdersTab({required this.firestore, required this.auth, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: auth.currentUser != null
          ? firestore
              .collection('users')
              .doc(auth.currentUser!.uid)
              .collection('store_bookings')
              .orderBy('purchase_date', descending: true)
              .snapshots()
          : Stream.empty(),
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

// Updated widget for Donations Tab
class DonationsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const DonationsTab({required this.firestore, required this.auth, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: auth.currentUser != null
          ? firestore
              .collection('users')
              .doc(auth.currentUser!.uid)
              .collection('donations')
              .orderBy('timestamp', descending: true)
              .snapshots()
          : Stream.empty(),
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

// Updated widget for Offerings Tab
class OfferingsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const OfferingsTab({required this.firestore, required this.auth, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: auth.currentUser != null
          ? firestore
              .collection('users')
              .doc(auth.currentUser!.uid)
              .collection('offering_booking')
              .orderBy('timestamp', descending: true)
              .snapshots()
          : Stream.empty(),
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
