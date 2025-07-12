// lib/pages/my_page.dart (改修後)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../widgets/post_grid_card.dart';
import 'edit_profile_page.dart';
import 'follower_list_page.dart';
import 'saved_posts_page.dart';
import '../widgets/common_app_bar.dart';

class SavedPostsPage extends StatefulWidget {
  final String userId;
  const SavedPostsPage({super.key, required this.userId});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // ▼▼▼ 関連データを保持するState変数を追加 ▼▼▼
  Set<String> _likedPostIds = {};
  Set<String> _savedPostIds = {};
  Set<String> _followingUserIds = {};

  // ▼▼▼ 関連データの読み込み状態を管理 ▼▼▼
  bool _isRelatedDataLoading = true;
  // 一度読み込んだ投稿データを保持して再取得を防ぐ
  List<Post> _posts = [];

  // ▼▼▼ 関連データを一括取得するメソッドを追加 ▼▼▼
  Future<void> _fetchRelatedData(List<Post> posts) async {
    setState(() {
      _isRelatedDataLoading = true;
    });

    final followingFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('following')
        .get();
    final savedPostsFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('saved_posts')
        .get();
    final likedChecksFuture = Future.wait(
      posts.map((post) {
        return FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .collection('likes')
            .doc(_currentUser.uid)
            .get();
      }),
    );

    final results = await Future.wait([
      followingFuture,
      savedPostsFuture,
      likedChecksFuture,
    ]);

    final followingDocs = results[0] as QuerySnapshot;
    final savedDocs = results[1] as QuerySnapshot;
    final likedDocs = results[2] as List<DocumentSnapshot>;

    final newFollowingUserIds = followingDocs.docs.map((doc) => doc.id).toSet();
    final newSavedPostIds = savedDocs.docs.map((doc) => doc.id).toSet();
    final newLikedPostIds = <String>{};
    for (int i = 0; i < likedDocs.length; i++) {
      if (likedDocs[i].exists) {
        newLikedPostIds.add(posts[i].id);
      }
    }

    if (mounted) {
      setState(() {
        _followingUserIds = newFollowingUserIds;
        _savedPostIds = newSavedPostIds;
        _likedPostIds = newLikedPostIds;
        _isRelatedDataLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: '保存した投稿'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('saved_posts')
            .snapshots(),
        builder: (context, savedPostsSnapshot) {
          if (savedPostsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!savedPostsSnapshot.hasData ||
              savedPostsSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('保存した投稿がありません。'));
          }

          final savedPostIds = savedPostsSnapshot.data!.docs
              .map((doc) => doc.id)
              .toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where(FieldPath.documentId, whereIn: savedPostIds)
                .snapshots(),
            builder: (context, postsSnapshot) {
              if (postsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('保存した投稿が見つかりません。'));
              }

              final posts = postsSnapshot.data!.docs
                  .map((doc) => Post.fromFirestore(doc))
                  .toList();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_isRelatedDataLoading) _fetchRelatedData(posts);
              });

              if (_isRelatedDataLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return PostGridCard(
                    post: post,
                    isLikedByCurrentUser: _likedPostIds.contains(post.id),
                    isSavedByCurrentUser: _savedPostIds.contains(post.id),
                    isFollowingAuthor: _followingUserIds.contains(post.userId),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- ここから下の他のメソッド (_buildProfileHeader, _buildStatsSectionなど) は変更ありません ---
  Widget _buildBadgeSection() {
    /* ... */
    return const SizedBox.shrink();
  }

  Widget _buildProfileHeader(DocumentSnapshot userDoc) {
    /* ... */
    return const SizedBox.shrink();
  }

  Widget _buildStatsSection(int postCount, int totalLikes) {
    /* ... */
    return const SizedBox.shrink();
  }

  Widget _buildTappableStatItem(
    String label,
    String collectionPath,
    Widget destinationPage,
  ) {
    /* ... */
    return const SizedBox.shrink();
  }

  Widget _buildStatItem(String label, String value) {
    /* ... */
    return const SizedBox.shrink();
  }

  Widget _buildChartSection(Map<String, int> data) {
    /* ... */
    return const SizedBox.shrink();
  }

  Map<String, int> _createMonthlyChartData(List<QueryDocumentSnapshot> docs) {
    /* ... */
    return {};
  }
}
