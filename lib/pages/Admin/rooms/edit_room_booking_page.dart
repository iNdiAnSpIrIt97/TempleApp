import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditRoomBookingPage extends StatefulWidget {
  final String bookingId;
  final String roomId;
  final DateTime selectedDay;

  const EditRoomBookingPage({
    super.key,
    required this.bookingId,
    required this.roomId,
    required this.selectedDay,
  });

  @override
  State<EditRoomBookingPage> createState() => _EditRoomBookingPageState();
}

class _EditRoomBookingPageState extends State<EditRoomBookingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _guestNamesController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  String? _swapRoom; // New room to swap to
  String? _originalAllocatedRoom; // Current allocated room (uneditable)
  bool _paymentStatus = false;
  List<String> _availableRooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    DocumentSnapshot bookingDoc = await _firestore
        .collection('room_bookings')
        .doc(widget.bookingId)
        .get();
    if (bookingDoc.exists) {
      var data = bookingDoc.data() as Map<String, dynamic>;
      setState(() {
        _guestNamesController.text =
            (data['guest_names'] as List<dynamic>?)?.join(', ') ?? '';
        _idNumberController.text = data['id_number'] ?? '';
        _userNameController.text = data['user_name'] ?? '';
        _originalAllocatedRoom = data['allocated_room'];
        _swapRoom = data['allocated_room']; // Default to current room
        _paymentStatus = data['payment_status'] ?? false;
      });
    }

    int epochMidnight = DateTime(widget.selectedDay.year,
                widget.selectedDay.month, widget.selectedDay.day)
            .millisecondsSinceEpoch ~/
        1000;
    DocumentSnapshot availabilityDoc = await _firestore
        .collection('room_availability')
        .doc(widget.roomId)
        .collection('date_wise_booking')
        .doc(epochMidnight.toString())
        .get();

    if (availabilityDoc.exists) {
      _availableRooms =
          List<String>.from(availabilityDoc['room_nos_available'] ?? []);
    } else {
      // If no availability document exists, assume no rooms are available for swapping
      _availableRooms = [];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _updateBooking() async {
    setState(() => _isLoading = true);
    try {
      // Update room_bookings
      await _firestore
          .collection('room_bookings')
          .doc(widget.bookingId)
          .update({
        'guest_names':
            _guestNamesController.text.split(',').map((e) => e.trim()).toList(),
        'id_number': _idNumberController.text,
        'user_name': _userNameController.text,
        'allocated_room': _swapRoom,
        'payment_status': _paymentStatus,
      });

      // Update room_availability if room swapped
      int epochMidnight = DateTime(widget.selectedDay.year,
                  widget.selectedDay.month, widget.selectedDay.day)
              .millisecondsSinceEpoch ~/
          1000;
      DocumentReference availabilityRef = _firestore
          .collection('room_availability')
          .doc(widget.roomId)
          .collection('date_wise_booking')
          .doc(epochMidnight.toString());

      DocumentSnapshot availabilityDoc = await availabilityRef.get();

      if (availabilityDoc.exists && _originalAllocatedRoom != _swapRoom) {
        List<String> bookedRooms =
            List<String>.from(availabilityDoc['booked_rooms'] ?? []);
        List<String> availableRooms =
            List<String>.from(availabilityDoc['room_nos_available'] ?? []);

        // Update booked_rooms: remove old room, add new room
        bookedRooms.remove(_originalAllocatedRoom);
        bookedRooms.add(_swapRoom!);

        // Update room_nos_available: remove new room, add old room
        availableRooms.remove(_swapRoom);
        if (_originalAllocatedRoom != null) {
          availableRooms.add(_originalAllocatedRoom!);
        }

        await availabilityRef.update({
          'booked_rooms': bookedRooms,
          'room_nos_available': availableRooms,
        });
      } else if (!availabilityDoc.exists &&
          _swapRoom != _originalAllocatedRoom) {
        DocumentSnapshot roomDoc =
            await _firestore.collection('rooms').doc(widget.roomId).get();
        List<String> allRooms = List<String>.from(roomDoc['room_nos'] ?? []);
        await availabilityRef.set({
          'booked_rooms': [_swapRoom],
          'booking_id': [widget.bookingId],
          'room_nos_available':
              allRooms.where((room) => room != _swapRoom).toList(),
          'total_bookings': 1,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking updated successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating booking: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Room Booking"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _guestNamesController,
                    decoration: const InputDecoration(
                        labelText: "Guest Names (comma-separated)"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _idNumberController,
                    decoration: const InputDecoration(labelText: "ID Number"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userNameController,
                    decoration: const InputDecoration(labelText: "User Name"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller:
                        TextEditingController(text: _originalAllocatedRoom),
                    decoration: const InputDecoration(
                      labelText: "Current Allocated Room",
                      enabled: false, // Makes it uneditable
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value:
                        _swapRoom == _originalAllocatedRoom ? null : _swapRoom,
                    items: _availableRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room,
                        child: Text(room),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _swapRoom = value ?? _originalAllocatedRoom;
                      });
                    },
                    decoration: const InputDecoration(labelText: "Swap Room"),
                    hint: const Text("Select a room to swap"),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text("Payment Status"),
                    value: _paymentStatus,
                    onChanged: (value) {
                      setState(() {
                        _paymentStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateBooking,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text("Update Booking"),
                  ),
                ],
              ),
            ),
    );
  }
}
