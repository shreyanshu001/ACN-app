import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResponsesList extends StatelessWidget {
  final String requirementId;

  const ResponsesList({required this.requirementId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requirements')
          .doc(requirementId)
          .collection('responses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final responses = snapshot.data!.docs;

        if (responses.isEmpty) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No responses yet'),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Responses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...responses.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['responderName'] ?? 'Anonymous',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          _buildStatusChip(data['status']),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(data['message']),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'accepted':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        break;
      case 'rejected':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        break;
      default:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}