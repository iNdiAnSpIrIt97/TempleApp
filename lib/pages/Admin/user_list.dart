import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:temple_app/pages/Admin/user_bookings.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _countryCode = "+91"; // Default country code (India)
  String _searchQuery = ""; // To store search query

  /// Validates Email Format
  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(email);
  }

  /// Registers the user in Firebase Authentication, Firestore `users`
  Future<void> _addUser() async {
    String email = _emailController.text.trim();
    String phone = "$_countryCode${_phoneController.text.trim()}";
    String name = _nameController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      _showToast("All fields are required!", Colors.red);
      return;
    }
    if (!_isValidEmail(email)) {
      _showToast("Invalid email format!", Colors.red);
      return;
    }
    if (_phoneController.text.length < 10) {
      _showToast("Phone number is too short!", Colors.red);
      return;
    }

    try {
      print("Creating user in Firebase Authentication...");
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: "mpkv123",
      );

      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        String uid = firebaseUser.uid;
        print("User created with UID: $uid");

        print("Sending email verification...");
        await firebaseUser.sendEmailVerification();
        print("Verification email sent.");

        print("Storing user in Firestore...");
        await _firestore.collection('users').doc(uid).set({
          'user_name': name,
          'email': email,
          'phone': phone,
          'role': 'user',
          'verified': false,
        });
        print("User stored in Firestore.");

        _showToast("User added! Verification email sent.", Colors.green);

        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error adding user: $e");
      _showToast("Error: ${e.toString()}", Colors.red);
    }
  }

  /// Displays a toast message
  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// Show Add User Dialog
  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            IntlPhoneField(
              controller: _phoneController,
              initialCountryCode: "IN",
              onCountryChanged: (country) {
                _countryCode = "+${country.dialCode}";
              },
              decoration: const InputDecoration(labelText: "Phone"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: _addUser,
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  /// Refreshes the user list and verification status
  Future<void> _refreshUserList() async {
    try {
      print("Refreshing user list...");
      var users = await _firestore
          .collection('users')
          .where('role', isNotEqualTo: 'admin')
          .get();

      print("Total users fetched: ${users.docs.length}");

      _showToast("User list refreshed!", Colors.green);
      setState(() {});
    } catch (e) {
      print("Error refreshing user list: $e");
      _showToast("Error refreshing user list: ${e.toString()}", Colors.red);
    }
  }

  /// Filter users based on search query
  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    if (_searchQuery.isEmpty) return users;

    String query = _searchQuery.toLowerCase();
    return users.where((user) {
      String name = (user['user_name'] ?? '').toLowerCase();
      String email = (user['email'] ?? '').toLowerCase();
      String phone = (user['phone'] ?? '').toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User List"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUserList,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddUserDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder(
        stream: _firestore
            .collection('users')
            .where('role', isNotEqualTo: 'admin')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          var filteredUsers = _filterUsers(snapshot.data!.docs);

          if (filteredUsers.isEmpty) {
            return const Center(child: Text("No matching users found"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              var user = filteredUsers[index];
              bool isVerified = user['verified'] ?? false;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      user['user_name'] != null && user['user_name'].isNotEmpty
                          ? user['user_name'][0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        user['user_name'] ?? 'No Name',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        isVerified ? Icons.verified : Icons.verified_outlined,
                        color: isVerified ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Email: ${user['email'] ?? 'No Email'}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        "Phone: ${user['phone'] ?? 'No Phone'}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navigate to UserBookingsPage with the selected user's UID
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserBookingsPage(
                          userId: user.id, // Pass the user's UID
                          userName: user['user_name'] ?? 'Unknown User',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
