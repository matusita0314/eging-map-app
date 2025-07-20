import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_provider.g.dart';

@riverpod
Stream<int> unreadChatCount(UnreadChatCountRef ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value(0); // ログインしていなければ未読数は0
  }

  // 自分が参加していて、かつ自分の未読数が1以上のチャットルームを監視
  final stream = FirebaseFirestore.instance
      .collection('chat_rooms')
      .where('userIds', arrayContains: user.uid)
      .snapshots();

  // 条件に合うチャットルームの「件数」を返す
  return stream.map((snapshot) {
    int totalCount = 0;
    // 取得した各チャットルームのドキュメントをループ
    for (final doc in snapshot.docs) {
      final data = doc.data(); // as Map<String, dynamic> は不要
      // unreadCountマップを取得
      final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
      if (unreadMap != null) {
        // 自分のIDに対応する未読数を合計に加算
        totalCount += unreadMap[user.uid] as int? ?? 0;
      }
    }
    return totalCount;
  });
}
