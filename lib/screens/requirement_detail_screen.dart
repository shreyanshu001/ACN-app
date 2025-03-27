import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/requirement_details_card.dart';
import '../widgets/response_section.dart';
import '../widgets/responses_list.dart';

class RequirementDetailScreen extends StatefulWidget {
  final String requirementId;
  
  RequirementDetailScreen({required this.requirementId});
  
  @override
  _RequirementDetailScreenState createState() => _RequirementDetailScreenState();
}

class _RequirementDetailScreenState extends State<RequirementDetailScreen> {
  final _responseController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Requirement Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requirements')
            .doc(widget.requirementId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Requirement details
                RequirementDetailsCard(data: data),
                
                SizedBox(height: 16),
                
                // Response section
                if (data['userId'] != FirebaseAuth.instance.currentUser!.uid)
                  ResponseSection(
                    requirementId: widget.requirementId,
                    responseController: _responseController,
                  ),
                
                SizedBox(height: 16),
                
                // Responses list
                ResponsesList(requirementId: widget.requirementId),
              ],
            ),
          );
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }
}