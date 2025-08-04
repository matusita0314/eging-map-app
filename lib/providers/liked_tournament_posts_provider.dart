import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'liked_tournament_posts_provider.g.dart';

@Riverpod(keepAlive: true)
class LikedTournamentPostsNotifier extends _$LikedTournamentPostsNotifier {
  @override
  Future<Set<String>> build() async {
    // このProviderは状態を保持するよりも、操作の窓口として利用します
    return {};
  }

  // いいね操作
  Future<void> handleLike(String tournamentId, String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final likeRef = FirebaseFirestore.instance
      .collection('tournaments').doc(tournamentId)
      .collection('posts').doc(postId)
      .collection('likes').doc(user.uid);

    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await likeRef.delete(); // いいね済みなら削除
    } else {
      await likeRef.set({'likedAt': Timestamp.now()}); // 未いいねなら追加
    }
  }
}