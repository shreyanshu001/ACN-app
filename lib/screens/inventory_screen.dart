import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  File? _image;

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
        _locationController.text.isEmpty) return;

    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference storageRef =
        FirebaseStorage.instance.ref().child('inventory/$fileName');
    await storageRef.putFile(_image!);
    String imageUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance.collection('inventory').add({
      'agentId': FirebaseAuth.instance.currentUser!.uid,
      'price': double.parse(_priceController.text),
      'location': _locationController.text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
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
                keyboardType: TextInputType.number),
            TextField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Location')),
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
