import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:aws_s3_upload/aws_s3_upload.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  // Location variables
  double _locationRange = 50.0; // Default 50km
  String _currentLocation = 'Not set';
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  
  // S3 configuration with fallbacks
  String get _s3Bucket => dotenv.env['S3_BUCKET'] ?? 'your-s3-bucket-name';
  String get _s3Region => dotenv.env['S3_REGION'] ?? 'us-east-1';
  String get _s3AccessKey => dotenv.env['S3_ACCESS_KEY'] ?? '';
  String get _s3SecretKey => dotenv.env['S3_SECRET_KEY'] ?? '';
  
  // Check if S3 is properly configured
  bool get _isS3Configured => _s3AccessKey.isNotEmpty && _s3SecretKey.isNotEmpty;

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
  }
  
  Future<void> _pickAndUploadProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image == null) return;
      
      setState(() {
        _isUploading = true;
      });
      
      // Upload to S3
      final String fileName = '${Uuid().v4()}${path.extension(image.path)}';
      final String? imageUrl = await _uploadToS3(
        File(image.path), 
        'profile-images/$fileName'
      );
      
      if (imageUrl != null && currentUser != null) {
        // Update user profile
        await currentUser!.updatePhotoURL(imageUrl);
        
        // Update Firestore document
        await FirebaseFirestore.instance
            .collection('agents')
            .doc(currentUser!.uid)
            .update({
          'photoURL': imageUrl,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile image updated successfully'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile image: $e'))
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
  
  Future<String?> _uploadToS3(File file, String key) async {
    if (!_isS3Configured) {
      throw Exception('S3 configuration missing. Please check your .env file.');
    }
    
    try {
      final result = await AwsS3.uploadFile(
        accessKey: _s3AccessKey,
        secretKey: _s3SecretKey,
        file: file,
        bucket: _s3Bucket,
        region: _s3Region,
        key: key,
        metadata: {
          'userId': currentUser?.uid ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      return result;
    } catch (e) {
      print('Error uploading to S3: $e');
      throw e;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserLocationData();
  }
  
  Future<void> _loadUserLocationData() async {
    if (currentUser == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(currentUser!.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _locationRange = data['locationRange']?.toDouble() ?? 50.0;
            _currentLocation = data['locationAddress'] ?? 'Not set';
            _latitude = data['latitude']?.toDouble();
            _longitude = data['longitude']?.toDouble();
          });
        }
      }
    } catch (e) {
      print('Error loading location data: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '${place.locality}, ${place.administrativeArea}';
        
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _currentLocation = address;
        });
        
        // Save to Firestore
        await _saveLocationToFirestore(
          position.latitude, 
          position.longitude, 
          address, 
          _locationRange
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location updated successfully'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e'))
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }
  
  Future<void> _saveLocationToFirestore(
    double latitude, 
    double longitude, 
    String address, 
    double range
  ) async {
    if (currentUser == null) return;
    
    await FirebaseFirestore.instance
        .collection('agents')
        .doc(currentUser!.uid)
        .update({
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': address,
      'locationRange': range,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  Future<void> _updateLocationRange(double value) async {
    setState(() {
      _locationRange = value;
    });
    
    if (_latitude != null && _longitude != null) {
      await _saveLocationToFirestore(
        _latitude!, 
        _longitude!, 
        _currentLocation, 
        value
      );
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
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: currentUser?.photoURL != null
                          ? NetworkImage(currentUser!.photoURL!)
                          : null,
                      child: currentUser?.photoURL == null
                          ? Icon(Icons.person, size: 60)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploading
                            ? Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: Icon(Icons.camera_alt, color: Colors.white),
                                onPressed: _pickAndUploadProfileImage,
                              ),
                      ),
                    ),
                  ],
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
                
                // Verification status card
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
                
                // Member since card
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
                
                SizedBox(height: 10),
                
                // Location settings card
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Location Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _isLoadingLocation
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: Icon(Icons.my_location),
                                    onPressed: _getCurrentLocation,
                                    tooltip: 'Get current location',
                                  ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentLocation,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Operation Range: ${_locationRange.toInt()} km',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Slider(
                          value: _locationRange,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: '${_locationRange.toInt()} km',
                          onChanged: (value) {
                            setState(() {
                              _locationRange = value;
                            });
                          },
                          onChangeEnd: (value) {
                            _updateLocationRange(value);
                          },
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 km'),
                            Text('50 km'),
                            Text('100 km'),
                          ],
                        ),
                      ],
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