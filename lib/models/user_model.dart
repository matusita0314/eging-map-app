import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.displayName,
    this.photoUrl,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] ?? '名無しさん',
      photoUrl: data['photoUrl'],
    );
  }
}