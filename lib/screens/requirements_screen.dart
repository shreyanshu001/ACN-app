import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequirementsScreen extends StatefulWidget {
  @override
  _RequirementsScreenState createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends State<RequirementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRegion;
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  
  final List<String> _regions = ['East', 'West', 'North', 'South', 'Central'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('requirements');
    
    // Apply search filter if provided
    if (_searchQuery.isNotEmpty) {
      query = query.where('projectName', isGreaterThanOrEqualTo: _searchQuery)
                  .where('projectName', isLessThanOrEqualTo: _searchQuery + '\uf8ff');
    }
    
    // Apply region filter if selected
    if (_selectedRegion != null) {
      query = query.where('region', isEqualTo: _selectedRegion);
    }
    
    // Order by creation date (newest first)
    return query.orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Requirements'),
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
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            ListTile(
              leading: Icon(Icons.list),
              title: Text('Requirements'),
              onTap: () {
                Navigator.pop(context);
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
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by project, location...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF0D4C3A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      // Search is already handled by the listener
                    },
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PopupMenuButton<String?>(
                    icon: Icon(Icons.filter_list),
                    onSelected: (String? value) {
                      setState(() {
                        _selectedRegion = value;
                      });
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String?>(
                          value: null,
                          child: Text('All Regions'),
                        ),
                        ..._regions.map((region) => PopupMenuItem<String>(
                              value: region,
                              child: Text(region),
                            )),
                      ];
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Requirements List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final documents = snapshot.data!.docs;
                
                // Calculate pagination
                final int totalItems = documents.length;
                final int totalPages = (totalItems / _itemsPerPage).ceil();
                final int startIndex = (_currentPage - 1) * _itemsPerPage;
                final int endIndex = startIndex + _itemsPerPage > totalItems 
                    ? totalItems 
                    : startIndex + _itemsPerPage;
                
                final List<DocumentSnapshot> paginatedDocs = 
                    documents.sublist(startIndex, endIndex);
                
                if (paginatedDocs.isEmpty) {
                  return Center(child: Text('No requirements found'));
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: paginatedDocs.length,
                        itemBuilder: (context, index) {
                          final data = paginatedDocs[index].data() as Map<String, dynamic>;
                          final String reqId = paginatedDocs[index].id;
                          
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (data.containsKey('reqId'))
                                    Text(
                                      data['reqId'] ?? 'RQB${reqId.substring(0, 3).toUpperCase()}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  SizedBox(height: 4),
                                  Text(
                                    data['projectName'] ?? 'Unnamed Project',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.currency_rupee, color: Colors.grey[700], size: 20),
                                      SizedBox(width: 4),
                                      Text(
                                        '₹${data['budgetFrom'] ?? 0}${data['budgetTo'] != null ? ' - ₹${data['budgetTo']}' : ''} ${data['asPerMarketPrice'] == true ? '(As per market)' : ''}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.home, color: Colors.grey[700], size: 20),
                                      SizedBox(width: 4),
                                      Text(
                                        '${data['assetType'] ?? 'Property'} - ${data['configuration'] ?? ''} ${data['area'] != null ? '/ ${data['area']} sqft' : ''}',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    data['details'] ?? 'east west or north',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Pagination
                    if (totalPages > 1)
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left),
                              onPressed: _currentPage > 1
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            for (int i = 1; i <= totalPages; i++)
                              if (i == 1 || i == totalPages || (i >= _currentPage - 1 && i <= _currentPage + 1))
                                Container(
                                  margin: EdgeInsets.symmetric(horizontal: 4),
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _currentPage = i),
                                    child: Text('$i'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _currentPage == i
                                          ? Color(0xFF0D4C3A)
                                          : Colors.white,
                                      foregroundColor: _currentPage == i
                                          ? Colors.white
                                          : Colors.black,
                                      minimumSize: Size(40, 40),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                )
                              else if (i == _currentPage - 2 || i == _currentPage + 2)
                                Container(
                                  alignment: Alignment.center,
                                  width: 40,
                                  child: Text('...'),
                                ),
                            IconButton(
                              icon: Icon(Icons.chevron_right),
                              onPressed: _currentPage < totalPages
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/requirement_form');
        },
        backgroundColor: Color(0xFF0D4C3A),
        child: Icon(Icons.add),
      ),
    );
  }
}