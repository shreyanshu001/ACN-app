import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Users'),
            Tab(text: 'Requirements'),
          ],
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildRequirementsTab(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('agents').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No users found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final userData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final userId = snapshot.data!.docs[index].id;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: userData['photoURL'] != null
                    ? NetworkImage(userData['photoURL'])
                    : null,
                child: userData['photoURL'] == null ? Icon(Icons.person) : null,
              ),
              title: Text(userData['name'] ?? 'Unknown'),
              subtitle: Text(userData['email'] ?? ''),
              trailing: Switch(
                value: userData['verified'] ?? false,
                onChanged: (value) {
                  FirebaseFirestore.instance
                      .collection('agents')
                      .doc(userId)
                      .update({'verified': value});
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequirementsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('requirements').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No requirements found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final requirementData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final requirementId = snapshot.data!.docs[index].id;

            return Card(
              margin: EdgeInsets.all(8),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requirementData['projectName'] ?? 'Unnamed Project',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(requirementData['details'] ?? 'No details'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(requirementData['status'] ?? 'Unknown'),
                          backgroundColor:
                              _getStatusColor(requirementData['status']),
                        ),
                        SizedBox(width: 8),
                        if (requirementData['assetType'] != null)
                          Chip(label: Text(requirementData['assetType'])),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.check_circle,
                          label: 'Approve',
                          color: Colors.green,
                          onPressed: () => _updateRequirementStatus(
                              requirementId, 'approved'),
                        ),
                        _buildActionButton(
                          icon: Icons.cancel,
                          label: 'Decline',
                          color: Colors.red,
                          onPressed: () => _updateRequirementStatus(
                              requirementId, 'declined'),
                        ),
                        _buildActionButton(
                          icon: Icons.edit,
                          label: 'Edit',
                          color: Colors.blue,
                          onPressed: () =>
                              _editRequirement(requirementId, requirementData),
                        ),
                        _buildActionButton(
                          icon: Icons.delete,
                          label: 'Delete',
                          color: Colors.grey,
                          onPressed: () => _deleteRequirement(requirementId),
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
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Icon(icon, color: color),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'new':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateRequirementStatus(
      String requirementId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('requirements')
          .doc(requirementId)
          .update({'status': status});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requirement status updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _deleteRequirement(String requirementId) async {
    try {
      // Show confirmation dialog
      bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Confirm Deletion'),
              content:
                  Text('Are you sure you want to delete this requirement?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Delete'),
                ),
              ],
            ),
          ) ??
          false;

      if (confirm) {
        await FirebaseFirestore.instance
            .collection('requirements')
            .doc(requirementId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Requirement deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete requirement: $e')),
      );
    }
  }

  void _editRequirement(
      String requirementId, Map<String, dynamic> requirementData) {
    // Navigate to edit screen with requirement data
    Navigator.pushNamed(
      context,
      '/edit_requirement',
      arguments: {
        'requirementId': requirementId,
        'requirementData': requirementData,
      },
    );
  }
}
