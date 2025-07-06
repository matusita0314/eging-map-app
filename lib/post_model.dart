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
  final String userName;
  final String userPhotoUrl;
  final int likeCount;
  final int commentCount;

  Post({
    required this.id,
    required this.userId,
    required this.squidSize,
    required this.egiType,
    required this.imageUrl,
    required this.location,
    required this.createdAt,
    required this.userName,
    required this.userPhotoUrl,
    required this.likeCount,
    required this.commentCount,
  });

  // FirestoreのデータからPostオブジェクトを生成する変換機能を修正
  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint point = data['location'] ?? const GeoPoint(0, 0);
    Timestamp timestamp = data['createdAt'] ?? Timestamp.now();

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '名無しさん',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      squidSize: (data['squidSize'] ?? 0).toDouble(),
      egiType: data['egiType'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      location: LatLng(point.latitude, point.longitude),
      createdAt: timestamp.toDate(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }
}
