import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/post_feed_card.dart';
import '../../models/sort_by.dart';
import '../auth/login_page.dart';

import '../../models/post_model.dart';
import '../../widgets/common_app_bar.dart';
import 'edit_profile_page.dart';
import 'follower_list_page.dart';
import 'saved_posts_page.dart';
import '../chat/talk_page.dart';
import 'settings_page.dart';
import '../../providers/post_provider.dart';
import '../../providers/following_provider.dart';
import '../../providers/followers_provider.dart';
part 'account.g.dart';

final myPageSortByProvider = StateProvider<SortBy>((ref) => SortBy.createdAt);

@riverpod
Stream<DocumentSnapshot> userDocStream(UserDocStreamRef ref, String userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
}

class MyPage extends ConsumerWidget {
  final String userId;
  const MyPage({super.key, required this.userId});

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text('本当にログアウトしますか？',style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13547a),
                          ),),
          actions: [
            TextButton(
              child: const Text('キャンセル',style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13547a),
                          ),),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('ログアウト', style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 202, 10, 10),
                          ),),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()), 
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
Widget build(BuildContext context, WidgetRef ref) {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final isCurrentUserProfile = currentUser.uid == userId;

  final userDocAsyncValue = ref.watch(userDocStreamProvider(userId));
  final sortBy = ref.watch(myPageSortByProvider); 
  final userPostsAsyncValue = ref.watch(userPostsProvider(userId: userId, sortBy: sortBy));

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
                      // 他のユーザーのプロフィールの場合のみ戻るボタンを表示
                      if (!isCurrentUserProfile)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      Expanded(
                        child: Text(
                          isCurrentUserProfile ? 'マイページ' : 'プロフィール',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13547a),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (isCurrentUserProfile) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFF13547a)),
                              tooltip: 'プロフィールを編集',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const EditProfilePage()),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: Color(0xFF13547a)),
                              tooltip: '設定',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const SettingsPage()),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Color(0xFF13547a)),
                              tooltip: 'ログアウト',
                              onPressed: () => _handleLogout(context), // ログアウト処理を呼び出す
                            ),

                          ] else
                            const SizedBox(width: 48), // バランスを保つためのスペース
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ];
          },
          body: userDocAsyncValue.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            error: (err, stack) => Center(
              child: Text(
                'ユーザー情報の読み込みに失敗: $err',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            data: (userDoc) {
              if (!userDoc.exists) {
                return const Center(
                  child: Text(
                    'ユーザーが見つかりません。',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                );
              }
              final monthlyData = userPostsAsyncValue.when(
                data: (posts) => _createMonthlyChartData(posts),
                loading: () => <String, int>{},
                error: (_, __) => <String, int>{},
              );
              return CustomScrollView(
                slivers: [
                  // 統合されたプロフィールエリア
                  SliverToBoxAdapter(
                    child: _buildProfileArea(context, ref, userDoc),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  
                  // チャートセクション
                  SliverToBoxAdapter(
                    child: _buildChartSection(monthlyData),
                  ),
                  const SliverToBoxAdapter(
                    child: Divider(color: Colors.white30),
                  ),
                  
                  // 投稿セクション
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'これまでの投稿',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SortHeader(sortByProvider: myPageSortByProvider),
                  ),
                  const SliverToBoxAdapter(
                    child: Divider(height: 1, color: Colors.white30),
                  ),
                  _buildUserPostsList(ref, userPostsAsyncValue),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}



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
  final totalCatches = (userData['totalCatches'] ?? 0).toString();
  final isCurrentUser = FirebaseAuth.instance.currentUser!.uid == userId;

  final followingState = ref.watch(followingNotifierProvider);
  final isFollowing = followingState.value?.contains(userId) ?? false;
  final followersState = ref.watch(followersNotifierProvider);
  final followsYou = followersState.value?.contains(userId) ?? false;

  return Container(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    margin: const EdgeInsets.symmetric(horizontal: 16),
    width: double.infinity,
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // プロフィール情報
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 小さくしたアイコン
            CircleAvatar(
              radius: 30, // 40から30に変更
              backgroundImage: photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 30) // 40から30に変更
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ユーザー名とランク
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22, // 24から22に変更
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRankBadge(rank),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // フォローされています表示
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
                      child: const Text(
                        'フォローされています',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  
                  // 自己紹介
                  Text(
                    introduction,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // バッジセクション（横並び）
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'バッジ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '取得したバッジはありません',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // 統計情報
        Row(
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
        ),
        
        const SizedBox(height: 20),
        
        // ボタン（プロフィール編集ボタンは削除）
        if (!isCurrentUser)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text.rich(
                    TextSpan(
                      text: 'チャット',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  onPressed: () => _startChat(context, userDoc),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: Colors.blue.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: Colors.blue.withOpacity(0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    isFollowing ? 'フォロー中' : '+ フォロー',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

  Widget _buildUserPostsList(WidgetRef ref, AsyncValue<List<Post>> asyncValue) {
    return asyncValue.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(
          child: Text(
            'エラー: $err',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'まだ投稿がありません。',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: PostFeedCard(post: posts[index], showAuthorInfo: true),
              );
            },
            childCount: posts.length,
          ),
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
      default:
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
      ),
    );
  }

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
      child: const Column(
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
}

class SortHeader extends ConsumerWidget {
  final StateProvider<SortBy> sortByProvider;
  const SortHeader({required this.sortByProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSortBy = ref.watch(sortByProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        alignment: WrapAlignment.center,
        children: SortBy.values.map((sort) {
          return ChoiceChip(
            label: Text(sort.displayName),
            selected: currentSortBy == sort,
            onSelected: (isSelected) {
              if (isSelected) {
                ref.read(sortByProvider.notifier).state = sort;
              }
            },
          );
        }).toList(),
      ),
    );
  }
}