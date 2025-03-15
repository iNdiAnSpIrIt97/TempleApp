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

  Future<void> _selectDate(
      BuildContext context, List<DateTime> bookedDates, String poojaId) async {
    try {
      DateTime initialDate = DateTime.now();
      while (bookedDates.any((blockedDate) =>
          blockedDate.year == initialDate.year &&
          blockedDate.month == initialDate.month &&
          blockedDate.day == initialDate.day)) {
        initialDate = initialDate.add(const Duration(days: 1));
      }

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
        selectableDayPredicate: (DateTime date) {
          return !bookedDates.any((blockedDate) =>
              blockedDate.year == date.year &&
              blockedDate.month == date.month &&
              blockedDate.day == date.day);
        },
      );

      if (picked != null && !bookedDates.contains(picked)) {
        await _firestore.collection('poojas').doc(poojaId).update({
          'booked_dates': FieldValue.arrayUnion([picked.toIso8601String()]),
        });

        setState(() {
          bookedDates.add(picked);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Date added successfully!")),
        );
      }
    } catch (e) {
      print("Error in _selectDate: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting date: $e")),
      );
    }
  }

  Future<void> _addPooja() async {
    final title = _titleController.text.trim();
    final amount = _amountController.text.trim();
    if (title.isEmpty || amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required!")),
      );
      return;
    }
    try {
      await _firestore.collection('poojas').add({
        'title': title,
        'amount': amount,
        'booked_dates': [], // Initialize with empty array
      });
      _titleController.clear();
      _amountController.clear();
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
          title: Text(booking['title']),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _addPooja();
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
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
          bottom: const TabBar(
            tabs: [
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
              title: Text(doc['title']),
              subtitle: Text(
                  "UserId: ${doc['userId']}, Date: ${doc['selectedDate']}"),
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
            final poojaId = doc.id;
            final bookedDates = (doc['booked_dates'] as List<dynamic>? ?? [])
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
