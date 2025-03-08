import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerMessagePage extends StatefulWidget {
  const CustomerMessagePage({super.key});

  @override
  State<CustomerMessagePage> createState() => _CustomerMessagePageState();
}

class _CustomerMessagePageState extends State<CustomerMessagePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'Date'; // Default sort by date
  bool _sortAscending = false;

  Future<void> _showUserDetails(String userId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User details not found")),
      );
      return;
    }

    var data = userDoc.data() as Map<String, dynamic>;
    String email = data['email'] ?? 'N/A';
    String phone = data['phone'] ?? 'N/A';
    String role = data['role'] ?? 'N/A';
    String userName = data['user_name'] ?? 'N/A';
    bool verified = data['verified'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("User Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Email: $email"),
              Text("Phone: $phone"),
              Text("Role: $role"),
              Text("User Name: $userName"),
              Text("Verified: $verified"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _replyToMessage(String messageId, String userId) async {
    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a reply")),
      );
      return;
    }

    try {
      String replyDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await _firestore.collection('customer_messages').doc(messageId).update({
        'Replied_on': replyDate,
        'Reply_by_admin': true,
        'Status': 'Replied',
        'Admin_reply': _replyController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reply sent successfully!")),
      );
      _replyController.clear();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending reply: $e")),
      );
    }
  }

  Future<void> _updateStatus(String messageId, String currentStatus) async {
    String? newStatus = currentStatus;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Ticket Status"),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButton<String>(
            value: newStatus,
            items: ['Pending', 'In Progress', 'Replied', 'Closed']
                .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                newStatus = value;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore
                    .collection('customer_messages')
                    .doc(messageId)
                    .update({
                  'Status': newStatus,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Status updated successfully!")),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error updating status: $e")),
                );
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(String? adminReply) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin Reply"),
        content: Text(adminReply ?? "No reply content available"),
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
      appBar: AppBar(
        title: const Text("Customer Messages"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by user or issue',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _sortBy,
                    items: ['Date', 'User', 'Status'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(_sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward),
                  onPressed: () {
                    setState(() {
                      _sortAscending = !_sortAscending;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('customer_messages').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages found"));
                }

                var messages = snapshot.data!.docs;
                // Filter messages
                var filteredMessages = messages.where((message) {
                  String userName =
                      (message['user_name'] ?? 'N/A').toLowerCase();
                  String issue = (message['Issue'] ?? 'N/A').toLowerCase();
                  return userName.contains(_searchQuery) ||
                      issue.contains(_searchQuery);
                }).toList();

                // Check if filtered results are empty
                if (filteredMessages.isEmpty && _searchQuery.isNotEmpty) {
                  return const Center(child: Text("No messages found"));
                }

                // Sort messages
                filteredMessages.sort((a, b) {
                  int compare;
                  switch (_sortBy) {
                    case 'User':
                      compare = (a['user_name'] ?? 'N/A')
                          .compareTo(b['user_name'] ?? 'N/A');
                      break;
                    case 'Status':
                      compare = (a['Status'] ?? 'Pending')
                          .compareTo(b['Status'] ?? 'Pending');
                      break;
                    case 'Date':
                    default:
                      compare = (a['Date'] as Timestamp? ?? Timestamp.now())
                          .compareTo(
                              b['Date'] as Timestamp? ?? Timestamp.now());
                  }
                  return _sortAscending ? compare : -compare;
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    var message = filteredMessages[index];
                    String messageId = message.id;
                    Timestamp? date = message['Date'];
                    String description = message['Description'] ?? 'N/A';
                    String issue = message['Issue'] ?? 'N/A';
                    String repliedOn = message['Replied_on'] ?? '';
                    bool replyByAdmin = message['Reply_by_admin'] ?? false;
                    String status = message['Status'] ?? 'Pending';
                    String userId = message['user_id'] ?? 'N/A';
                    String userName = message['user_name'] ?? 'N/A';
                    final messageData = message.data() as Map<String, dynamic>?;
                    String? adminReply =
                        messageData?.containsKey('Admin_reply') == true
                            ? messageData!['Admin_reply'] as String?
                            : null;

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    "$userName",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline,
                                      color: Colors.blue),
                                  onPressed: () => _showUserDetails(userId),
                                  tooltip: 'View User Details',
                                ),
                              ],
                            ),
                            const Divider(),
                            _buildInfoRow(
                                'Date:',
                                date != null
                                    ? DateFormat('yyyy-MM-dd HH:mm')
                                        .format(date.toDate())
                                    : 'N/A'),
                            _buildInfoRow('Issue:', issue),
                            _buildInfoRow('Description:', description),
                            Row(
                              children: [
                                const Text(
                                  'Status: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                status == 'Pending'
                                    ? const Icon(Icons.hourglass_empty,
                                        color: Colors.orange, size: 20)
                                    : Text(
                                        status,
                                        style: TextStyle(
                                          color: status == 'Replied'
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                              ],
                            ),
                            if (replyByAdmin && repliedOn.isNotEmpty)
                              _buildInfoRow('Replied On:', repliedOn),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              alignment: WrapAlignment.end,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _updateStatus(messageId, status),
                                  child: const Text("Update Status"),
                                ),
                                if (replyByAdmin && repliedOn.isNotEmpty)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _showReplyDialog(adminReply),
                                    child: const Text("See Reply"),
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Reply to Message"),
                                          content: TextField(
                                            controller: _replyController,
                                            decoration: const InputDecoration(
                                                labelText: "Enter your reply"),
                                            maxLines: 3,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed: () => _replyToMessage(
                                                  messageId, userId),
                                              child: const Text("Send"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text("Reply"),
                                  ),
                              ],
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
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: ' $value',
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
