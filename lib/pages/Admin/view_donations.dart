import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = "";
  String _sortOption = "date_desc";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donations"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "View Donations"),
            Tab(text: "Add/Edit Donation"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildViewDonations(),
          _buildAddEditDonationType(),
        ],
      ),
    );
  }

  Widget _buildViewDonations() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search by name, phone, or donation for",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: () {
                  _showSortOptions();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: _firestore.collection('donations').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No donations found"));
              }
              var donations = snapshot.data!.docs;

              donations = donations.where((donation) {
                return (donation['userName']?.toString().toLowerCase() ?? "")
                        .contains(_searchQuery) ||
                    (donation['phone']?.toString().toLowerCase() ?? "")
                        .contains(_searchQuery) ||
                    (donation['donation_for']?.toString().toLowerCase() ?? "")
                        .contains(_searchQuery);
              }).toList();

              try {
                if (_sortOption == "date_desc") {
                  donations.sort((a, b) =>
                      (b['date'] is Timestamp && a['date'] is Timestamp)
                          ? (b['date'] as Timestamp)
                              .compareTo(a['date'] as Timestamp)
                          : 0);
                } else if (_sortOption == "date_asc") {
                  donations.sort((a, b) =>
                      (a['date'] is Timestamp && b['date'] is Timestamp)
                          ? (a['date'] as Timestamp)
                              .compareTo(b['date'] as Timestamp)
                          : 0);
                } else if (_sortOption == "amount_desc") {
                  donations.sort((a, b) {
                    int amountA =
                        int.tryParse(a['amount']?.toString() ?? '0') ?? 0;
                    int amountB =
                        int.tryParse(b['amount']?.toString() ?? '0') ?? 0;
                    return amountB.compareTo(amountA);
                  });
                } else if (_sortOption == "amount_asc") {
                  donations.sort((a, b) {
                    int amountA =
                        int.tryParse(a['amount']?.toString() ?? '0') ?? 0;
                    int amountB =
                        int.tryParse(b['amount']?.toString() ?? '0') ?? 0;
                    return amountA.compareTo(amountB);
                  });
                }
              } catch (e) {
                print("Sorting error: $e");
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: donations.length,
                itemBuilder: (context, index) {
                  var donation = donations[index];
                  bool isGuest = false;
                  if (donation['guest_user'] as bool == true) {
                    setState(() {
                      isGuest = true;
                    });
                  }
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                donation['userName'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isGuest
                                      ? Colors.redAccent
                                      : Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isGuest ? 'Guest' : 'User',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text("Amount: ₹${donation['amount'] ?? '0'}",
                              style: const TextStyle(fontSize: 16)),
                          Text(
                              "Payment Id: ${donation['paymentId'] ?? 'N/A'}",
                              style: const TextStyle(fontSize: 16)),
                          Text(
                              "Donation For: ${donation['donationType'] ?? 'N/A'}",
                              style: const TextStyle(fontSize: 16)),
                          // Text("Phone: ${donation['phone'] ?? 'N/A'}",
                          //     style: const TextStyle(fontSize: 16)),
                          Text(
                            "Date: ${donation['timestamp'] is Timestamp ? (donation['timestamp'] as Timestamp).toDate().toLocal().toString() : 'N/A'}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sort By",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text("Newest"),
                leading: Radio<String>(
                  value: "date_desc",
                  groupValue: _sortOption,
                  onChanged: (value) {
                    setState(() {
                      _sortOption = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text("Oldest"),
                leading: Radio<String>(
                  value: "date_asc",
                  groupValue: _sortOption,
                  onChanged: (value) {
                    setState(() {
                      _sortOption = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text("Highest Amount"),
                leading: Radio<String>(
                  value: "amount_desc",
                  groupValue: _sortOption,
                  onChanged: (value) {
                    setState(() {
                      _sortOption = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text("Lowest Amount"),
                leading: Radio<String>(
                  value: "amount_asc",
                  groupValue: _sortOption,
                  onChanged: (value) {
                    setState(() {
                      _sortOption = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddEditDonationType() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('donation_list').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No donation types found"));
              }

              var donationTypes = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: donationTypes.length,
                itemBuilder: (context, index) {
                  var donationType = donationTypes[index];
                  String id = donationType.id;
                  String amount = donationType['Amount'] ?? '';
                  String title = donationType['Title'] ?? '';

                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    child: ListTile(
                      title: Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text("Amount: ₹$amount",
                          style: const TextStyle(fontSize: 16)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _showEditDonationTypeDialog(id, amount, title);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: () {
              _showAddDonationTypeDialog();
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showAddDonationTypeDialog() {
    TextEditingController amountController = TextEditingController();
    TextEditingController titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Donation Type"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: "Amount",
                  hintText: "e.g., 1000",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "e.g., Annadanam (5 persons)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty &&
                    titleController.text.isNotEmpty) {
                  await _firestore.collection('donation_list').add({
                    'Amount': amountController.text,
                    'Title': titleController.text,
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _showEditDonationTypeDialog(String id, String amount, String title) {
    TextEditingController amountController =
        TextEditingController(text: amount);
    TextEditingController titleController = TextEditingController(text: title);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Donation Type"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: "Amount",
                  hintText: "e.g., 1000",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "e.g., Annadanam (5 persons)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty &&
                    titleController.text.isNotEmpty) {
                  await _firestore.collection('donation_list').doc(id).update({
                    'Amount': amountController.text,
                    'Title': titleController.text,
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
