// lib/features/account/saved_posts_page.dart (修正後のコード)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/post_model.dart';
import '../../widgets/post_grid_card.dart';
import '../../widgets/common_app_bar.dart';

part 'saved_posts_page.g.dart'; // build_runnerで自動生成

// ▼▼▼ 【追加】 保存した投稿リストを取得するProviderを作成 ▼▼▼
@riverpod
Stream<List<Post>> savedPosts(SavedPostsRef ref, String userId) {
  final _currentUser = FirebaseAuth.instance.currentUser;
  if (_currentUser == null || _currentUser.uid != userId) {
    // 他の人の保存リストは見れないため、空のストリームを返す
    return Stream.value([]);
  }

  // 1. まず保存した投稿のIDリストを監視する
  final savedPostIdsStream = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('saved_posts')
      .snapshots();

  // 2. IDリストが変更されるたびに、そのIDに紐づく投稿データを取得し直す
  return savedPostIdsStream.asyncMap((snapshot) {
    final savedPostIds = snapshot.docs.map((doc) => doc.id).toList();
    if (savedPostIds.isEmpty) {
      return [];
    }
    // whereInクエリで、保存した投稿のデータだけをまとめて取得
    return FirebaseFirestore.instance
        .collection('posts')
        .where(FieldPath.documentId, whereIn: savedPostIds)
        .get()
        .then((postSnapshot) => postSnapshot.docs
            .map((doc) => Post.fromFirestore(doc))
            .toList());
  });
}


// ▼▼▼ 【変更点】 StatefulWidget を ConsumerWidget に変更 ▼▼▼
class SavedPostsPage extends ConsumerWidget {
  final String userId;
  const SavedPostsPage({super.key, required this.userId});

  // ▼▼▼ 【変更点】 Stateクラスは丸ごと不要になります ▼▼▼
  // _fetchRelatedDataなどの複雑なロジックはすべてProviderに移動しました。

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 作成したProviderを監視(watch)する
    final savedPostsAsyncValue = ref.watch(savedPostsProvider(userId));

    return Scaffold(
      appBar: CommonAppBar(title: const Text('保存した投稿')),
      body: savedPostsAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(child: Text('保存した投稿がありません。'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75, // PostGridCardの比率に合わせる
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              // ▼▼▼ 【重要】 エラーが出ていた引数を削除し、postだけを渡す ▼▼▼
              return PostGridCard(
                post: post,
              );
            },
          );
        },
      ),
    );
  }
}