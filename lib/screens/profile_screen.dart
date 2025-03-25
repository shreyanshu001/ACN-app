import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:aws_s3_upload/aws_s3_upload.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  // S3 configuration
  String? get _s3Bucket => dotenv.env['S3_BUCKET'];
  String? get _s3Region => dotenv.env['S3_REGION'];
  String? get _s3AccessKey => dotenv.env['S3_ACCESS_KEY'];
  String? get _s3SecretKey => dotenv.env['S3_SECRET_KEY'];

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
    if (_s3Bucket == null || _s3Region == null || 
        _s3AccessKey == null || _s3SecretKey == null) {
      throw Exception('S3 configuration missing');
    }
    
    try {
      final result = await AwsS3.uploadFile(
        accessKey: _s3AccessKey!,
        secretKey: _s3SecretKey!,
        file: file,
        bucket: _s3Bucket!,
        region: _s3Region!,
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