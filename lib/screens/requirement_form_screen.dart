import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aws_s3_upload/aws_s3_upload.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class RequirementFormScreen extends StatefulWidget {
  @override
  _RequirementFormScreenState createState() => _RequirementFormScreenState();
}

class _RequirementFormScreenState extends State<RequirementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _areaController = TextEditingController();
  final _budgetFromController = TextEditingController();
  final _budgetToController = TextEditingController();
  
  String? _selectedAssetType;
  String? _selectedConfiguration;
  bool _asPerMarketPrice = false;
  
  final List<String> _assetTypes = ['Residential', 'Commercial', 'Land', 'Industrial'];
  final List<String> _configurations = ['1BHK', '2BHK', '3BHK', '4BHK', 'Villa', 'Plot', 'Office Space'];
  
  // Add these new variables for image upload
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isUploading = false;
  
  // AWS S3 configuration using environment variables
  final String _s3Bucket = dotenv.env['AWS_S3_BUCKET'] ?? '';
  final String _s3Region = dotenv.env['AWS_S3_REGION'] ?? '';
  final String _s3AccessKey = dotenv.env['AWS_ACCESS_KEY'] ?? '';
  final String _s3SecretKey = dotenv.env['AWS_SECRET_KEY'] ?? '';
  
  // Method to pick images
  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    
    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xFile) => File(xFile.path)).toList());
      });
    }
  }
  
  // Method to take a photo
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      setState(() {
        _selectedImages.add(File(photo.path));
      });
    }
  }
  
  // Method to remove an image
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }
  
  // Method to upload images to S3
  Future<List<String>> _uploadImagesToS3() async {
    List<String> imageUrls = [];
    
    if (_selectedImages.isEmpty) return imageUrls;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      for (File imageFile in _selectedImages) {
        final String fileName = '${Uuid().v4()}${path.extension(imageFile.path)}';
        
        final result = await AwsS3.uploadFile(
          accessKey: _s3AccessKey,
          secretKey: _s3SecretKey,
          file: imageFile,
          bucket: _s3Bucket,
          region: _s3Region,
          key: 'property-images/$fileName',
          metadata: {
            'userId': FirebaseAuth.instance.currentUser!.uid,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
         
        // Fix: Check if result is not null before checking if it's not empty
        if (result != null && result.isNotEmpty) {
          imageUrls.add(result);
        }
      }
    } catch (e) {
      print('Error uploading to S3: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload images: $e'))
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
    
    return imageUrls;
  }

  Future<void> _submitRequirement() async {
    if (_formKey.currentState!.validate()) {
      try {
        // First upload images to S3
        List<String> imageUrls = await _uploadImagesToS3();
        
        // Then save the requirement with image URLs
        await FirebaseFirestore.instance.collection('requirements').add({
          'userId': FirebaseAuth.instance.currentUser!.uid,
          'projectName': _projectNameController.text,
          'details': _detailsController.text,
          'assetType': _selectedAssetType,
          'configuration': _selectedConfiguration,
          'area': _areaController.text.isNotEmpty ? double.parse(_areaController.text) : null,
          'budgetFrom': _budgetFromController.text.isNotEmpty ? double.parse(_budgetFromController.text) : null,
          'budgetTo': _budgetToController.text.isNotEmpty ? double.parse(_budgetToController.text) : null,
          'asPerMarketPrice': _asPerMarketPrice,
          'imageUrls': imageUrls,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Requirement submitted successfully'))
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit requirement: $e'))
        );
      }
    }
  }

  void _clearForm() {
    _projectNameController.clear();
    _detailsController.clear();
    _areaController.clear();
    _budgetFromController.clear();
    _budgetToController.clear();
    setState(() {
      _selectedAssetType = null;
      _selectedConfiguration = null;
      _asPerMarketPrice = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Requirement Form'),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project Name / Location
                Text(
                  'Project Name / Location *',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _projectNameController,
                  decoration: InputDecoration(
                    hintText: 'Type here',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter project name/location';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Requirement Details
                Text(
                  'Requirement Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _detailsController,
                  decoration: InputDecoration(
                    hintText: 'Enter the details',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: 16),
                
                // Asset Type and Configuration Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Asset Type
                      Text(
                        'Asset Type *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedAssetType,
                        decoration: InputDecoration(
                          hintText: 'Select Asset Type',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _assetTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedAssetType = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an asset type';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      
                      // Configuration and Area
                      Row(
                        children: [
                          // Configuration
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Configuration *',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedConfiguration,
                                  decoration: InputDecoration(
                                    hintText: 'Select Configuration',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items: _configurations.map((String config) {
                                    return DropdownMenuItem<String>(
                                      value: config,
                                      child: Text(config),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedConfiguration = newValue;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a configuration';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          
                          // Area
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Area (Sqft)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                TextFormField(
                                  controller: _areaController,
                                  decoration: InputDecoration(
                                    hintText: '0000',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                
                // Budget Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget (Cr) *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          // From
                          Expanded(
                            child: TextFormField(
                              controller: _budgetFromController,
                              decoration: InputDecoration(
                                hintText: 'From',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_asPerMarketPrice && (value == null || value.isEmpty)) {
                                  return 'Please enter budget';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('To'),
                          SizedBox(width: 16),
                          // To
                          Expanded(
                            child: TextFormField(
                              controller: _budgetToController,
                              decoration: InputDecoration(
                                hintText: 'To',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _asPerMarketPrice,
                            onChanged: (bool? value) {
                              setState(() {
                                _asPerMarketPrice = value ?? false;
                              });
                            },
                          ),
                          Text('As per Market Price'),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                
                // Add this new section for image upload
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property Images',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: Icon(Icons.photo_library),
                            label: Text('Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: Icon(Icons.camera_alt),
                            label: Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (_selectedImages.isNotEmpty)
                        Container(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(right: 8),
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _selectedImages[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      if (_isUploading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: _clearForm,
                      child: Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _submitRequirement,
                      child: _isUploading 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Uploading...'),
                              ],
                            )
                          : Text('Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0D4C3A),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _projectNameController.dispose();
    _detailsController.dispose();
    _areaController.dispose();
    _budgetFromController.dispose();
    _budgetToController.dispose();
    super.dispose();
  }
}