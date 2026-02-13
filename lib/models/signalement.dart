import 'package:cloud_firestore/cloud_firestore.dart';

class Signalement {
  final String id;
  final String? userId; // Added for filtering
  String userName;
  final String type;
  final String description;
  String status;
  final DateTime date;
  final double? latitude;
  final double? longitude;
  final String? imageBase64;
  final String? imageUrl;

  Signalement({
    required this.id,
    this.userId,
    required this.userName,
    required this.type,
    required this.description,
    required this.status,
    required this.date,
    this.latitude,
    this.longitude,
    this.imageBase64,
    this.imageUrl,
  });

  factory Signalement.fromFirestore(String id, Map<String, dynamic> data) {
    return Signalement(
      id: id,
      userId: data['userId'],
      userName: (data['userName'] == null ||
          data['userName'].toString().isEmpty)
          ? 'Anonyme'
          : data['userName'],
      type: data['type'] ?? 'Autre',
      description: data['description'] ?? '',
      status: data['status'] ?? 'En attente',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageBase64: data['imageBase64'],
      imageUrl: data['imageUrl'],
    );
  }
}
