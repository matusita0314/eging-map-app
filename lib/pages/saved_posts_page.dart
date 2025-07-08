import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../widgets/post_grid_card.dart';

class SavedPostsPage extends StatelessWidget {
  final String userId;

  const SavedPostsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('保存した投稿')),
      body: StreamBuilder<QuerySnapshot>(
        // ユーザーの保存済み投稿IDのリストを取得
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('saved_posts')
            .orderBy('savedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('保存した投稿はありません。'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              // 各IDを使って、投稿の詳細データを取得して表示
              final postId = snapshot.data!.docs[index].id;
              return _PostCardLoader(postId: postId);
            },
          );
        },
      ),
    );
  }
}

// 投稿IDから投稿データを非同期で読み込んで表示するウィジェット
class _PostCardLoader extends StatelessWidget {
  final String postId;
  const _PostCardLoader({required this.postId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
      builder: (context, postSnapshot) {
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          // 投稿が削除されている場合などは何も表示しない
          return const SizedBox.shrink();
        }
        final post = Post.fromFirestore(postSnapshot.data!);
        return PostGridCard(post: post);
      },
    );
  }
}
