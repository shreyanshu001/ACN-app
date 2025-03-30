import 'package:cloud_firestore/cloud_firestore.dart';

class Requirement {
  final String id;
  final String userId;
  final String projectName;
  final String details;
  final String assetType;
  final String? configuration;
  final double? area;
  final double? budgetFrom;
  final double? budgetTo;
  final bool asPerMarketPrice;
  final List<String> imageUrls;
  final String status;
  final String propertyStatus;
  final DateTime createdAt;

  Requirement({
    required this.id,
    required this.userId,
    required this.projectName,
    required this.details,
    required this.assetType,
    this.configuration,
    this.area,
    this.budgetFrom,
    this.budgetTo,
    required this.asPerMarketPrice,
    required this.imageUrls,
    required this.status,
    required this.propertyStatus,
    required this.createdAt,
  });

  factory Requirement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Requirement(
      id: doc.id,
      userId: data['userId'] ?? '',
      projectName: data['projectName'] ?? '',
      details: data['details'] ?? '',
      assetType: data['assetType'] ?? '',
      configuration: data['configuration'],
      area: data['area']?.toDouble(),
      budgetFrom: data['budgetFrom']?.toDouble(),
      budgetTo: data['budgetTo']?.toDouble(),
      asPerMarketPrice: data['asPerMarketPrice'] ?? false,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      status: data['status'] ?? 'new',
      propertyStatus: data['propertyStatus'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'projectName': projectName,
      'details': details,
      'assetType': assetType,
      'configuration': configuration,
      'area': area,
      'budgetFrom': budgetFrom,
      'budgetTo': budgetTo,
      'asPerMarketPrice': asPerMarketPrice,
      'imageUrls': imageUrls,
      'status': status,
      'propertyStatus': propertyStatus,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}