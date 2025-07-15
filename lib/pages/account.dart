import 'dart:async';
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

class MyPage extends StatefulWidget {
  final String userId;
  const MyPage({super.key, required this.userId});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
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
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    _postsSubscription = stream.listen((snapshot) {
      // ▼▼▼ ご要望のログ出力を追加 ▼▼▼
      print("◉ アカウントの投稿データを受信 (件数: ${snapshot.docs.length})");

      if (mounted) {
        setState(() {
          _posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
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
          .get(),
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
    // ユーザーのプロフィール情報（ランクや累計釣果数など）はリアルタイムで更新を反映させたいので、
    // FutureBuilderからStreamBuilderに変更します。
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final userDoc = userSnapshot.data!;
          final monthlyData = _createMonthlyChartData(_posts);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(userDoc),
                const SizedBox(height: 16),
                _buildStatsSection(userDoc),
                const Divider(height: 32),
                _buildChartSection(monthlyData),
                const Divider(),
                _buildBadgeSection(),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'これまでの投稿',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildUserPostsGrid(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final photoUrl = userData['photoUrl'] as String? ?? '';
    final displayName = userData['displayName'] as String? ?? '名無しさん';
    final introduction = userData['introduction'] as String? ?? '自己紹介がありません';
    final rank = userData['rank'] as String? ?? 'beginner';
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildRankBadge(rank),
                  ],
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

  Widget _buildRankBadge(String rank) {
    Color badgeColor;
    String badgeText;
    switch (rank) {
      case 'amateur':
        badgeColor = Colors.blue.shade700;
        badgeText = 'アマチュア';
        break;
      case 'pro':
        badgeColor = Colors.amber.shade800;
        badgeText = 'プロ';
        break;
      default: // beginner
        badgeColor = Colors.green;
        badgeText = 'ビギナー';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatsSection(DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final totalCatches = (userData['totalCatches'] ?? 0).toString();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('釣果数', totalCatches),
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
                        sortedEntries[value.toInt()].key.substring(5),
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

  Widget _buildUserPostsGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('まだ投稿がありません。'),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
