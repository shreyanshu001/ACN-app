import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResponseSection extends StatelessWidget {
  final String requirementId;
  final TextEditingController responseController;

  const ResponseSection({
    required this.requirementId,
    required this.responseController,
  });

  Future<void> _submitResponse(BuildContext context) async {
    if (responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a response')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('requirements')
          .doc(requirementId)
          .collection('responses')
          .add({
        'responderId': FirebaseAuth.instance.currentUser!.uid,
        'responderName': FirebaseAuth.instance.currentUser!.displayName,
        'message': responseController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      responseController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Response submitted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit response: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Response',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: responseController,
              decoration: InputDecoration(
                hintText: 'Enter your response...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _submitResponse(context),
              child: Text('Submit Response'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}