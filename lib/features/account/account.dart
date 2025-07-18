import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/post_model.dart';
import '../../widgets/post_grid_card.dart';
import 'edit_profile_page.dart';
import 'follower_list_page.dart';
import 'saved_posts_page.dart';
import '../chat/talk_page.dart';
import 'settings_page.dart';

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

  // ▼▼▼【追加】チャットを開始するためのメソッド ▼▼▼
  Future<void> _startChat(DocumentSnapshot otherUserDoc) async {
    final myId = _currentUser.uid;
    final otherUserId = otherUserDoc.id;
    final otherUserData = otherUserDoc.data() as Map<String, dynamic>;

    // ユーザーIDをソートして、常に同じchatRoomIdを生成する
    final userIds = [myId, otherUserId];
    userIds.sort();
    final chatRoomId = userIds.join('_');

    final chatRoomRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId);
    final docSnapshot = await chatRoomRef.get();

    // チャットルームが存在しなければ作成
    if (!docSnapshot.exists) {
      await chatRoomRef.set({
        'userIds': userIds,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // TalkPageへ遷移
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TalkPage(
            chatRoomId: chatRoomId,
            otherUserName: otherUserData['displayName'] ?? '名無しさん',
            otherUserPhotoUrl: otherUserData['photoUrl'] ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUserProfile = _currentUser.uid == widget.userId;
    return Scaffold(
      appBar: CommonAppBar(
        // Textウィジェットを渡す
        title: Text(isCurrentUserProfile ? 'マイページ' : 'プロフィール'),
        actions: [
          // 自分のプロフィールページの場合のみ設定ボタンを表示
          if (isCurrentUserProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '設定',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData) {
            return const Center(child: Text('ユーザーが見つかりません。'));
          }

          final userDoc = userSnapshot.data!;
          final monthlyData = _createMonthlyChartData(_posts);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(userDoc),
                // ▼▼▼【追加】アクションボタン領域 ▼▼▼
                _buildActionButtons(userDoc),
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

  // ▼▼▼【追加】戻る、編集、チャットボタンをまとめたウィジェット ▼▼▼
  Widget _buildActionButtons(DocumentSnapshot userDoc) {
    final isCurrentUser = _currentUser.uid == widget.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // 自分のプロフィールの場合は「編集」、他人の場合は「チャット」ボタン
          if (isCurrentUser)
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('編集'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EditProfilePage(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('チャット'),
                onPressed: () => _startChat(userDoc),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ▼▼▼【修正】ヘッダーから編集ボタンを削除 ▼▼▼
  Widget _buildProfileHeader(DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final photoUrl = userData['photoUrl'] as String? ?? '';
    final displayName = userData['displayName'] as String? ?? '名無しさん';
    final introduction = userData['introduction'] as String? ?? '自己紹介がありません';
    final rank = userData['rank'] as String? ?? 'beginner';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 16),
      width: double.infinity,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 編集ボタンは _buildActionButtons に移動したため、ここからは削除
        ],
      ),
    );
  }

  // --- 以下、変更なし ---

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
