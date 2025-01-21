import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<QueryDocumentSnapshot> users = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  // Check if the current user is admin@gmail.com
  bool isAdmin() {
    final user = _auth.currentUser;
    return user != null && user.email == 'admin@gmail.com';
  }

  Future<void> _checkAdminStatus() async {
    bool adminStatus = isAdmin();
    setState(() {
      _isAdmin = adminStatus;
    });
    if (_isAdmin) {
      _fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have admin privileges.')),
      );
    }
  }

  Future<void> _fetchUsers() async {
    QuerySnapshot snapshot = await _firestore.collection('users').get();
    setState(() {
      users = snapshot.docs;
    });
  }

  void _deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: !_isAdmin
          ? const Center(child: Text('You do not have admin privileges.'))
          : users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(user['preferredName'] ?? 'No Preferred Name'), // Display preferredName
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['email'] ?? 'No Email'), // Display email
                          Text(user['phoneNumber'] ?? 'No Phone Number'), // Display phoneNumber
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete User'),
                              content: const Text('Are you sure you want to delete this user?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _deleteUser(users[index].id);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}