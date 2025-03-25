import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agents')
            .doc(currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : null,
                  child: currentUser?.photoURL == null
                      ? Icon(Icons.person, size: 50)
                      : null,
                ),
                SizedBox(height: 20),
                Text(
                  currentUser?.displayName ?? 'No Name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 10),
                Text(
                  currentUser?.email ?? 'No Email',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.verified),
                    title: Text('Verification Status'),
                    trailing: Text(
                      userData?['verified'] == true ? 'Verified' : 'Pending',
                      style: TextStyle(
                        color: userData?['verified'] == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.calendar_today),
                    title: Text('Member Since'),
                    subtitle: Text(
                      userData?['createdAt'] != null
                          ? userData!['createdAt'].toDate().toString()
                          : 'Not available',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}