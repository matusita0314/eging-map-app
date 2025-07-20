import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'following_provider.g.dart';

@Riverpod(keepAlive: true)
class FollowingNotifier extends _$FollowingNotifier {
  @override
  Future<Set<String>> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('following').get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> handleFollow(String targetUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == targetUserId) return;

    final currentState = state.value ?? {};
    final isFollowing = currentState.contains(targetUserId);
    final previousState = state;
    
    state = isFollowing ? AsyncData(currentState..remove(targetUserId)) : AsyncData(currentState..add(targetUserId));
    
    final batch = FirebaseFirestore.instance.batch();
    final myFollowingRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('following').doc(targetUserId);
    final theirFollowersRef = FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('followers').doc(user.uid);

    try {
      if (isFollowing) {
        batch.delete(myFollowingRef);
        batch.delete(theirFollowersRef);
      } else {
        batch.set(myFollowingRef, {'followedAt': Timestamp.now()});
        batch.set(theirFollowersRef, {'followerAt': Timestamp.now()});
      }
      await batch.commit();
    } catch(e) {
      state = previousState;
    }
  }
}