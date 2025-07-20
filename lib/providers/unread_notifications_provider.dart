import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unread_notifications_provider.g.dart'; // build_runnerで自動生成

@riverpod
Stream<int> unreadNotificationsCount(UnreadNotificationsCountRef ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value(0); // ログインしていなければ未読数は0
  }

  // 自分のnotificationsサブコレクションで、isReadがfalseのドキュメントを監視
  final stream = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
      .snapshots();

  // 条件に合う通知の「件数」を返す
  return stream.map((snapshot) => snapshot.docs.length);
}
