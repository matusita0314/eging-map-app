// lib/pages/timeline_page.dart (最終確定版)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import '../models/post_model.dart';
import '../widgets/post_grid_card.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _CustomTabSwitcher(
            selectedIndex: _selectedTabIndex,
            onTabSelected: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: const [
          _TodayTimeline(),
          Center(child: Text('現在、お知らせはありません。')),
        ],
      ),
    );
  }
}

class _CustomTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  const _CustomTabSwitcher({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    // ... このウィジェットの中身は変更ありません ...
    return Container(
      height: 40,
      width: 220,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              width: 110,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildTabItem(context, 'Today', 0),
              _buildTabItem(context, 'お知らせ', 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String title, int index) {
    // ... このウィジェットの中身は変更ありません ...
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayTimeline extends StatefulWidget {
  const _TodayTimeline();

  @override
  State<_TodayTimeline> createState() => _TodayTimelineState();
}

class _TodayTimelineState extends State<_TodayTimeline> {
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

    // ▼▼▼ まず関連データを一度だけ取得する ▼▼▼
    _fetchRelatedData();

    // ▼▼▼ 投稿のリアルタイム監視を開始 ▼▼▼
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final stream = FirebaseFirestore.instance
        .collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: startOfToday)
        .orderBy('createdAt', descending: true)
        .snapshots();

    _postsSubscription = stream.listen((snapshot) {
      print("◉ 投稿データを受信 (件数: ${snapshot.docs.length})");
      final newPosts = snapshot.docs
          .map((doc) => Post.fromFirestore(doc))
          .toList();
      if (mounted) {
        setState(() {
          _posts = newPosts;
          _isLoading = false; // 投稿データが来たらローディング解除
        });
      }
    });
  }

  @override
  void dispose() {
    _postsSubscription.cancel();
    super.dispose();
  }

  // ▼▼▼ 「いいね」の読み込みも効率化された最終版のメソッド ▼▼▼
  Future<void> _fetchRelatedData() async {
    final futures = [
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('following')
          .get(),
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('saved_posts')
          .get(),
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('liked_posts')
          .get(), // 新しいデータ構造を読む
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(child: Text('今日の投稿はまだありません。'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return PostGridCard(
          post: post,
          isLikedByCurrentUser: _likedPostIds.contains(post.id),
          isSavedByCurrentUser: _savedPostIds.contains(post.id),
          isFollowingAuthor: _followingUserIds.contains(post.userId),
        );
      },
    );
  }
}
