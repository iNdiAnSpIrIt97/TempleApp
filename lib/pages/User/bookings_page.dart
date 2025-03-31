import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:temple_app/models/room.dart';
import 'package:temple_app/pages/User/booking_completion_page.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime? fromDate;
  DateTime? toDate;
  String? selectedRoomId;
  int selectedPersons = 1;
  bool isAvailable = false;
  bool isChecking = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> checkAvailability(String roomId, DateTime date) async {
    try {
      print('Checking availability for room: $roomId on date: $date');
      final epochTime = (date.millisecondsSinceEpoch / 1000).round();
      print('Converted date to epoch time: $epochTime');

      final docRef = _firestore
          .collection('room_availability')
          .doc(roomId)
          .collection('date_wise_booking')
          .doc(epochTime.toString());

      print(
          'Querying path: /room_availability/$roomId/date_wise_booking/$epochTime');

      final doc = await docRef.get();

      print('Document exists: ${doc.exists}');
      if (!doc.exists) {
        print('No booking data found - all rooms available');
        return true;
      }

      final data = doc.data();
      print('Retrieved data: $data');
      final availableRooms =
          List<String>.from(data?['room_nos_available'] ?? []);
      print('Available rooms: $availableRooms');

      if (availableRooms.isEmpty) {
        print('No rooms available (empty room_nos_available)');
        return false;
      }

      print('Rooms available found: $availableRooms');
      return true;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  void _handleAvailabilityCheck(Room room) async {
    if (fromDate == null || selectedRoomId == null) {
      print(
          'Missing required fields: fromDate=$fromDate, selectedRoomId=$selectedRoomId');
      return;
    }

    print('Starting availability check for room ID: ${room.roomId}');
    setState(() {
      isChecking = true;
    });

    final available = await checkAvailability(room.roomId, fromDate!);

    setState(() {
      isChecking = false;
      isAvailable = available;
      print('Availability result: $available');
      if (available) {
        print('Navigating to booking completion page');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingCompletionPage(
              room: room,
              fromDate: fromDate!,
              toDate: toDate,
              persons: selectedPersons,
            ),
          ),
        );
      } else {
        print('Showing no availability dialog');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('No Rooms Available'),
            content: Text(
              'No rooms available for selected room type and date. Try another or Contact admin',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Building BookingPage');
    return Scaffold(
      appBar: AppBar(title: const Text("Room Booking")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('room').snapshots(),
        builder: (context, snapshot) {
          print('StreamBuilder state: ${snapshot.connectionState}');
          if (snapshot.hasError) {
            print('StreamBuilder error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            print('Waiting for room data...');
            return Center(child: CircularProgressIndicator());
          }

          print('Received ${snapshot.data!.docs.length} rooms');
          final rooms = snapshot.data!.docs
              .map((doc) => Room.fromFirestore(doc))
              .toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDatePickers(),
                  SizedBox(height: 20),
                  _buildRoomDropdown(rooms),
                  SizedBox(height: 20),
                  _buildPersonsDropdown(rooms),
                  SizedBox(height: 20),
                  _buildActionButtons(rooms),
                  SizedBox(height: 20),
                  _buildTariffList(rooms),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatePickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select Dates",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: fromDate != null
                      ? "${fromDate!.toLocal()}".split(' ')[0]
                      : "From Date",
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () async {
                      print('Opening from date picker');
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2025, 12, 31),
                      );
                      if (picked != null) {
                        setState(() {
                          fromDate = picked;
                          print('From date selected: $fromDate');
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: toDate != null
                      ? "${toDate!.toLocal()}".split(' ')[0]
                      : "To Date",
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () async {
                      print('Opening to date picker');
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: fromDate ?? DateTime.now(),
                        firstDate: fromDate ?? DateTime.now(),
                        lastDate: DateTime(2025, 12, 31),
                      );
                      if (picked != null) {
                        setState(() {
                          toDate = picked;
                          print('To date selected: $toDate');
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomDropdown(List<Room> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select Room Type",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(
          value: selectedRoomId,
          items: rooms.map((room) {
            return DropdownMenuItem<String>(
              value: room.roomId,
              child: Text("${room.title} (${room.type})"),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              selectedRoomId = newValue;
              selectedPersons = 1;
              print('Room selected: $newValue');
            });
          },
          decoration: InputDecoration(border: OutlineInputBorder()),
          hint: Text("Select Room Type"),
        ),
      ],
    );
  }

  Widget _buildPersonsDropdown(List<Room> rooms) {
    final selectedRoom = rooms.firstWhere(
      (room) => room.roomId == selectedRoomId,
      orElse: () => rooms.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Number of Persons",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        DropdownButtonFormField<int>(
          value: selectedPersons,
          items: List.generate(selectedRoom.occupancy, (index) => index + 1)
              .map((value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text("$value Person${value > 1 ? 's' : ''}"),
            );
          }).toList(),
          onChanged: selectedRoomId != null
              ? (newValue) {
                  setState(() {
                    selectedPersons = newValue!;
                    print('Persons selected: $selectedPersons');
                  });
                }
              : null,
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildActionButtons(List<Room> rooms) {
    final selectedRoom = rooms.firstWhere(
      (room) => room.roomId == selectedRoomId,
      orElse: () => rooms.first,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: fromDate != null && selectedRoomId != null
              ? () => _handleAvailabilityCheck(selectedRoom)
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: isChecking
              ? CircularProgressIndicator(color: Colors.white)
              : Text("Check Availability"),
        ),
        // ElevatedButton(
        //   onPressed: isAvailable ? () {} : null,
        //   style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        //   child: Text("Book Now"),
        // ),
      ],
    );
  }

  Widget _buildTariffList(List<Room> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tariff List",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text("Check-in: 11:00 AM, Check-out: 10:00 AM"),
        ...rooms.map((room) => Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text("${room.title} (${room.type})",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("₹${room.amount} per day"),
                    SizedBox(height: 4),
                    Text("Features: ${room.features.join(', ')}",
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: Text(
                    "Max ${room.occupancy} Person${room.occupancy > 1 ? 's' : ''}"),
              ),
            )),
      ],
    );
  }
}
