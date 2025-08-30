import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ユーザーIDを引数に取り、獲得した称号のリストをストリームで提供する
final awardedTitlesProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('awardedTitles')
      .orderBy('awardedAt', descending: true)
      .snapshots();
});