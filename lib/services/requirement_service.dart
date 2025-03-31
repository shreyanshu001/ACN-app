import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/requirement.dart';

class RequirementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all requirements
  Stream<List<Requirement>> getRequirements() {
    return _firestore
        .collection('requirements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Requirement.fromFirestore(doc)).toList())
        .shareReplay(maxSize: 1); // Add caching with rxdart
  }

  // Get user requirements
  Stream<List<Requirement>> getUserRequirements(String userId) {
    return _firestore
        .collection('requirements')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Requirement.fromFirestore(doc))
            .toList());
  }

  // Get requirement by id
  Stream<Requirement?> getRequirementById(String id) {
    return _firestore
        .collection('requirements')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Requirement.fromFirestore(doc) : null);
  }

  // Add requirement
  Future<String> addRequirement(Requirement requirement) async {
    final docRef =
        await _firestore.collection('requirements').add(requirement.toMap());
    return docRef.id;
  }

  // Update requirement
  Future<void> updateRequirement(String id, Map<String, dynamic> data) async {
    await _firestore.collection('requirements').doc(id).update(data);
  }

  // Delete requirement
  Future<void> deleteRequirement(String id) async {
    await _firestore.collection('requirements').doc(id).delete();
  }

  // Update requirement status
  Future<void> updateRequirementStatus(String id, String status) async {
    await _firestore
        .collection('requirements')
        .doc(id)
        .update({'status': status});
  }
}
