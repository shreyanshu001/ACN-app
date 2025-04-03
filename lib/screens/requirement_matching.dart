import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class RequirementMatchingScreen extends StatefulWidget {
  const RequirementMatchingScreen({super.key});

  @override
  _RequirementMatchingScreenState createState() =>
      _RequirementMatchingScreenState();
}

class _RequirementMatchingScreenState extends State<RequirementMatchingScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  List<DocumentSnapshot> _matchingRequirements = [];

  // User preferences
  double? _userLatitude;
  double? _userLongitude;
  double _userLocationRange = 50.0; // Default 50km
  String? _preferredAssetType;

  // Sorting options
  String _sortBy = 'distance'; // 'distance', 'recent', 'budget'
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load user preferences from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          setState(() {
            _userLatitude = userData['latitude']?.toDouble();
            _userLongitude = userData['longitude']?.toDouble();
            _userLocationRange = userData['locationRange']?.toDouble() ?? 50.0;
            _preferredAssetType = userData['preferredAssetType'];
          });
        }
      }

      // Load matching requirements
      await _loadMatchingRequirements();
    } catch (e) {
      print('Error loading user preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load preferences: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMatchingRequirements() async {
    if (currentUser == null) return;

    try {
      // Base query to get all requirements except user's own
      Query query = FirebaseFirestore.instance
          .collection('requirements')
          .where('userId', isNotEqualTo: currentUser!.uid);

      // Apply asset type filter if preferred
      if (_preferredAssetType != null && _preferredAssetType!.isNotEmpty) {
        query = query.where('assetType', isEqualTo: _preferredAssetType);
      }

      // Get the results
      final QuerySnapshot snapshot = await query.get();
      List<DocumentSnapshot> filteredDocs = snapshot.docs;

      // Filter by distance if location is available
      if (_userLatitude != null && _userLongitude != null) {
        filteredDocs = filteredDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final double? reqLat = data['latitude']?.toDouble();
          final double? reqLong = data['longitude']?.toDouble();

          if (reqLat == null || reqLong == null) return false;

          // Calculate distance
          final double distance = Geolocator.distanceBetween(
                _userLatitude!,
                _userLongitude!,
                reqLat,
                reqLong,
              ) /
              1000; // Convert to km

          // Store distance in the document data for sorting
          (doc.data() as Map<String, dynamic>)['distance'] = distance;

          // Check if within range
          return distance <= _userLocationRange;
        }).toList();
      }

      // Sort the results
      _sortRequirements(filteredDocs);

      setState(() {
        _matchingRequirements = filteredDocs;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load matching requirements: $e')));
    }
  }

  void _sortRequirements(List<DocumentSnapshot> docs) {
    switch (_sortBy) {
      case 'distance':
        docs.sort((a, b) {
          final distanceA =
              (a.data() as Map<String, dynamic>)['distance'] ?? double.infinity;
          final distanceB =
              (b.data() as Map<String, dynamic>)['distance'] ?? double.infinity;
          return _ascending
              ? distanceA.compareTo(distanceB)
              : distanceB.compareTo(distanceA);
        });
        break;
      case 'recent':
        docs.sort((a, b) {
          final timestampA =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final timestampB =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (timestampA == null) return _ascending ? 1 : -1;
          if (timestampB == null) return _ascending ? -1 : 1;
          return _ascending
              ? timestampB.compareTo(timestampA)
              : timestampA.compareTo(timestampB);
        });
        break;
      case 'budget':
        docs.sort((a, b) {
          final budgetFromA =
              (a.data() as Map<String, dynamic>)['budgetFrom']?.toDouble() ??
                  0.0;
          final budgetFromB =
              (b.data() as Map<String, dynamic>)['budgetFrom']?.toDouble() ??
                  0.0;
          return _ascending
              ? budgetFromA.compareTo(budgetFromB)
              : budgetFromB.compareTo(budgetFromA);
        });
        break;
    }
  }

  void _changeSortOption(String option) {
    if (_sortBy == option) {
      // Toggle ascending/descending if same option selected
      setState(() {
        _ascending = !_ascending;
      });
    } else {
      // Change sort option
      setState(() {
        _sortBy = option;
        _ascending = true;
      });
    }

    // Re-sort the list
    _sortRequirements(_matchingRequirements);
    setState(() {}); // Refresh UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Matching Requirements'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort),
            onSelected: _changeSortOption,
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'distance',
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: _sortBy == 'distance'
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                      SizedBox(width: 8),
                      Text('Distance'),
                      if (_sortBy == 'distance')
                        Icon(
                          _ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                        ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'recent',
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: _sortBy == 'recent'
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                      SizedBox(width: 8),
                      Text('Most Recent'),
                      if (_sortBy == 'recent')
                        Icon(
                          _ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                        ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'budget',
                  child: Row(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: _sortBy == 'budget'
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                      SizedBox(width: 8),
                      Text('Budget'),
                      if (_sortBy == 'budget')
                        Icon(
                          _ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Location range slider
                if (_userLatitude != null && _userLongitude != null)
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location Range: ${_userLocationRange.toInt()} km',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Slider(
                          value: _userLocationRange,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: '${_userLocationRange.toInt()} km',
                          onChanged: (value) {
                            setState(() {
                              _userLocationRange = value;
                            });
                          },
                          onChangeEnd: (value) async {
                            // Update user preference in Firestore
                            if (currentUser != null) {
                              await FirebaseFirestore.instance
                                  .collection('agents')
                                  .doc(currentUser!.uid)
                                  .update({
                                'locationRange': value,
                              });
                            }
                            // Reload matching requirements
                            await _loadMatchingRequirements();
                          },
                        ),
                      ],
                    ),
                  ),

                // Results count
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_matchingRequirements.length} matching requirements',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_preferredAssetType != null)
                        Chip(
                          label: Text(_preferredAssetType!),
                          deleteIcon: Icon(Icons.close, size: 16),
                          onDeleted: () async {
                            // Clear asset type filter
                            if (currentUser != null) {
                              await FirebaseFirestore.instance
                                  .collection('agents')
                                  .doc(currentUser!.uid)
                                  .update({
                                'preferredAssetType': FieldValue.delete(),
                              });

                              setState(() {
                                _preferredAssetType = null;
                              });

                              await _loadMatchingRequirements();
                            }
                          },
                        ),
                    ],
                  ),
                ),

                // Requirements list
                Expanded(
                  child: _matchingRequirements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No matching requirements found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your location range or preferences',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _matchingRequirements.length,
                          itemBuilder: (context, index) {
                            final data = _matchingRequirements[index].data()
                                as Map<String, dynamic>;
                            // final String reqId =
                            //     _matchingRequirements[index].id;
                            final double? distance =
                                data['distance']?.toDouble();

                            return Card(
                              margin: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          data['projectName'] ??
                                              'Unnamed Project',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (distance != null)
                                          Chip(
                                            label: Text(
                                                '${distance.toStringAsFixed(1)} km'),
                                            backgroundColor: distance <= 10
                                                ? Colors.green[100]
                                                : distance <= 30
                                                    ? Colors.amber[100]
                                                    : Colors.orange[100],
                                            avatar: Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: distance <= 10
                                                  ? Colors.green
                                                  : distance <= 30
                                                      ? Colors.amber
                                                      : Colors.orange,
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.currency_rupee,
                                            color: Colors.grey[700], size: 20),
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
                                        Icon(Icons.home,
                                            color: Colors.grey[700], size: 20),
                                        SizedBox(width: 4),
                                        Text(
                                          '${data['assetType'] ?? 'Property'} - ${data['configuration'] ?? ''} ${data['area'] != null ? '/ ${data['area']} sqft' : ''}',
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      data['details'] ?? 'No details provided',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: Icon(Icons.message),
                                          label: Text('Contact'),
                                          onPressed: () {
                                            // Navigate to chat or contact screen
                                            // You can implement this functionality
                                          },
                                        ),
                                        SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          icon: Icon(Icons.visibility),
                                          label: Text('View Details'),
                                          onPressed: () {
                                            // Navigate to requirement details screen
                                            // You can implement this functionality
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF0D4C3A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
