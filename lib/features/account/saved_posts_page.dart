import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../widgets/post_feed_card.dart';
import '../../models/sort_by.dart';
import 'account.dart'; // Accountクラスの正しいパスに修正してください
import '../../models/post_model.dart';

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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF13547a),
              Color(0xFF80d0c7),
            ],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // フローティング風AppBar
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            '保存した投稿',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF13547a),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // アイコンボタンのサイズ分のスペース
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ];
            },
            body: savedPostsAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('エラー: $err')),
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(child: Text('保存した投稿がありません。'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return PostFeedCard(
                      post: posts[index],
                      showAuthorInfo: true,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}