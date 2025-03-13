import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_room_booking_page.dart';

class RoomAllocationPage extends StatefulWidget {
  const RoomAllocationPage({super.key});

  @override
  State<RoomAllocationPage> createState() => _RoomAllocationPageState();
}

class _RoomAllocationPageState extends State<RoomAllocationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedDay = DateTime.now();

  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.utc(2030, 12, 31),
    );
    if (pickedDate != null && pickedDate != _selectedDay) {
      setState(() {
        _selectedDay = pickedDate;
      });
    }
  }

  Future<void> _showBookingDetails(String roomId, String roomNo) async {
    DateTime midnight =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    int epochMidnight = midnight.millisecondsSinceEpoch ~/ 1000;

    DocumentSnapshot availabilityDoc = await _firestore
        .collection('room_availability')
        .doc(roomId)
        .collection('date_wise_booking')
        .doc(epochMidnight.toString())
        .get();

    if (!availabilityDoc.exists) {
      _showNoBookingDialog();
      return;
    }

    List<String> bookedRooms =
        List<String>.from(availabilityDoc['booked_rooms'] ?? []);
    List<String> bookingIds =
        List<String>.from(availabilityDoc['booking_id'] ?? []);
    if (!bookedRooms.contains(roomNo) || bookingIds.isEmpty) {
      _showNoBookingDialog();
      return;
    }

    String? bookingId;
    for (int i = 0; i < bookedRooms.length; i++) {
      if (bookedRooms[i] == roomNo) {
        bookingId = bookingIds[i];
        break;
      }
    }

    if (bookingId == null) {
      _showNoBookingDialog();
      return;
    }

    DocumentSnapshot bookingDoc =
        await _firestore.collection('room_bookings').doc(bookingId).get();

    if (!bookingDoc.exists) {
      _showNoBookingDialog();
      return;
    }

    var data = bookingDoc.data() as Map<String, dynamic>;
    String allocatedRoom = data['allocated_room'] ?? 'N/A';
    Timestamp? dateOfBooking = data['booking_date'];
    Timestamp? fromDate = data['from_date'];
    Timestamp? toDate = data['to_date'];
    List<dynamic> guests = data['guests'] ?? [];
    String guestNames = guests.map((g) => g['name']).join(', ');
    bool guestUser = data['guest_user'] ?? false;
    bool paymentStatus = data['payment_status'] ?? false;
    String userId = data['user_id'] ?? 'N/A';
    String userName = data['user_name'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Booking Details for Room $roomNo"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Allocated Room: $allocatedRoom"),
              Text(
                  "Date of Booking: ${dateOfBooking != null ? DateFormat('yyyy-MM-dd HH:mm').format(dateOfBooking.toDate()) : 'N/A'}"),
              Text(
                  "From Date: ${fromDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(fromDate.toDate()) : 'N/A'}"),
              Text(
                  "To Date: ${toDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(toDate.toDate()) : 'N/A'}"),
              Text(
                  "Guest Names: ${guestNames.isNotEmpty ? guestNames : 'N/A'}"),
              Text("Guest User: $guestUser"),
              Text("Payment Status: $paymentStatus"),
              Text("User ID: $userId"),
              Text("User Name: $userName"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRoomBookingPage(
                    bookingId: bookingId!,
                    roomId: roomId,
                    selectedDay: _selectedDay,
                  ),
                ),
              );
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showNoBookingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("No Booking"),
        content: const Text(
            "No booking details available for this room on the selected date."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Room Allocation",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(context),
                  tooltip: 'Select Date',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Selected Date: ${DateFormat('yyyy-MM-dd').format(_selectedDay)}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('room').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No rooms found"));
                }

                var rooms = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    var room = rooms[index];
                    String roomId = room.id;
                    String title = room['title'];
                    String type = room['type'];
                    List<String> roomNos =
                        List<String>.from(room['room_nos'] ?? []);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$title - $type",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            FutureBuilder<Map<String, bool>>(
                              future: _getRoomAvailability(roomId, roomNos),
                              builder: (context, availabilitySnapshot) {
                                if (!availabilitySnapshot.hasData) {
                                  return const Text(
                                      "Loading room availability...");
                                }
                                var availability = availabilitySnapshot.data!;
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: roomNos.map((roomNo) {
                                    bool isBooked =
                                        availability[roomNo] ?? false;
                                    return GestureDetector(
                                      onTap: () =>
                                          _showBookingDetails(roomId, roomNo),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isBooked
                                              ? Colors.red
                                              : Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            roomNo,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, bool>> _getRoomAvailability(
      String roomId, List<String> roomNos) async {
    DateTime midnight =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    int epochMidnight = midnight.millisecondsSinceEpoch ~/ 1000;

    DocumentSnapshot availabilityDoc = await _firestore
        .collection('room_availability')
        .doc(roomId)
        .collection('date_wise_booking')
        .doc(epochMidnight.toString())
        .get();

    Map<String, bool> availability = {
      for (var roomNo in roomNos) roomNo: false
    };

    if (availabilityDoc.exists) {
      List<String> bookedRooms =
          List<String>.from(availabilityDoc['booked_rooms'] ?? []);
      for (var roomNo in roomNos) {
        if (bookedRooms.contains(roomNo)) {
          availability[roomNo] = true;
        }
      }
    }
    return availability;
  }
}
