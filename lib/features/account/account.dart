import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/post_model.dart';
import '../../widgets/post_grid_card.dart';
import '../../widgets/common_app_bar.dart';
import 'edit_profile_page.dart';
import 'follower_list_page.dart';
import 'saved_posts_page.dart';
import '../chat/talk_page.dart';
import 'settings_page.dart';
import '../../providers/following_provider.dart';
import '../../providers/followers_provider.dart';
part 'account.g.dart';

@riverpod
Stream<DocumentSnapshot> userDocStream(UserDocStreamRef ref, String userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
}

@riverpod
Stream<List<Post>> userPosts(UserPostsRef ref, String userId) {
  return FirebaseFirestore.instance
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
      );
}

class MyPage extends ConsumerWidget {
  final String userId;
  const MyPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isCurrentUserProfile = currentUser.uid == userId;

    final userDocAsyncValue = ref.watch(userDocStreamProvider(userId));
    final userPostsAsyncValue = ref.watch(userPostsProvider(userId));

    return Scaffold(
      appBar: CommonAppBar(
        title: Text(isCurrentUserProfile ? 'マイページ' : 'プロフィール'),
        actions: [
          if (isCurrentUserProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '設定',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ),
            ),
        ],
      ),
      body: userDocAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('ユーザー情報の読み込みに失敗: $err')),
        data: (userDoc) {
          if (!userDoc.exists) {
            return const Center(child: Text('ユーザーが見つかりません。'));
          }
          final monthlyData = userPostsAsyncValue.when(
            data: (posts) => _createMonthlyChartData(posts),
            loading: () => <String, int>{},
            error: (_, __) => <String, int>{},
          );
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileArea(context, ref, userDoc),
                const SizedBox(height: 16),
                _buildStatsSection(context, userDoc),
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
                _buildUserPostsGrid(ref, userPostsAsyncValue),
              ],
            ),
          );
        },
      ),
    );
  }

  // ▼▼▼【ここから下を修正】すべてのヘルパーメソッドをMyPageクラスの内側に移動 ▼▼▼

  Widget _buildProfileArea(
    BuildContext context,
    WidgetRef ref,
    DocumentSnapshot userDoc,
  ) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final photoUrl = userData['photoUrl'] as String? ?? '';
    final displayName = userData['displayName'] as String? ?? '名無しさん';
    final introduction = userData['introduction'] as String? ?? '自己紹介がありません';
    final rank = userData['rank'] as String? ?? 'beginner';
    final isCurrentUser = FirebaseAuth.instance.currentUser!.uid == userId;

    final followingState = ref.watch(followingNotifierProvider);
    final isFollowing = followingState.value?.contains(userId) ?? false;
    final followersState = ref.watch(followersNotifierProvider);
    final followsYou = followersState.value?.contains(userId) ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      width: double.infinity,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isCurrentUser && followsYou)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 104, 104),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'フォローされています',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                fontSize: 12,
                              ),
                            ),
                          ),
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isCurrentUser)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('プロフィールを編集'),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('チャット'),
                          onPressed: () => _startChat(context, userDoc),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref
                                .read(followingNotifierProvider.notifier)
                                .handleFollow(userId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing
                                ? Colors.white
                                : Colors.blue,
                            foregroundColor: isFollowing
                                ? Colors.blue
                                : Colors.white,
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(isFollowing ? 'フォロー中' : 'フォロー'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserPostsGrid(WidgetRef ref, AsyncValue<List<Post>> asyncValue) {
    return asyncValue.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(child: Text('エラー: $err')),
      data: (posts) {
        if (posts.isEmpty) {
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
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostGridCard(post: posts[index]);
          },
        );
      },
    );
  }

  Future<void> _startChat(
    BuildContext context,
    DocumentSnapshot otherUserDoc,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final myId = currentUser.uid;
    final otherUserId = otherUserDoc.id;
    final otherUserData = otherUserDoc.data() as Map<String, dynamic>;
    final userIds = [myId, otherUserId]..sort();
    final chatRoomId = userIds.join('_');
    final chatRoomRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId);
    final docSnapshot = await chatRoomRef.get();
    if (!docSnapshot.exists) {
      await chatRoomRef.set({
        'userIds': userIds,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TalkPage(
            chatRoomId: chatRoomId,
            chatTitle: otherUserData['displayName'] ?? '名無しさん',
            isGroupChat: false,
          ),
        ),
      );
    }
  }

  // (中身は変更なし)
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

  Widget _buildStatsSection(BuildContext context, DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final totalCatches = (userData['totalCatches'] ?? 0).toString();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('釣果数', totalCatches),
        _buildTappableStatItem(
          context,
          '保存',
          'saved_posts',
          SavedPostsPage(userId: userId),
        ),
        _buildTappableStatItem(
          context,
          'フォロワー',
          'followers',
          FollowerListPage(userId: userId, listType: FollowListType.followers),
        ),
        _buildTappableStatItem(
          context,
          'フォロー中',
          'following',
          FollowerListPage(userId: userId, listType: FollowListType.following),
        ),
      ],
    );
  }

  // (中身は変更なし)
  Widget _buildTappableStatItem(
    BuildContext context,
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
              .doc(userId)
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

  // (中身は変更なし)
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

  // (中身は変更なし)
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

  // (中身は変更なし)
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

  // (中身は変更なし)
  Map<String, int> _createMonthlyChartData(List<Post> posts) {
    final Map<String, int> data = {};
    for (var post in posts) {
      final monthKey = DateFormat('yyyy-MM').format(post.createdAt);
      data.update(monthKey, (value) => value + 1, ifAbsent: () => 1);
    }
    return data;
  }
}
