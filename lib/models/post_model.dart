import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String imageUrl;
  final String thumbnailUrl;
  final DateTime createdAt;
  final LatLng location;

  // --- ▼▼▼ 新しく追加・変更するフィールド ▼▼▼ ---
  final String weather; // 天気
  final double? airTemperature; // 気温
  final double? waterTemperature; // 水温
  final String? caption; // キャプション
  final double squidSize; // サイズ(cm)
  final double? weight; // 重さ(g) ※任意なので nullable
  final String egiName; // エギ・ルアー名
  final String? egiMaker; // エギ・ルアーメーカー ※任意
  final String? tackleRod; // ロッド ※任意
  final String? tackleReel; // リール ※任意
  final String? tackleLine; // ライン ※任意

  final int likeCount;
  final int commentCount;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.createdAt,
    required this.location,
    required this.weather,
    this.airTemperature,
    this.waterTemperature,
    this.caption,
    required this.squidSize,
    this.weight,
    required this.egiName,
    this.egiMaker,
    this.tackleRod,
    this.tackleReel,
    this.tackleLine,
    required this.likeCount,
    required this.commentCount,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint point = data['location'] ?? const GeoPoint(0, 0);
    Timestamp timestamp = data['createdAt'] ?? Timestamp.now();

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '名無しさん',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      createdAt: timestamp.toDate(),
      location: LatLng(point.latitude, point.longitude),

      // --- ▼▼▼ 新しいフィールドの読み込み ▼▼▼ ---
      weather: data['weather'] ?? '',
      airTemperature: (data['airTemperature'])?.toDouble(),
      waterTemperature: (data['waterTemperature'])?.toDouble(),
      caption: data['caption'],
      squidSize: (data['squidSize'] ?? 0.0).toDouble(),
      weight: (data['weight'])?.toDouble(), // nullableなので安全にキャスト
      egiName: data['egiName'] ?? (data['egiType'] ?? ''), // 以前のegiTypeも考慮
      egiMaker: data['egiMaker'],
      tackleRod: data['tackleRod'],
      tackleReel: data['tackleReel'],
      tackleLine: data['tackleLine'],

      // --- ▲▲▲ ここまで ▲▲▲ ---
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }
}
