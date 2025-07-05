import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String userId;
  final double squidSize;
  final String egiType;
  final String imageUrl;
  final LatLng location;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,
    required this.squidSize,
    required this.egiType,
    required this.imageUrl,
    required this.location,
    required this.createdAt,
  });

  // FirestoreのデータからPostオブジェクトを生成する変換機能
  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint point = data['location'] ?? const GeoPoint(0, 0);
    Timestamp timestamp = data['createdAt'] ?? Timestamp.now();

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      squidSize: (data['squidSize'] ?? 0).toDouble(),
      egiType: data['egiType'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      location: LatLng(point.latitude, point.longitude),
      createdAt: timestamp.toDate(),
    );
  }
}