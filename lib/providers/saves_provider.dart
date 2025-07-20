import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'saves_provider.g.dart';

@Riverpod(keepAlive: true)
class SavedPostsNotifier extends _$SavedPostsNotifier {
  @override
  Future<Set<String>> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('saved_posts').get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> handleSave(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentState = state.value ?? {};
    final isSaved = currentState.contains(postId);
    final previousState = state;

    state = isSaved ? AsyncData(currentState..remove(postId)) : AsyncData(currentState..add(postId));

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('saved_posts').doc(postId);
    try {
      isSaved ? await ref.delete() : await ref.set({'savedAt': Timestamp.now()});
    } catch (e) {
      state = previousState;
    }
  }
}