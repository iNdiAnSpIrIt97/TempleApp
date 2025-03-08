import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PoojaManagementPage extends StatefulWidget {
  const PoojaManagementPage({super.key});

  @override
  State<PoojaManagementPage> createState() => _PoojaManagementPageState();
}

class _PoojaManagementPageState extends State<PoojaManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  List<DateTime> _selectedDates = [];
  List<DateTime> _blockedDates = [];

  @override
  void initState() {
    super.initState();
    _fetchBlockedDates();
  }

  Future<void> _fetchBlockedDates() async {
    try {
      final snapshot = await _firestore.collection('poojas').get();
      final blockedDates = <DateTime>[];
      for (final doc in snapshot.docs) {
        final dates = doc['booked_dates'] as List<dynamic>;
        for (final date in dates) {
          blockedDates.add(DateTime.parse(date));
        }
      }
      setState(() {
        _blockedDates = blockedDates;
      });
      print("Fetched Blocked Dates: $_blockedDates"); // Debugging
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching blocked dates: $e")),
      );
    }
  }

  Future<void> _selectDate(
      BuildContext context, List<DateTime> bookedDates, String poojaId) async {
    try {
      // Ensure the initial date is not blocked
      DateTime initialDate = DateTime.now();
      while (_blockedDates.any((blockedDate) =>
          blockedDate.year == initialDate.year &&
          blockedDate.month == initialDate.month &&
          blockedDate.day == initialDate.day)) {
        initialDate =
            initialDate.add(const Duration(days: 1)); // Move to the next day
      }

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate, // Use the validated initial date
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
        selectableDayPredicate: (DateTime date) {
          // Ensure the date is not in the blocked list
          return !_blockedDates.any((blockedDate) =>
              blockedDate.year == date.year &&
              blockedDate.month == date.month &&
              blockedDate.day == date.day);
        },
      );

      if (picked != null && !bookedDates.contains(picked)) {
        // Add the selected date to Firestore
        await _firestore.collection('poojas').doc(poojaId).update({
          'booked_dates': FieldValue.arrayUnion([picked.toIso8601String()]),
        });

        // Refresh the blocked dates list
        _fetchBlockedDates();

        // Update the local state
        setState(() {
          bookedDates.add(picked);
        });

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Date added successfully!")),
        );
      }
    } catch (e) {
      print("Error in _selectDate: $e"); // Debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting date: $e")),
      );
    }
  }

  Future<void> _addPooja() async {
    final title = _titleController.text.trim();
    final amount = _amountController.text.trim();
    if (title.isEmpty || amount.isEmpty || _selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required!")),
      );
      return;
    }
    try {
      await _firestore.collection('poojas').add({
        'title': title,
        'amount': amount,
        'booked_dates':
            _selectedDates.map((date) => date.toIso8601String()).toList(),
      });
      _titleController.clear();
      _amountController.clear();
      setState(() => _selectedDates.clear());
      _fetchBlockedDates(); // Refresh blocked dates
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pooja added successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding pooja: $e")),
      );
    }
  }

  Future<void> _editPooja(String poojaId, String title, String amount) async {
    try {
      await _firestore.collection('poojas').doc(poojaId).update({
        'title': title,
        'amount': amount,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pooja updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating pooja: $e")),
      );
    }
  }

  Future<void> _deletePooja(String poojaId) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this Pooja?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _firestore.collection('poojas').doc(poojaId).delete();
        _fetchBlockedDates(); // Refresh blocked dates
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pooja deleted successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting pooja: $e")),
        );
      }
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this booking?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _firestore.collection('pooja_bookings').doc(bookingId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking deleted successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting booking: $e")),
        );
      }
    }
  }

  void _showBookingDetails(DocumentSnapshot booking) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(booking['pooja_title']),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("User: ${booking['user_name']}"),
              Text("Star Sign: ${booking['star_sign']}"),
              Text("Date Booked: ${booking['date_booked']}"),
              Text("Payment: ${booking['payment']}"),
              Text("Payment ID: ${booking['payment_id']}"),
              Text("Payment Date & Time: ${booking['payment_date_time']}"),
              Text("Amount: ₹${booking['amount']}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void _showAddPoojaDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Pooja"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Pooja Title"),
              ),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Wrap(
                children: _selectedDates.map((date) {
                  return Chip(label: Text(date.toIso8601String()));
                }).toList(),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  // Save the Pooja first to get the document ID
                  final title = _titleController.text.trim();
                  final amount = _amountController.text.trim();
                  if (title.isEmpty || amount.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Title and Amount are required!")),
                    );
                    return;
                  }

                  try {
                    // Add the Pooja to Firestore
                    final docRef = await _firestore.collection('poojas').add({
                      'title': title,
                      'amount': amount,
                      'booked_dates': _selectedDates
                          .map((date) => date.toIso8601String())
                          .toList(),
                    });

                    // Get the document ID
                    final poojaId = docRef.id;

                    // Now allow the user to select dates
                    await _selectDate(context, _selectedDates, poojaId);

                    // Refresh the UI
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error adding Pooja: $e")),
                    );
                  }
                },
                child: const Text("Select Date"),
              ),
              ElevatedButton(
                onPressed: () {
                  _addPooja();
                  Navigator.pop(context);
                },
                child: const Text("Add Pooja"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditPoojaDialog(DocumentSnapshot pooja) {
    final titleController = TextEditingController(text: pooja['title']);
    final amountController = TextEditingController(text: pooja['amount']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Pooja"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Pooja Title"),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _editPooja(
                  pooja.id,
                  titleController.text.trim(),
                  amountController.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Pooja Management"),
          bottom: TabBar(
            tabs: const [
              Tab(text: "View Bookings"),
              Tab(text: "Update Poojas"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddPoojaDialog,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildBookingList(),
            _buildUpdatePoojaTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    return StreamBuilder(
      stream: _firestore.collection('pooja_bookings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No bookings found"));
        }
        return ListView(
          children: snapshot.data!.docs.map((doc) {
            return ListTile(
              title: Text(doc['pooja_title']),
              subtitle: Text(
                  "User: ${doc['user_name']}, Date: ${doc['date_booked']}"),
              onTap: () => _showBookingDetails(doc),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteBooking(doc.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildUpdatePoojaTab() {
    return StreamBuilder(
      stream: _firestore.collection('poojas').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No poojas found"));
        }
        return ListView(
          children: snapshot.data!.docs.map((doc) {
            final poojaId = doc.id; // Get the document ID
            final bookedDates = (doc['booked_dates'] as List<dynamic>)
                .map((date) => DateTime.parse(date))
                .toList();

            return ListTile(
              title: Text(doc['title']),
              subtitle: Text("Amount: ₹${doc['amount']}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context, bookedDates, poojaId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditPoojaDialog(doc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deletePooja(doc.id),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
