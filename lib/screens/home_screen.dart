import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
  }

  Future<void> _checkEmailVerification() async {
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.reload();
      if (!currentUser!.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please verify your email to access all features'),
            action: SnackBarAction(
              label: 'Resend',
              onPressed: () async {
                await currentUser!.sendEmailVerification();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Verification email sent')),
                );
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Center(child: CircularProgressIndicator());
    }

    // Check if user is verified
    if (!currentUser!.emailVerified) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Verification Required'),
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Please verify your email to continue'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await currentUser!.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Verification email sent')),
                  );
                },
                child: Text('Resend Verification Email'),
              ),
            ],
          ),
        ),
      );
    }

    // Return your regular dashboard for verified users
    return Scaffold(
      appBar: AppBar(
        title: Text('ACN Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF0D4C3A),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: currentUser?.photoURL != null
                        ? NetworkImage(currentUser!.photoURL!)
                        : null,
                    child: currentUser?.photoURL == null
                        ? Icon(Icons.person, size: 30)
                        : null,
                  ),
                  SizedBox(height: 10),
                  Text(
                    currentUser?.displayName ?? 'Welcome',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    currentUser?.email ?? '',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.list),
              title: Text('Requirements'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/requirements');
              },
            ),
            ListTile(
              leading: Icon(Icons.add),
              title: Text('Add Requirement'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/requirement_form');
              },
            ),
            ListTile(
              leading: Icon(Icons.compare_arrows),
              title: Text('Matching Requirements'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/requirement_matching');
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacementNamed('/login');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign out failed: $e')),
                  );
                }
              },
            ),
          ],
        ),
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

          // Check if document exists and has data
          if (!snapshot.hasData || !snapshot.data!.exists) {
            // Create agent document if it doesn't exist
            FirebaseFirestore.instance
                .collection('agents')
                .doc(currentUser?.uid)
                .set({
              'email': currentUser?.email,
              'name': currentUser?.displayName,
              'verified': true,  // Set to true by default for now
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final bool isVerified = userData?['verified'] ?? true; // Default to true if field doesn't exist

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner - only show if explicitly set to false
                if (userData != null && userData['verified'] == false)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    color: Colors.orange[100],
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[800]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your account is pending verification. Some features may be limited.',
                            style: TextStyle(color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main content
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${currentUser?.displayName ?? 'Agent'}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 24),
                      
                      // Quick actions
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionCard(
                            context,
                            icon: Icons.add,
                            title: 'Add Requirement',
                            onTap: () {
                              Navigator.pushNamed(context, '/requirement_form');
                            },
                          ),
                          _buildActionCard(
                            context,
                            icon: Icons.list,
                            title: 'View Requirements',
                            onTap: () {
                              Navigator.pushNamed(context, '/requirements');
                            },
                          ),
                          _buildActionCard(
                            context,
                            icon: Icons.compare_arrows,
                            title: 'Find Matches',
                            onTap: () {
                              Navigator.pushNamed(context, '/requirement_matching');
                            },
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 32),
                      
                      // Recent requirements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Recent Requirements',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/requirements');
                            },
                            child: Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      
                      // Recent requirements list
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('requirements')
                            .where('userId', isEqualTo: currentUser?.uid)
                            .orderBy('createdAt', descending: true)
                            .limit(3)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data!.docs;
                          
                          if (docs.isEmpty) {
                            return Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(Icons.add_circle_outline, size: 48, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No requirements yet',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/requirement_form');
                                      },
                                      child: Text('Add Requirement'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF0D4C3A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              
                              return Card(
                                margin: EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(
                                    data['projectName'] ?? 'Unnamed Project',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${data['assetType'] ?? 'Property'} - ${data['configuration'] ?? ''}',
                                  ),
                                  trailing: Chip(
                                    label: Text(data['status']?.toUpperCase() ?? 'NEW'),
                                    backgroundColor: _getStatusColor(data['status']),
                                  ),
                                  onTap: () {
                                    // Navigate to requirement details
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                      
                      SizedBox(height: 32),
                      
                      // Matching requirements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Matching Requirements',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/requirement_matching');
                            },
                            child: Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      
                      // Placeholder for matching requirements
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.search, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Find matching requirements based on your location and preferences',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/requirement_matching');
                                },
                                child: Text('Find Matches'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF0D4C3A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildActionCard(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.27,
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Color(0xFF0D4C3A)),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green[100]!;
      case 'rejected':
        return Colors.red[100]!;
      case 'completed':
        return Colors.blue[100]!;
      case 'new':
        return Colors.blue[50]!;
      case 'pending':
      default:
        return Colors.orange[50]!;
    }
  }
}