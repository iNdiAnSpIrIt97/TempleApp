import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:temple_app/pages/Login/login_page.dart';
import 'pooja_booking_page.dart';
import 'package:temple_app/pages/Login/login_landing.dart';
import 'dart:developer' as developer;

class PoojaListPage extends StatefulWidget {
  const PoojaListPage({super.key});

  @override
  _PoojaListPageState createState() => _PoojaListPageState();
}

class _PoojaListPageState extends State<PoojaListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<DateTime>> _fetchBookedDates(String poojaId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('poojas').doc(poojaId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['booked_dates'] as List<dynamic>? ?? [])
            .map((date) => DateTime.parse(date as String).toLocal())
            .toList();
      }
      return [];
    } catch (e) {
      developer.log('Error fetching booked dates: $e');
      return [];
    }
  }

  void _showCalendarDialog(
      BuildContext context, String poojaId, String title, int amount) {
    DateTime? selectedDay;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => Center(
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: Colors.white,
              title: Text(
                'Book $title',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height *
                    0.50, // Increased height slightly
                child: Column(
                  children: [
                    Expanded(
                      child: FutureBuilder<List<DateTime>>(
                        future: _fetchBookedDates(poojaId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.orange));
                          }
                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error loading dates'));
                          }

                          final bookedDates = snapshot.data ?? [];

                          return TableCalendar(
                            firstDay: DateTime.now(),
                            lastDay: DateTime(DateTime.now().year, 12, 31),
                            focusedDay: DateTime.now(),
                            selectedDayPredicate: (day) =>
                                isSameDay(selectedDay, day),
                            onDaySelected: (selected, focused) {
                              if (bookedDates
                                  .any((date) => isSameDay(date, selected))) {
                                return;
                              }
                              setState(() {
                                selectedDay = selected;
                              });
                            },
                            enabledDayPredicate: (day) => !bookedDates
                                .any((date) => isSameDay(date, day)),
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              todayDecoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              defaultTextStyle:
                                  const TextStyle(color: Colors.black87),
                              weekendTextStyle:
                                  const TextStyle(color: Colors.red),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                color: Colors.orange,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            calendarBuilders: CalendarBuilders(
                              disabledBuilder: (context, day, focusedDay) {
                                if (bookedDates
                                    .any((date) => isSameDay(date, day))) {
                                  return Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      width: 40,
                                      height: 40,
                                      child: Center(
                                        child: Text(
                                          '${day.day}',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return null;
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (_auth.currentUser == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Text(
                          'Please login to book',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedDay != null && _auth.currentUser != null
                      ? () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PoojaBookingPage(
                                poojaId: poojaId,
                                selectedDate: selectedDay!,
                                title: title,
                                amount: amount,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pooja List'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('poojas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No poojas available.'));
          }

          final poojas = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: poojas.length,
            itemBuilder: (context, index) {
              final pooja = poojas[index].data() as Map<String, dynamic>;
              final poojaId = poojas[index].id;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    pooja['title'] ?? 'Unnamed Pooja',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Amount: ₹${pooja['amount'] ?? '0'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      final title = pooja['title'] ?? 'Unnamed Pooja';
                      final amount =
                          int.tryParse(pooja['amount'].toString()) ?? 0;
                      _showCalendarDialog(context, poojaId, title, amount);
                    },
                    child: const Text('Book', style: TextStyle(fontSize: 16)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
