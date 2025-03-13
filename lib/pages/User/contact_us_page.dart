import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Function to add temporary test data
  Future<void> _addTestData() async {
    try {
      await _firestore.collection('customer_messages').add({
        'admin_reply': 'will be open till 10:30AM',
        'date': Timestamp.fromDate(DateTime.parse(
            '2025-03-09 00:07:02Z')), // UTC time for 5:37:02 AM UTC+5:30
        'description': 'Please share timings on Saturday.',
        'issue': 'Need to Know Timings',
        'replied_on': '2025-03-09 02:01:48',
        'reply_by_admin': true,
        'status': 'In Progress',
        'isGuest': false,
        'user_id': 'c95uEAtv4ec5q6gZLIZeY9t0mYI2',
        'user_name': 'mpkv_user',
        'email': 'mpkv_user@example.com', // Added as it's typically needed
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test data added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding test data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New Ticket'),
            Tab(text: 'My Tickets'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ContactFormTab(firestore: _firestore, auth: _auth),
          TicketHistoryTab(firestore: _firestore, auth: _auth),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTestData,
        backgroundColor: Colors.orange,
        tooltip: 'Add Test Data',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Contact Form Tab (unchanged from previous version)
class ContactFormTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const ContactFormTab({required this.firestore, required this.auth, Key? key})
      : super(key: key);

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
        final messageData = {
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
          'attachment': _attachment != null ? _attachment!.name : null,
        };

        await widget.firestore.collection('customer_messages').add(messageData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket submitted successfully')),
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
                    onTap: () => launchUrl(Uri.parse(
                        'https://maps.google.com/?q=123+Temple+Road')),
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
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                    ),
                    child: const Center(
                        child: Text(
                            'Map Placeholder\n(Integration with Google Maps API required)')),
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

// Ticket History Tab (unchanged from previous version)
class TicketHistoryTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const TicketHistoryTab(
      {required this.firestore, required this.auth, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: auth.currentUser != null
          ? firestore
              .collection('customer_messages')
              .where('user_id', isEqualTo: auth.currentUser!.uid)
              .orderBy('date', descending: true)
              .snapshots()
          : Stream.empty(),
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
                  'Submitted: ${ticket['date'] != null ? (ticket['date'] as Timestamp).toDate().toString().split('.')[0] : 'N/A'}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Description: ${ticket['description'] ?? 'N/A'}'),
                        const SizedBox(height: 8),
                        Text('Status: ${ticket['status'] ?? 'Pending'}'),
                        if (ticket['reply_by_admin'] == true) ...[
                          const SizedBox(height: 8),
                          Text(
                              'Admin Reply: ${ticket['admin_reply'] ?? 'N/A'}'),
                          Text('Replied On: ${ticket['replied_on'] ?? 'N/A'}'),
                        ],
                        if (ticket['attachment'] != null) ...[
                          const SizedBox(height: 8),
                          Text('Attachment: ${ticket['attachment']}'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
