import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/post_model.dart';
part 'post_provider.g.dart';

// 投稿1件のデータをリアルタイムで監視するProvider
@riverpod
Stream<Post> postStream(PostStreamRef ref, String postId) {
  final docStream = FirebaseFirestore.instance.collection('posts').doc(postId).snapshots();
  return docStream.map((doc) => Post.fromFirestore(doc));
}