import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GuestDetails {
  TextEditingController nameController = TextEditingController();
  TextEditingController ageController = TextEditingController();
  TextEditingController idNumberController = TextEditingController();
  String? idType;

  GuestDetails({String? name, String? age, String? idNumber, String? idType}) {
    nameController.text = name ?? '';
    ageController.text = age ?? '';
    idNumberController.text = idNumber ?? '';
    this.idType = idType ?? 'AADHAAR';
  }

  Map<String, dynamic> toJson() => {
        'name': nameController.text,
        'age': int.tryParse(ageController.text) ?? 0,
        'id_number': idNumberController.text,
        'id_type': idType ?? 'AADHAAR',
      };
}

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
  List<GuestDetails> _guestDetails = [];
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _userEmailController = TextEditingController();
  final TextEditingController _userPhoneController = TextEditingController();
  DateTime? _bookingDate;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _swapRoom;
  String? _originalAllocatedRoom;
  bool _paymentStatus = false;
  bool _guestUser = false;
  int _persons = 1;
  String? _roomTitle;
  String? _roomType;
  String? _status;
  List<String> _availableRooms = [];
  bool _isLoading = true;

  final List<String> _idTypeOptions = [
    'AADHAAR',
    'Voter ID',
    'Driving License'
  ];
  final List<String> _statusOptions = ['confirmed', 'pending', 'cancelled'];

  @override
  void initState() {
    super.initState();
    print(
        'Initializing EditRoomBookingPage - Booking ID: ${widget.bookingId}, Room ID: ${widget.roomId}, Selected Day: ${widget.selectedDay}');
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    try {
      print('Fetching booking document for ID: ${widget.bookingId}');
      DocumentSnapshot bookingDoc =
          await _firestore.collection('bookings').doc(widget.bookingId).get();
      print('Booking document exists: ${bookingDoc.exists}');
      if (bookingDoc.exists) {
        var data = bookingDoc.data() as Map<String, dynamic>;
        print('Booking data: $data');
        setState(() {
          // Handle guests (assuming guest_names and id_number should be in guests)
          List<dynamic> guests = data['guests'] ?? [];
          if (guests.isEmpty && data['guest_names'] != null) {
            // Fallback for your current data structure
            List<String> guestNames =
                List<String>.from(data['guest_names'] ?? []);
            _guestDetails = guestNames.map((name) {
              return GuestDetails(
                name: name,
                idNumber: data['id_number'],
              );
            }).toList();
          } else {
            _guestDetails = guests.map((guest) {
              return GuestDetails(
                name: guest['name'],
                age: guest['age']?.toString(),
                idNumber: guest['id_number'],
                idType: guest['id_type'],
              );
            }).toList();
          }
          print(
              'Loaded ${_guestDetails.length} guests: ${_guestDetails.map((g) => g.nameController.text).toList()}');

          _userNameController.text = data['user_name'] ?? '';
          _amountController.text = data['amount']?.toString() ?? '';
          _userEmailController.text = data['user_email'] ?? '';
          _userPhoneController.text = data['user_phone'] ?? '';
          _bookingDate = (data['booking_date'] as Timestamp?)?.toDate();
          _fromDate = (data['from_date'] as Timestamp?)?.toDate();
          _toDate = (data['to_date'] as Timestamp?)?.toDate();
          _originalAllocatedRoom = data['allocated_room'];
          _swapRoom = data['allocated_room'];
          _paymentStatus = data['payment_status'] ?? false;
          _guestUser = data['guest_user'] ?? false;
          _persons = data['persons'] ?? 1;
          _roomTitle = data['room_title'];
          _roomType = data['room_type'];
          _status = data['status'] ?? 'confirmed';
          print(
              'Loaded details - User: ${_userNameController.text}, Amount: ${_amountController.text}, Room: $_originalAllocatedRoom');
        });
      } else {
        print('No booking found for ID: ${widget.bookingId}');
      }

      int epochMidnight = DateTime(widget.selectedDay.year,
                  widget.selectedDay.month, widget.selectedDay.day)
              .millisecondsSinceEpoch ~/
          1000;
      print('Fetching availability for epoch: $epochMidnight');
      DocumentSnapshot availabilityDoc = await _firestore
          .collection('room_availability')
          .doc(widget.roomId)
          .collection('date_wise_booking')
          .doc(epochMidnight.toString())
          .get();
      if (availabilityDoc.exists) {
        _availableRooms =
            List<String>.from(availabilityDoc['room_nos_available'] ?? []);
        print('Available rooms: $_availableRooms');
      } else {
        DocumentSnapshot roomDoc =
            await _firestore.collection('room').doc(widget.roomId).get();
        _availableRooms = List<String>.from(roomDoc['room_nos'] ?? []);
        _availableRooms.remove(_originalAllocatedRoom);
        print('Available rooms from room doc: $_availableRooms');
      }
    } catch (e) {
      print('Error loading booking details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBooking() async {
    setState(() => _isLoading = true);
    try {
      print('Updating booking for ID: ${widget.bookingId}');
      await _firestore.collection('bookings').doc(widget.bookingId).update({
        'guests': _guestDetails.map((g) => g.toJson()).toList(),
        'user_name': _userNameController.text,
        'amount': int.tryParse(_amountController.text) ?? 0,
        'user_email': _userEmailController.text,
        'user_phone': _userPhoneController.text,
        'booking_date':
            _bookingDate != null ? Timestamp.fromDate(_bookingDate!) : null,
        'from_date': _fromDate != null ? Timestamp.fromDate(_fromDate!) : null,
        'to_date': _toDate != null ? Timestamp.fromDate(_toDate!) : null,
        'allocated_room': _swapRoom,
        'payment_status': _paymentStatus,
        'guest_user': _guestUser,
        'persons': _persons,
        'room_title': _roomTitle,
        'room_type': _roomType,
        'status': _status,
      });

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

      if (_originalAllocatedRoom != _swapRoom) {
        if (!availabilityDoc.exists) {
          DocumentSnapshot roomDoc =
              await _firestore.collection('room').doc(widget.roomId).get();
          List<String> allRooms = List<String>.from(roomDoc['room_nos'] ?? []);
          await availabilityRef.set({
            'booked_rooms': [_swapRoom],
            'booking_id': [widget.bookingId],
            'room_nos_available':
                allRooms.where((room) => room != _swapRoom).toList(),
            'total_bookings': 1,
          });
        } else {
          List<String> bookedRooms =
              List<String>.from(availabilityDoc['booked_rooms'] ?? []);
          List<String> availableRooms =
              List<String>.from(availabilityDoc['room_nos_available'] ?? []);
          int totalBookings = availabilityDoc['total_bookings'] ?? 0;

          bookedRooms.remove(_originalAllocatedRoom);
          bookedRooms.add(_swapRoom!);
          availableRooms.remove(_swapRoom);
          if (_originalAllocatedRoom != null) {
            availableRooms.add(_originalAllocatedRoom!);
          }

          await availabilityRef.update({
            'booked_rooms': bookedRooms,
            'room_nos_available': availableRooms,
            'total_bookings': totalBookings,
          });
        }
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

  Future<void> _pickDate(BuildContext context, String field) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      setState(() {
        if (field == 'booking') {
          _bookingDate = pickedDate;
        } else if (field == 'from') {
          _fromDate = pickedDate;
        } else if (field == 'to') {
          _toDate = pickedDate;
        }
      });
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
                  Text("Booking Details",
                      style: Theme.of(context).textTheme.titleLarge),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: "Amount"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(
                        text: _bookingDate != null
                            ? DateFormat('yyyy-MM-dd').format(_bookingDate!)
                            : ''),
                    decoration: InputDecoration(
                      labelText: "Booking Date",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _pickDate(context, 'booking'),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(
                        text: _fromDate != null
                            ? DateFormat('yyyy-MM-dd').format(_fromDate!)
                            : ''),
                    decoration: InputDecoration(
                      labelText: "From Date",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _pickDate(context, 'from'),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(
                        text: _toDate != null
                            ? DateFormat('yyyy-MM-dd').format(_toDate!)
                            : ''),
                    decoration: InputDecoration(
                      labelText: "To Date",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _pickDate(context, 'to'),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: _roomTitle),
                    decoration: const InputDecoration(labelText: "Room Title"),
                    readOnly: true, // Typically not editable
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: _roomType),
                    decoration: const InputDecoration(labelText: "Room Type"),
                    readOnly: true, // Typically not editable
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _status = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: "Status"),
                  ),
                  const SizedBox(height: 20),
                  Text("Guest Details",
                      style: Theme.of(context).textTheme.titleLarge),
                  if (_guestDetails.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("No guest details available"),
                    )
                  else
                    ..._guestDetails.asMap().entries.map((entry) {
                      int index = entry.key;
                      GuestDetails guest = entry.value;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Guest ${index + 1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              TextField(
                                controller: guest.nameController,
                                decoration:
                                    const InputDecoration(labelText: "Name"),
                              ),
                              TextField(
                                controller: guest.ageController,
                                decoration:
                                    const InputDecoration(labelText: "Age"),
                                keyboardType: TextInputType.number,
                              ),
                              TextField(
                                controller: guest.idNumberController,
                                decoration: const InputDecoration(
                                    labelText: "ID Number"),
                              ),
                              DropdownButtonFormField<String>(
                                value: guest.idType,
                                items: _idTypeOptions.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    guest.idType = value;
                                  });
                                },
                                decoration:
                                    const InputDecoration(labelText: "ID Type"),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _guestDetails.removeAt(index);
                                  });
                                },
                                child: const Text("Remove Guest",
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _guestDetails.add(GuestDetails());
                      });
                    },
                    child: const Text("Add Guest"),
                  ),
                  const SizedBox(height: 16),
                  Text("User Details",
                      style: Theme.of(context).textTheme.titleLarge),
                  TextField(
                    controller: _userNameController,
                    decoration: const InputDecoration(labelText: "User Name"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userEmailController,
                    decoration: const InputDecoration(labelText: "User Email"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userPhoneController,
                    decoration: const InputDecoration(labelText: "User Phone"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text("Guest User"),
                    value: _guestUser,
                    onChanged: (value) {
                      setState(() {
                        _guestUser = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller:
                        TextEditingController(text: _persons.toString()),
                    decoration: const InputDecoration(labelText: "Persons"),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _persons = int.tryParse(value) ?? 1;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text("Room Allocation",
                      style: Theme.of(context).textTheme.titleLarge),
                  TextField(
                    controller:
                        TextEditingController(text: _originalAllocatedRoom),
                    decoration: const InputDecoration(
                      labelText: "Current Allocated Room",
                      enabled: false,
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
