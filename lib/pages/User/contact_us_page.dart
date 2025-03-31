import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({Key? key}) : super(key: key);

  @override
  _ContactUsPageState createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Show tabs only for authenticated users
    _tabController = TabController(
      length: _auth.currentUser != null ? 2 : 0, // No tabs for guest users
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Generate a sequential ticket ID (e.g., MPK00000001)
  Future<String> _generateTicketId() async {
    final ticketCounterRef =
        _firestore.collection('counters').doc('ticket_counter');
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ticketCounterRef);
      int currentCount = snapshot.exists ? snapshot.get('count') as int : 0;
      String newTicketId =
          'MPK${(currentCount + 1).toString().padLeft(8, '0')}';
      transaction.set(ticketCounterRef, {'count': currentCount + 1},
          SetOptions(merge: true));
      return newTicketId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
        bottom: _auth.currentUser != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'New Ticket'),
                  Tab(text: 'My Tickets'),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
              )
            : null, // No tabs for guest users
      ),
      body: _auth.currentUser != null
          ? TabBarView(
              controller: _tabController,
              children: [
                ContactFormTab(
                    firestore: _firestore,
                    auth: _auth,
                    generateTicketId: _generateTicketId),
                TicketHistoryTab(firestore: _firestore, auth: _auth),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Submit a Ticket',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: const Text(
                                'Login or Register to Raise a ticket',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contact Information',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.location_on,
                                color: Colors.orange),
                            title: const Text(
                                'East Yakara, Manapullikavu, Palakkad, Kerala 678013'),
                            onTap: () => launchUrl(Uri.parse(
                                'https://maps.app.goo.gl/sSVq7drjnEga23YdA')),
                          ),
                          ListTile(
                            leading:
                                const Icon(Icons.email, color: Colors.orange),
                            title: const Text('manappullykavu@gmail.com'),
                            onTap: () => launchUrl(
                                Uri.parse('mailto:manappullykavu@gmail.com')),
                          ),
                          ListTile(
                            leading:
                                const Icon(Icons.phone, color: Colors.orange),
                            title: const Text('0491 253 9431'),
                            onTap: () =>
                                launchUrl(Uri.parse('tel:0491 253 9431')),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse(
                                'https://maps.app.goo.gl/sSVq7drjnEga23YdA')),
                            child: Image.asset(
                              'assets/images/maps.png', // Correct asset path as a string
                              height: 200,
                              width: 320, // Height property
                              fit: BoxFit.cover, // Fit property
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Contact Form Tab
class ContactFormTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Future<String> Function() generateTicketId;

  const ContactFormTab({
    required this.firestore,
    required this.auth,
    required this.generateTicketId,
    Key? key,
  }) : super(key: key);

  @override
  _ContactFormTabState createState() => _ContactFormTabState();
}

class _ContactFormTabState extends State<ContactFormTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _issueController = TextEditingController();
  final _descriptionController = TextEditingController();
  PlatformFile? _attachment;
  bool _isSubmitting = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        final user = widget.auth.currentUser;
        String ticketId = await widget.generateTicketId();
        final messageData = {
          'ticket_id': ticketId,
          'user_name': _nameController.text,
          'email': _emailController.text,
          'issue': _issueController.text,
          'description': _descriptionController.text,
          'date': Timestamp.fromDate(DateTime.now()),
          'user_id':
              user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
          'isGuest': user == null,
          'status': 'Pending',
          'reply_by_admin': false,
          'replied_on': '', // Default empty string
          'replies': [''], // Default array with empty string
          'attachment': _attachment != null ? _attachment!.name : null,
        };

        await widget.firestore.collection('customer_messages').add(messageData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Ticket submitted successfully with ID: $ticketId')),
        );

        _formKey.currentState!.reset();
        _nameController.clear();
        _emailController.clear();
        _issueController.clear();
        _descriptionController.clear();
        setState(() => _attachment = null);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting ticket: $e')),
        );
      }
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _attachment = result.files.first);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _issueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Submit a Ticket',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      validator: (value) =>
                          value!.isEmpty || !value.contains('@')
                              ? 'Please enter a valid email'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _issueController,
                      decoration: InputDecoration(
                        labelText: 'Issue',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.report_problem),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter your issue' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a description' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickAttachment,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Attach File'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        if (_attachment != null)
                          Flexible(
                              child: Text(_attachment!.name,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Submit',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Information',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    leading:
                        const Icon(Icons.location_on, color: Colors.orange),
                    title: const Text('123 Temple Road, City, Country'),
                    onTap: () => launchUrl(
                        Uri.parse('https://maps.app.goo.gl/sSVq7drjnEga23YdA')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.orange),
                    title: const Text('support@example.com'),
                    onTap: () =>
                        launchUrl(Uri.parse('mailto:support@example.com')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.orange),
                    title: const Text('+1 234 567 8900'),
                    onTap: () => launchUrl(Uri.parse('tel:+12345678900')),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => launchUrl(
                        Uri.parse('https://maps.app.goo.gl/sSVq7drjnEga23YdA')),
                    child: Image.network(
                      'https://maps.googleapis.com/maps/api/staticmap?center=37.8199,-122.4783&zoom=14&size=400x200&key=YOUR_STATIC_MAP_API_KEY',
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Ticket History Tab
class TicketHistoryTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const TicketHistoryTab({
    required this.firestore,
    required this.auth,
    Key? key,
  }) : super(key: key);

  @override
  _TicketHistoryTabState createState() => _TicketHistoryTabState();
}

class _TicketHistoryTabState extends State<TicketHistoryTab> {
  final TextEditingController _replyController = TextEditingController();

  Future<void> _showUserDetails(String userId) async {
    DocumentSnapshot userDoc =
        await widget.firestore.collection('users').doc(userId).get();
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
      String formattedReply = widget.auth.currentUser != null
          ? "User: ${_replyController.text.trim()}"
          : "User: ${_replyController.text.trim()}"; // User reply
      await widget.firestore
          .collection('customer_messages')
          .doc(messageId)
          .update({
        'replies': FieldValue.arrayUnion([formattedReply]),
        'replied_on': replyDate,
        'reply_by_admin': false, // Ensure reply_by_admin is false for user
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
                await widget.firestore
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
            stream: widget.firestore
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('customer_messages')
                .where('user_id', isEqualTo: widget.auth.currentUser!.uid)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No tickets found.'));
              }

              final tickets = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index].data() as Map<String, dynamic>;
                  final messageId = tickets[index].id;
                  List<dynamic> replies = ticket['replies'] ?? [];
                  bool replyByAdmin =
                      ticket['reply_by_admin'] as bool? ?? false;
                  String status = ticket['status'] ?? 'Pending';
                  String repliedOn = ticket['replied_on'] ?? '';

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: Icon(
                        ticket['status'] == 'Pending'
                            ? Icons.hourglass_empty
                            : Icons.check_circle,
                        color: ticket['status'] == 'Pending'
                            ? Colors.orange
                            : Colors.green,
                      ),
                      title: Text(
                        ticket['issue'] ?? 'No Issue',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Submitted: ${ticket['date'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((ticket['date'] as Timestamp).toDate()) : 'N/A'} | Ticket ID: ${ticket['ticket_id'] ?? 'N/A'}',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Description: ${ticket['description'] ?? 'N/A'}'),
                              const SizedBox(height: 8),
                              Text('Status: ${ticket['status'] ?? 'Pending'}'),
                              if (replyByAdmin && repliedOn.isNotEmpty)
                                Text('Last Replied On: $repliedOn'),
                              if (ticket['attachment'] != null) ...[
                                const SizedBox(height: 8),
                                Text('Attachment: ${ticket['attachment']}'),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                alignment: WrapAlignment.end,
                                children: [
                                  if (replies.length > 1 ||
                                      (replies.length == 1 && replies[0] != ''))
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showReplyDialog(messageId),
                                      child: const Text("See Conversation"),
                                    ),
                                  if (replyByAdmin && status != 'Closed')
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title:
                                                const Text("Reply to Ticket"),
                                            content: TextField(
                                              controller: _replyController,
                                              decoration: const InputDecoration(
                                                  labelText:
                                                      "Enter your reply"),
                                              maxLines: 3,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text("Cancel"),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _replyToMessage(messageId,
                                                        ticket['user_id']),
                                                child: const Text("Send"),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: const Text("Reply"),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        _showUserDetails(ticket['user_id']),
                                    tooltip: 'View User Details',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
