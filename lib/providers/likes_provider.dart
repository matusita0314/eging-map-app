import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';


part 'likes_provider.g.dart'; // 自動生成されるファイル

@Riverpod(keepAlive: true) // ユーザーがログアウトするまで状態を保持
class LikedPostsNotifier extends _$LikedPostsNotifier {
  
  // Providerの初期状態を構築するメソッド
  @override
  Future<Set<String>> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {}; // 未ログイン時は空のセット

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('liked_posts')
        .get();
        
    final likedIds = snapshot.docs.map((doc) => doc.id).toSet();
    return likedIds;
  }

  // いいね操作を行うメソッド
  Future<void> handleLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentState = state.value ?? {};
    final isLiked = currentState.contains(postId);
    
    // UIを即時反映させるための「楽観的更新」
    if (isLiked) {
      state = AsyncData(currentState..remove(postId));
    } else {
      state = AsyncData(currentState..add(postId));
    }
    
    // Firestoreへの書き込み処理
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likedPostRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('liked_posts')
        .doc(postId);

    final batch = FirebaseFirestore.instance.batch();

    if (isLiked) { // いいねを取り消す
      batch.delete(likedPostRef);
      batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
    } else { // いいねする
      batch.set(likedPostRef, {'likedAt': Timestamp.now()});
      batch.update(postRef, {'likeCount': FieldValue.increment(1)});
    }
    
    try {
      await batch.commit();
    } catch (e) {
      // エラーが起きたらUIの状態を元に戻す
      state = AsyncData(currentState); 
    }
  }
}