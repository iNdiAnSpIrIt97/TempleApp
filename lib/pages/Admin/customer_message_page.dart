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
      String formattedReply =
          "Admin: ${_replyController.text.trim()}"; // Format admin reply
      await _firestore.collection('customer_messages').doc(messageId).update({
        'replied_on': replyDate,
        'reply_by_admin': true,
        'status': 'Replied',
        'replies': FieldValue.arrayUnion([formattedReply]),
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
            items: ['Pending', 'Replied', 'Closed'].map((String value) {
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
                  'status': newStatus,
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

  void _showReplyDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Conversation"),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('customer_messages')
                .doc(messageId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var message = snapshot.data!.data() as Map<String, dynamic>?;
              List<dynamic> replies = message?['replies'] ?? [];
              String status = message?['status'] ?? 'Pending';

              if (status == 'Closed') {
                return const Text("Conversation closed.");
              }

              if (replies.isEmpty || replies.every((r) => r == '')) {
                return const Text("No replies yet.");
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: replies.length,
                itemBuilder: (context, index) {
                  String reply = replies[index] as String? ?? '';
                  if (reply.isEmpty)
                    return const SizedBox.shrink(); // Skip empty strings
                  return ListTile(
                    title: Text(reply),
                    tileColor: reply.startsWith('Admin:')
                        ? Colors.blue[50]
                        : Colors.green[50],
                  );
                },
              );
            },
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

  @override
  void dispose() {
    _replyController.dispose();
    _searchController.dispose();
    super.dispose();
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
                  String issue = (message['issue'] ?? 'N/A').toLowerCase();
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
                      compare = (a['status'] ?? 'Pending')
                          .compareTo(b['status'] ?? 'Pending');
                      break;
                    case 'Date':
                    default:
                      compare = (a['date'] as Timestamp? ?? Timestamp.now())
                          .compareTo(
                              b['date'] as Timestamp? ?? Timestamp.now());
                  }
                  return _sortAscending ? compare : -compare;
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    var message = filteredMessages[index];
                    String messageId = message.id;
                    Timestamp? date = message['date'];
                    String description = message['description'] ?? 'N/A';
                    String issue = message['issue'] ?? 'N/A';
                    String repliedOn = message['replied_on'] ?? '';
                    bool replyByAdmin =
                        message['reply_by_admin'] as bool? ?? false;
                    String status = message['status'] ?? 'Pending';
                    String userId = message['user_id'] ?? 'N/A';
                    String userName = message['user_name'] ?? 'N/A';
                    List<dynamic> replies = message['replies'] ?? [];

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
                                if (replies.length > 1 ||
                                    (replies.length == 1 && replies[0] != ''))
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _showReplyDialog(messageId),
                                    child: const Text("See Conversation"),
                                  ),
                                if (status != 'Closed')
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
