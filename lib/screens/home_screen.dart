import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
              'verified': true, // Set to true by default for now
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final bool isVerified = userData?['verified'] ??
              true; // Default to true if field doesn't exist

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
                              Navigator.pushNamed(
                                  context, '/requirement_matching');
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 32),

                      // Messages Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Messages',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/messages');
                            },
                            child: Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Recent conversations

                      SizedBox(height: 32),

                      // Your Recent Requirements Section
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
                      SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('requirements')
                            .where('userId', isEqualTo: currentUser?.uid)
                            .orderBy('createdAt', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No requirements submitted yet'),
                              ),
                            );
                          }

                          return Column(
                            children: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                      data['projectName'] ?? 'Unnamed Project'),
                                  subtitle: Text(
                                      '${data['assetType'] ?? ''} - ${data['configuration'] ?? ''}'),
                                  trailing: _buildStatusChip(data['status']),
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/requirement_detail',
                                      arguments: doc.id,
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      SizedBox(height: 32),

                      // Received Responses Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Received Responses',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/messages');
                            },
                            child: Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('conversations')
                            .where('participants',
                                arrayContains: currentUser?.uid)
                            .orderBy('lastMessageTime', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No conversations yet'),
                              ),
                            );
                          }

                          return Column(
                            children: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final participants =
                                  List<String>.from(data['participants'] ?? []);
                              final String otherUserId =
                                  (data['participants'] as List).firstWhere(
                                      (id) => id != currentUser?.uid,
                                      orElse: () => '');
                              final String requirementId =
                                  data['requirementId'] ?? '';

                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('agents')
                                    .doc(otherUserId)
                                    .get(),
                                builder: (context, userSnapshot) {
                                  String userName = 'User';
                                  if (userSnapshot.hasData &&
                                      userSnapshot.data!.exists) {
                                    final userData = userSnapshot.data!.data()
                                        as Map<String, dynamic>;
                                    userName = userData['name'] ?? 'User';
                                  }

                                  return Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text(userName.isNotEmpty
                                            ? userName[0]
                                            : 'U'),
                                      ),
                                      title: Text(userName),
                                      subtitle: Text(data['lastMessage'] ??
                                          'Start a conversation'),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (data['unreadCount'] != null &&
                                              data['unreadCount']
                                                      [currentUser?.uid] !=
                                                  null &&
                                              data['unreadCount']
                                                      [currentUser?.uid] >
                                                  0)
                                            Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${data['unreadCount'][currentUser?.uid]}',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12),
                                              ),
                                            ),
                                          SizedBox(height: 4),
                                          Text(
                                            _formatTimestamp(
                                                data['lastMessageTime']),
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/messages',
                                          arguments: {
                                            'conversationId': doc.id,
                                            'otherUserId': otherUserId,
                                            'requirementId': requirementId,
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),

                      // StreamBuilder<QuerySnapshot>(
                      //   stream: FirebaseFirestore.instance
                      //       .collection('requirements')
                      //       .where('userId', isEqualTo: currentUser?.uid)
                      //       .snapshots(),
                      //   builder: (context, snapshot) {
                      //     if (snapshot.connectionState ==
                      //         ConnectionState.waiting) {
                      //       return Center(child: CircularProgressIndicator());
                      //     }

                      //     if (!snapshot.hasData ||
                      //         snapshot.data!.docs.isEmpty) {
                      //       return Card(
                      //         margin: EdgeInsets.only(bottom: 8),
                      //         child: Padding(
                      //           padding: EdgeInsets.all(16),
                      //           child: Text('No responses received yet'),
                      //         ),
                      //       );
                      //     }

                      //     List<Widget> responseWidgets = [];
                      //     bool hasAnyResponses = false;

                      //     for (var doc in snapshot.data!.docs) {
                      //       responseWidgets.add(
                      //         StreamBuilder<QuerySnapshot>(
                      //           stream: FirebaseFirestore.instance
                      //               .collection('requirements')
                      //               .doc(doc.id)
                      //               .collection('responses')
                      //               .orderBy('createdAt', descending: true)
                      //               .limit(3)
                      //               .snapshots(),
                      //           builder: (context, responseSnapshot) {
                      //             if (responseSnapshot.connectionState ==
                      //                 ConnectionState.waiting) {
                      //               return Center(
                      //                   child: CircularProgressIndicator());
                      //             }

                      //             if (!responseSnapshot.hasData ||
                      //                 responseSnapshot.data!.docs.isEmpty) {
                      //               return SizedBox();
                      //             }
                      //             setState(() {
                      //               hasAnyResponses = true;
                      //             });

                      //             return Column(
                      //               children: responseSnapshot.data!.docs
                      //                   .map((response) {
                      //                 final responseData = response.data()
                      //                     as Map<String, dynamic>;
                      //                 return Card(
                      //                   margin: EdgeInsets.only(bottom: 8),
                      //                   child: ListTile(
                      //                     title: Text(
                      //                         responseData['responderName'] ??
                      //                             'Anonymous'),
                      //                     subtitle: Text(
                      //                         responseData['message'] ?? ''),
                      //                     trailing: _buildStatusChip(
                      //                         responseData['status']),
                      //                     onTap: () {
                      //                       Navigator.pushNamed(
                      //                         context,
                      //                         '/requirement_detail',
                      //                         arguments: doc.id,
                      //                       );
                      //                     },
                      //                   ),
                      //                 );
                      //               }).toList(),
                      //             );
                      //           },
                      //         ),
                      //       );
                      //     }

                      //     if (!hasAnyResponses) {
                      //       return Card(
                      //         margin: EdgeInsets.only(bottom: 8),
                      //         child: Padding(
                      //           padding: EdgeInsets.all(16),
                      //           child: Text('No responses received yet'),
                      //         ),
                      //       );
                      //     }

                      //     return Column(children: responseWidgets);
                      //   },
                      // ),
                      SizedBox(height: 32),

                      // Sent Responses Section
                      Text(
                        'Your Sent Responses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collectionGroup('responses')
                            .where('responderId', isEqualTo: currentUser?.uid)
                            .orderBy('createdAt', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No responses sent yet'),
                              ),
                            );
                          }

                          return Column(
                            children: snapshot.data!.docs.map((doc) {
                              final responseData =
                                  doc.data() as Map<String, dynamic>;
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                      'Response to: ${responseData['projectName'] ?? 'Requirement'}'),
                                  subtitle: Text(responseData['message'] ?? ''),
                                  trailing:
                                      _buildStatusChip(responseData['status']),
                                  onTap: () {
                                    // Get the parent requirement ID
                                    final requirementId =
                                        doc.reference.parent.parent!.id;
                                    Navigator.pushNamed(
                                      context,
                                      '/requirement_detail',
                                      arguments: requirementId,
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
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

  Widget _buildStatusChip(String? status) {
    Color backgroundColor;
    Color textColor;

    switch (status?.toLowerCase()) {
      case 'accepted':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        break;
      case 'rejected':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        break;
      default:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        (status ?? 'PENDING').toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Remove the duplicate _getStatusColor at the bottom of the file and keep this version
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return Colors.blue[50]!;
      case 'approved':
        return Colors.green[50]!;
      case 'rejected':
        return Colors.red[50]!;
      case 'completed':
        return Colors.blue[100]!;
      default:
        return Colors.orange[50]!;
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return Colors.blue[700]!;
      case 'approved':
        return Colors.green[700]!;
      case 'rejected':
        return Colors.red[700]!;
      case 'completed':
        return Colors.blue[700]!;
      default:
        return Colors.orange[700]!;
    }
  }

  Widget _buildActionCard(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
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

  // Remove this duplicate method
  // Color _getStatusColor(String? status) {
  //   switch (status) {
  //     case 'approved':
  //       return Colors.green[100]!;
  //     case 'rejected':
  //       return Colors.red[100]!;
  //     case 'completed':
  //       return Colors.blue[100]!;
  //     case 'new':
  //       return Colors.blue[50]!;
  //     case 'pending':
  //     default:
  //       return Colors.orange[50]!;
  //   }
  // }
}

String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return '';

  DateTime dateTime;
  if (timestamp is Timestamp) {
    dateTime = timestamp.toDate();
  } else {
    return '';
  }

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}
