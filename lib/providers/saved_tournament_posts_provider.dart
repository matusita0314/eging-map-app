import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_tournament_posts_provider.g.dart';

@Riverpod(keepAlive: true)
class SavedTournamentPostsNotifier extends _$SavedTournamentPostsNotifier {
  @override
  Future<Set<String>> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_tournament_posts')
        .get();
        
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> handleSave(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentState = state.value ?? {};
    final isSaved = currentState.contains(postId);
    
    // UIを即時反映
    state = AsyncData(isSaved 
      ? (currentState..remove(postId)) 
      : (currentState..add(postId))
    );

    final ref = FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('saved_tournament_posts').doc(postId);
    
    if (isSaved) {
      await ref.delete();
    } else {
      await ref.set({'savedAt': Timestamp.now()});
    }
  }
}