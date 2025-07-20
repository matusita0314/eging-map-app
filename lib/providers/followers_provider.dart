import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'followers_provider.g.dart'; // build_runnerで自動生成

@Riverpod(keepAlive: true)
class FollowersNotifier extends _$FollowersNotifier {
  @override
  Future<Set<String>> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    // 自分の'followers'サブコレクションを監視
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('followers')
        .get();
        
    return snapshot.docs.map((doc) => doc.id).toSet();
  }
  
  // このProviderはフォロワーリストを読み取るだけなので、
  // handleFollowのような状態を更新するメソッドは不要です。
}