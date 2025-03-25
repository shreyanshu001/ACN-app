import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aws_s3_upload/aws_s3_upload.dart'; // Import AWS S3 package

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  File? _image;

  // AWS S3 Configuration (replace with your credentials and bucket details)
  final String _awsAccessKey = 'YOUR_ACCESS_KEY_ID';
  final String _awsSecretKey = 'YOUR_SECRET_ACCESS_KEY';
  final String _bucketName = 'acn-images';
  final String _region = 'us-east-1'; // Replace with your bucket's region

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _uploadInventory() async {
    if (_image == null ||
        _priceController.text.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please fill all fields and select an image')));
      return;
    }

    try {
      // Generate a unique file name
      String fileName =
          '${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload image to S3
      String? imageUrl = await AwsS3.uploadFile(
        accessKey: _awsAccessKey,
        secretKey: _awsSecretKey,
        bucket: _bucketName,
        region: _region,
        file: _image!,
        key: fileName,
      );

      if (imageUrl == null) {
        throw Exception('Failed to upload image to S3');
      }

      // Save metadata to Firestore with S3 URL
      await FirebaseFirestore.instance.collection('inventory').add({
        'agentId': FirebaseAuth.instance.currentUser!.uid,
        'price': double.parse(_priceController.text),
        'location': _locationController.text,
        'imageUrl':
            'https://$_bucketName.s3.$_region.amazonaws.com/$fileName', // Construct S3 URL
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Share Inventory')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _priceController,
              decoration: InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(labelText: 'Location'),
            ),
            SizedBox(height: 20),
            _image == null
                ? Text('No image selected')
                : Image.file(_image!, height: 100),
            ElevatedButton(onPressed: _pickImage, child: Text('Pick Image')),
            ElevatedButton(
                onPressed: _uploadInventory, child: Text('Upload Inventory')),
          ],
        ),
      ),
    );
  }
}
