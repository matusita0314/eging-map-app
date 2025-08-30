import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String rank;
  final String? rankForCurrentMonth; 

  UserModel({
    required this.id,
    required this.displayName,
    this.photoUrl,
    required this.rank,
    this.rankForCurrentMonth, 
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] ?? '名無しさん',
      photoUrl: data['photoUrl'],
      rank: data['rank'] ?? 'beginner', 
      rankForCurrentMonth: data['rankForCurrentMonth'] ?? data['rank'] ?? 'beginner',
    );
  }
}