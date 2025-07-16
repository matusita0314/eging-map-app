// lib/models/challenge_model.dart (新規作成)

import 'package:cloud_firestore/cloud_firestore.dart';

class Challenge {
  final String id;
  final String title;
  final String description;
  final String rank;
  final String type;
  final num threshold;

  Challenge.fromFirestore(DocumentSnapshot doc)
    : id = doc.id,
      title = (doc.data() as Map<String, dynamic>)['title'] ?? '',
      description = (doc.data() as Map<String, dynamic>)['description'] ?? '',
      rank = (doc.data() as Map<String, dynamic>)['rank'] ?? '',
      type = (doc.data() as Map<String, dynamic>)['type'] ?? '',
      threshold = (doc.data() as Map<String, dynamic>)['threshold'] ?? 0;
}