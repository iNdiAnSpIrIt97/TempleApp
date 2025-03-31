import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OfferingsPage extends StatefulWidget {
  const OfferingsPage({super.key});

  @override
  State<OfferingsPage> createState() => _OfferingsPageState();
}

class _OfferingsPageState extends State<OfferingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedDeity = 'Devi'; // Change default selection to a valid deity

  final List<String> _deities = [
    'All',
    'Devi',
    'Ganesha',
    'Ayyappa',
    'Nagas',
    'Bhairavaa'
  ];

  /// Fetch offerings based on selected deity (null for all)
  Stream<QuerySnapshot> _getOfferingsStream(String? deity) {
    Query query = _firestore.collection('offerings');
    if (deity != null && deity != 'All') {
      query = query.where('deity', isEqualTo: deity);
    }
    return query.snapshots();
  }

  /// Adds a new offering
  Future<void> _addOffering() async {
    String name = _nameController.text.trim();
    String amount = _amountController.text.trim();

    if (name.isEmpty || amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required!")),
      );
      return;
    }

    await _firestore.collection('offerings').add({
      'name': name,
      'amount': amount,
      'deity': _selectedDeity,
    });

    _nameController.clear();
    _amountController.clear();
    Navigator.pop(context);
  }

  /// Show Add Offering Dialog
  void _showAddOfferingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Offering"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Offering Name"),
            ),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
            ),
            DropdownButtonFormField<String>(
              value: _selectedDeity,
              items: _deities.skip(1).map((deity) {
                return DropdownMenuItem(
                  value: deity,
                  child: Text(deity),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDeity = value!;
                });
              },
              decoration: const InputDecoration(labelText: "Deity"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: _addOffering,
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Offerings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddOfferingDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: _deities.map((deity) {
                bool isSelected = _selectedDeity == deity;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? Colors.blue.shade700 // Darker blue for selected
                          : Colors.grey.shade300, // Lighter grey for unselected
                      foregroundColor:
                          isSelected ? Colors.white : Colors.black87,
                      elevation:
                          isSelected ? 6 : 2, // Lift selected button for depth
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30), // More rounded edges
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDeity = deity;
                      });
                    },
                    child: Text(
                      deity,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _buildOfferingsList(
                _selectedDeity == 'All' ? null : _selectedDeity),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingsList(String? deity) {
    return StreamBuilder(
      stream: _getOfferingsStream(deity),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No offerings found"));
        }

        var offerings = snapshot.data!.docs;
        offerings.sort((a, b) => _deities
            .indexOf(a['deity'])
            .compareTo(_deities.indexOf(b['deity'])));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offerings.length,
          itemBuilder: (context, index) {
            var offering = offerings[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  offering['name'] ?? 'No Name',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Amount: ₹${offering['amount']}"),
                    Text("Deity: ${offering['deity']}",
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
