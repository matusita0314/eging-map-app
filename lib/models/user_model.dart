import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String rank;
  final String? rankForCurrentMonth;

  // ▼▼▼ チャレンジ用の集計フィールドを追加 ▼▼▼
  final int totalCatches;
  final num maxSize;
  final num maxWeight;
  final int followerCount;
  final int followingCount;
  final int totalLikesReceived;
  final bool hasCreatedGroup;
  final bool hasJoinedTournament;

  UserModel({
    required this.id,
    required this.displayName,
    this.photoUrl,
    required this.rank,
    this.rankForCurrentMonth,
    this.totalCatches = 0,
    this.maxSize = 0,
    this.maxWeight = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.totalLikesReceived = 0,
    this.hasCreatedGroup = false,
    this.hasJoinedTournament = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] ?? '名無しさん',
      photoUrl: data['photoUrl'],
      rank: data['rank'] ?? 'beginner',
      rankForCurrentMonth: data['rankForCurrentMonth'] ?? data['rank'] ?? 'beginner',
      totalCatches: data['totalCatches'] ?? 0,
      maxSize: data['maxSize'] ?? 0,
      maxWeight: data['maxWeight'] ?? 0,
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      totalLikesReceived: data['totalLikesReceived'] ?? 0,
      hasCreatedGroup: data['hasCreatedGroup'] ?? false,
      hasJoinedTournament: data['hasJoinedTournament'] ?? false,
    );
  }
}