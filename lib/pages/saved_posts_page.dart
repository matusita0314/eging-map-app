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
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'バッジ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Center(child: Text('取得したバッジはありません')),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final photoUrl = userData['photoUrl'] as String? ?? '';
    final displayName = userData['displayName'] as String? ?? '名無しさん';
    final introduction = userData['introduction'] as String? ?? '自己紹介がありません';
    final isCurrentUser = _currentUser.uid == widget.userId;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 24),
      width: double.infinity,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  introduction,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              ],
            ),
          ),
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'プロフィールを編集',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EditProfilePage(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(int postCount, int totalLikes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('釣果数', postCount.toString()),
        _buildStatItem('総いいね', totalLikes.toString()),
        _buildTappableStatItem(
          '保存',
          'saved_posts',
          SavedPostsPage(userId: widget.userId),
        ),
        _buildTappableStatItem(
          'フォロワー',
          'followers',
          FollowerListPage(
            userId: widget.userId,
            listType: FollowListType.followers,
          ),
        ),
        _buildTappableStatItem(
          'フォロー中',
          'following',
          FollowerListPage(
            userId: widget.userId,
            listType: FollowListType.following,
          ),
        ),
      ],
    );
  }

  Widget _buildTappableStatItem(
    String label,
    String collectionPath,
    Widget destinationPage,
  ) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => destinationPage)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection(collectionPath)
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            return _buildStatItem(label, count.toString());
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildChartSection(Map<String, int> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '月別釣果グラフ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        sortedEntries[value.toInt()].key.substring(
                          5,
                        ), // '2024-07' -> '07'
                        style: const TextStyle(fontSize: 10),
                      ),
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(sortedEntries.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: sortedEntries[index].value.toDouble(),
                        color: Colors.blue,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _createMonthlyChartData(List<Post> posts) {
    final Map<String, int> data = {};
    for (var post in posts) {
      final monthKey = DateFormat('yyyy-MM').format(post.createdAt);
      data.update(monthKey, (value) => value + 1, ifAbsent: () => 1);
    }
    return data;
  }
}
