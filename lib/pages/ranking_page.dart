// lib/pages/ranking_page.dart (最終確定版)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import '../models/post_model.dart';
import '../widgets/post_grid_card.dart';
import '../widgets/common_app_bar.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  late final StreamSubscription _postsSubscription;

  List<Post> _posts = [];
  Set<String> _likedPostIds = {};
  Set<String> _savedPostIds = {};
  Set<String> _followingUserIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _fetchRelatedData();

    final stream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('squidSize', descending: true)
        .limit(50)
        .snapshots();
    
    _postsSubscription = stream.listen((snapshot) {
      final newPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      if(mounted) {
        setState(() {
          _posts = newPosts;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _postsSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchRelatedData() async {
    final futures = [
      FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('following').get(),
      FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('saved_posts').get(),
      FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('liked_posts').get(),
    ];

    final results = await Future.wait(futures);
    if (!mounted) return;

    final followingDocs = results[0] as QuerySnapshot;
    final savedDocs = results[1] as QuerySnapshot;
    final likedDocs = results[2] as QuerySnapshot;

    setState(() {
      _followingUserIds = followingDocs.docs.map((doc) => doc.id).toSet();
      _savedPostIds = savedDocs.docs.map((doc) => doc.id).toSet();
      _likedPostIds = likedDocs.docs.map((doc) => doc.id).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'ランキング'),
      body: _buildRankingList(),
    );
  }

  Widget _buildRankingList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(child: Text('ランキング対象の投稿がありません。'));
    }

    final firstPost = _posts.first;
    final otherPosts = _posts.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        // --- 1位のカード ---
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: PostGridCard(
            post: firstPost,
            rank: 1,
            isLikedByCurrentUser: _likedPostIds.contains(firstPost.id),
            isSavedByCurrentUser: _savedPostIds.contains(firstPost.id),
            isFollowingAuthor: _followingUserIds.contains(firstPost.userId),
          ),
        ),

        // --- 2位以降のグリッド ---
        if (otherPosts.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: otherPosts.length,
            itemBuilder: (context, index) {
              final post = otherPosts[index];
              final rank = index + 2;
              return PostGridCard(
                post: post,
                rank: rank,
                isLikedByCurrentUser: _likedPostIds.contains(post.id),
                isSavedByCurrentUser: _savedPostIds.contains(post.id),
                isFollowingAuthor: _followingUserIds.contains(post.userId),
              );
            },
          ),
      ],
    );
  }
}