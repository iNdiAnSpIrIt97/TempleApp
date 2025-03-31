import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewBookingsPage extends StatefulWidget {
  const ViewBookingsPage({super.key});

  @override
  State<ViewBookingsPage> createState() => _ViewBookingsPageState();
}

class _ViewBookingsPageState extends State<ViewBookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'from_date'; // Default sort by from_date
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by Username or Booking ID',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      if (value == _sortBy) {
                        _sortAscending = !_sortAscending; // Toggle direction
                      } else {
                        _sortBy = value;
                        _sortAscending = true; // Reset to ascending
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'from_date', child: Text('Sort by Date')),
                    const PopupMenuItem(
                        value: 'user_name', child: Text('Sort by Username')),
                  ],
                  icon: const Icon(Icons.sort),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('room_bookings').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No bookings found"));
                  }

                  List<QueryDocumentSnapshot> bookings = snapshot.data!.docs;

                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    bookings = bookings.where((booking) {
                      String userName =
                          booking['user_name'].toString().toLowerCase();
                      String bookingId = booking.id.toLowerCase();
                      return userName.contains(_searchQuery) ||
                          bookingId.contains(_searchQuery);
                    }).toList();
                  }

                  // Check if filtered list is empty
                  if (bookings.isEmpty) {
                    return const Center(child: Text("No bookings found"));
                  }

                  // Sort bookings
                  bookings.sort((a, b) {
                    if (_sortBy == 'from_date') {
                      Timestamp aDate = a['from_date'];
                      Timestamp bDate = b['from_date'];
                      return _sortAscending
                          ? aDate.compareTo(bDate)
                          : bDate.compareTo(aDate);
                    } else {
                      String aName = a['user_name'].toString().toLowerCase();
                      String bName = b['user_name'].toString().toLowerCase();
                      return _sortAscending
                          ? aName.compareTo(bName)
                          : bName.compareTo(aName);
                    }
                  });

                  return ListView.builder(
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      return BookingTile(booking: bookings[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingTile extends StatefulWidget {
  final QueryDocumentSnapshot booking;

  const BookingTile({super.key, required this.booking});

  @override
  State<BookingTile> createState() => _BookingTileState();
}

class _BookingTileState extends State<BookingTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    String allocatedRoom = widget.booking['allocated_room'];
    Timestamp bookingDate = widget.booking['booking_date'];
    Timestamp fromDate = widget.booking['from_date'];
    Timestamp toDate = widget.booking['to_date'];
    String userName = widget.booking['user_name'];
    List<dynamic> guests = widget.booking['guests'];
    bool paymentStatus = widget.booking['payment_status'];
    int amount = widget.booking['amount'];
    String paymentId = widget.booking['payment_id'];
    int persons = widget.booking['persons'];
    String status = widget.booking['status'];
    String userEmail = widget.booking['user_email'];
    String userPhone = widget.booking['user_phone'];
    String roomId = widget.booking['room_id'];

    // Convert timestamp to local date midnight (Epoch) for room_availability lookup
    DateTime fromDateTime = fromDate.toDate();
    String dateKey = DateFormat('yyyy-MM-dd').format(fromDateTime);
    int epochMidnight =
        DateTime(fromDateTime.year, fromDateTime.month, fromDateTime.day)
                .millisecondsSinceEpoch ~/
            1000;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "From: ${DateFormat('MMM d, yyyy').format(fromDate.toDate())}",
        ),
        trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Booking ID: ${widget.booking.id}"),
                Text("Allocated Room: $allocatedRoom"),
                Text(
                    "Booking Date: ${DateFormat('MMM d, yyyy hh:mm a').format(bookingDate.toDate())}"),
                Text(
                    "To: ${DateFormat('MMM d, yyyy hh:mm a').format(toDate.toDate())}"),
                Text("Amount: ₹$amount"),
                Text("Persons: $persons"),
                Text("Payment ID: $paymentId"),
                Text("Payment Status: ${paymentStatus ? 'Paid' : 'Pending'}"),
                Text("Status: $status"),
                Text("User Email: $userEmail"),
                Text("User Phone: $userPhone"),
                const SizedBox(height: 8),
                Text("Guests:"),
                ...guests
                    .map((guest) => Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Name: ${guest['name']}"),
                              Text("Age: ${guest['age']}"),
                              Text("ID Number: ${guest['id_number']}"),
                              Text("ID Type: ${guest['id_type']}"),
                              const Divider(),
                            ],
                          ),
                        ))
                    .toList(),
                const SizedBox(height: 8),
                FutureBuilder<DocumentSnapshot>(
                  future: _fetchRoomDetails(roomId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Text("Loading room...");
                    var room = snapshot.data!;
                    return Text("Room: ${room['title']} (${room['type']})");
                  },
                ),
                FutureBuilder<DocumentSnapshot>(
                  future: _fetchAvailabilityDetails(
                      roomId, epochMidnight.toString()),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Text("Loading availability...");
                    if (!snapshot.data!.exists)
                      return const Text("No availability data");
                    var availability = snapshot.data!;
                    int totalBookings = availability['total_bookings'] ?? 0;
                    List<dynamic> bookingIds = availability['booking_id'] ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date: $dateKey"),
                        Text("Total Bookings: $totalBookings"),
                        Text("Booking IDs: ${bookingIds.join(', ')}"),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<DocumentSnapshot> _fetchRoomDetails(String roomId) {
    return FirebaseFirestore.instance.collection('room').doc(roomId).get();
  }

  Future<DocumentSnapshot> _fetchAvailabilityDetails(
      String roomId, String dateKey) {
    return FirebaseFirestore.instance
        .collection('room_availability')
        .doc(roomId)
        .collection('date_wise_booking')
        .doc(dateKey)
        .get();
  }
}
