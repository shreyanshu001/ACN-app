import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequirementsScreen extends StatefulWidget {
  @override
  _RequirementsScreenState createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends State<RequirementsScreen> {
  final _budgetController = TextEditingController();
  final _locationController = TextEditingController();

  Future<void> _postRequirement() async {
    if (_budgetController.text.isEmpty || _locationController.text.isEmpty)
      return;

    await FirebaseFirestore.instance.collection('requirements').add({
      'agentId': FirebaseAuth.instance.currentUser!.uid,
      'budget': double.parse(_budgetController.text),
      'location': _locationController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Post Requirement')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: _budgetController,
                decoration: InputDecoration(labelText: 'Budget'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Location')),
            SizedBox(height: 20),
            ElevatedButton(
                onPressed: _postRequirement, child: Text('Post Requirement')),
          ],
        ),
      ),
    );
  }
}
