// lib/features/account/saved_posts_page.dart (修正後のコード)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../widgets/post_feed_card.dart';
import '../../models/sort_by.dart';
import 'account.dart';
import '../../models/post_model.dart';
import '../../widgets/common_app_bar.dart';

part 'saved_posts_page.g.dart'; // build_runnerで自動生成

final savedPostsSortByProvider = StateProvider<SortBy>((ref) => SortBy.createdAt);

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
  
  final sortBy = ref.watch(savedPostsSortByProvider);

  return savedPostIdsStream.asyncMap((snapshot) async {
    final savedPostIds = snapshot.docs.map((doc) => doc.id).toList();
    if (savedPostIds.isEmpty) return [];

    final postSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where(FieldPath.documentId, whereIn: savedPostIds)
        .get();
        
    final posts = postSnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

    posts.sort((a, b) {
      switch (sortBy) {
        case SortBy.createdAt:
          return b.createdAt.compareTo(a.createdAt);
        case SortBy.likeCount:
          return b.likeCount.compareTo(a.likeCount);
        case SortBy.squidSize:
          return b.squidSize.compareTo(a.squidSize);
      }
    });
    return posts;
  });
}

class SavedPostsPage extends ConsumerWidget {
  final String userId;
  const SavedPostsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

          return Column(
            children: [
              SortHeader(sortByProvider: savedPostsSortByProvider),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    // ▼▼▼ PostFeedCardに変更 (ユーザー情報は表示する) ▼▼▼
                    return PostFeedCard(
                      post: posts[index],
                      showAuthorInfo: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}