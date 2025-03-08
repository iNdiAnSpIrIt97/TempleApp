import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, DateTime> blockedDates = {
    "Udayasthamana Pooja": DateTime(2025, 3, 20),
    "Chuttuvilak": DateTime(2025, 4, 10),
  };
  final Map<String, bool> isCalendarVisible = {
    "Udayasthamana Pooja": false,
    "Chuttuvilak": false,
  };
  String selectedRoomType = "AC Room";
  DateTime? fromDate;
  DateTime? toDate;
  bool isAvailable = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Room Booking"),
            Tab(text: "Pooja Booking"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoomBookingTab(),
          _buildPoojaBookingTab(),
        ],
      ),
    );
  }

  Widget _buildPoojaBookingTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: blockedDates.keys.map((pooja) {
        return Card(
          child: Column(
            children: [
              ListTile(
                title: Text(pooja),
                subtitle: Text(
                    "Amount: ₹${pooja == "Udayasthamana Pooja" ? "25000" : "10000"}"),
                trailing: IconButton(
                  icon: Icon(isCalendarVisible[pooja]!
                      ? Icons.calendar_today
                      : Icons.calendar_today_outlined),
                  onPressed: () {
                    setState(() {
                      isCalendarVisible[pooja] = !isCalendarVisible[pooja]!;
                    });
                  },
                ),
              ),
              if (isCalendarVisible[pooja]!) _buildCalendar(pooja),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendar(String title) {
    DateTime blockedUntil = blockedDates[title]!;
    return TableCalendar(
      focusedDay: DateTime.now(),
      firstDay: DateTime(2025, 1, 1),
      lastDay: DateTime(2025, 12, 31),
      calendarFormat: CalendarFormat.month,
      availableGestures: AvailableGestures.all,
      headerStyle:
          const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, _) {
          if (date.isBefore(blockedUntil)) {
            return Container(
              margin: const EdgeInsets.all(4.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.5), shape: BoxShape.circle),
              child: Text('${date.day}',
                  style: const TextStyle(color: Colors.white)),
            );
          } else {
            return Container(
              margin: const EdgeInsets.all(4.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.7), shape: BoxShape.circle),
              child: Text('${date.day}',
                  style: const TextStyle(color: Colors.white)),
            );
          }
        },
      ),
    );
  }

  Widget _buildRoomBookingTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2025, 12, 31),
                        );
                        if (picked != null) {
                          setState(() {
                            fromDate = picked;
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
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: fromDate ?? DateTime.now(),
                          firstDate: fromDate ?? DateTime.now(),
                          lastDate: DateTime(2025, 12, 31),
                        );
                        if (picked != null) {
                          setState(() {
                            toDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text("Select Room Type",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          DropdownButtonFormField<String>(
            value: selectedRoomType,
            items: ["AC Room", "Non-AC Room", "2 Bed Room", "Family Room"]
                .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                selectedRoomType = newValue!;
              });
            },
            decoration: InputDecoration(border: OutlineInputBorder()),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isAvailable = true;
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text("Check Availability"),
              ),
              ElevatedButton(
                onPressed: isAvailable ? () {} : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text("Book Now"),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text("Tariff List",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text("Check-in: 11:00 AM, Check-out: 10:00 AM"),
          _buildTariffList(),
        ],
      ),
    );
  }

  Widget _buildTariffList() {
    return Column(
      children: [
        _buildRoomCard("AC Room", "₹1500 per day"),
        _buildRoomCard("Non-AC Room", "₹1000 per day"),
        _buildRoomCard("2 Bed Room", "₹2000 per day"),
        _buildRoomCard("Family Room", "₹3000 per day"),
      ],
    );
  }

  Widget _buildRoomCard(String title, String price) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(price,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
