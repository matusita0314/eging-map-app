import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../widgets/post_feed_card.dart';
import '../../models/sort_by.dart';
import '../auth/login_page.dart';
import '../../widgets/ranked_circle_avatar.dart';
import '../../models/post_model.dart';
import 'edit_profile_page.dart';
import 'follower_list_page.dart';
import 'saved_posts_page.dart';
import '../chat/talk_page.dart';
import 'settings_page.dart';
import '../../providers/post_provider.dart';
import '../../providers/following_provider.dart';
import '../../providers/achievement_provider.dart'; 

part 'account.g.dart';

final myPageSortByProvider = StateProvider<SortBy>((ref) => SortBy.createdAt);
final followersCountProvider = StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).collection('followers').snapshots().map((snapshot) => snapshot.size);
});
final followingCountProvider = StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).collection('following').snapshots().map((snapshot) => snapshot.size);
});
final savedPostsCountProvider = StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).collection('saved_posts').snapshots().map((snapshot) => snapshot.size);
});

@riverpod
Stream<DocumentSnapshot> userDocStream(UserDocStreamRef ref, String userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
}

class MyPage extends ConsumerStatefulWidget {
  final String userId;
  const MyPage({super.key, required this.userId});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  late int _currentYear;
  int? _touchedIndex;
  bool _isChartExpanded = false; 

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text(
            '本当にログアウトしますか？',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF13547a),
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                'キャンセル',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF13547a),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'ログアウト',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 202, 10, 10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isCurrentUserProfile = currentUser.uid == widget.userId;

    final userDocAsyncValue = ref.watch(userDocStreamProvider(widget.userId));
    final sortBy = ref.watch(myPageSortByProvider);
    final userPostsAsyncValue = ref.watch(userPostsProvider(userId: widget.userId, sortBy: sortBy));

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
                        if (Navigator.canPop(context))
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
                                onPressed: () => _handleLogout(context),
                              ),
                            ] else
                              const SizedBox(width: 48),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: userDocAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
              error: (err, stack) => Center(child: Text('ユーザー情報の読み込みに失敗: $err', style: const TextStyle(color: Colors.white))),
              data: (userDoc) {
                if (!userDoc.exists) {
                  return const Center(child: Text('ユーザーが見つかりません。', style: TextStyle(color: Colors.white, fontSize: 16)));
                }
                final monthlyData = userPostsAsyncValue.when(
                  data: (posts) => _createMonthlyChartData(posts, _currentYear),
                  loading: () => <int, int>{},
                  error: (_, __) => <int, int>{},
                );
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: const SizedBox(height: 16)),
                    SliverToBoxAdapter(child: _buildUserProfileHeader(context, ref, userDoc)),
                    
                    const SliverToBoxAdapter(child: SizedBox(height: 16)), 

                    SliverToBoxAdapter(child: _buildAchievementsAndHighlightsCard(context, ref, userDoc)),
                    SliverToBoxAdapter(child: const SizedBox(height: 16)),
                    SliverToBoxAdapter(child: _buildChartSection(monthlyData)),
                    const SliverToBoxAdapter(child: Divider(color: Colors.white30, indent: 16, endIndent: 16, height: 32)),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text('これまでの投稿', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    SliverToBoxAdapter(child: SortHeader(sortByProvider: myPageSortByProvider)),
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
  // 1. ユーザー情報ヘッダー
  Widget _buildUserProfileHeader(BuildContext context, WidgetRef ref, DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final photoUrl = userData['photoUrl'] as String? ?? '';
    final displayName = userData['displayName'] as String? ?? '名無しさん';
    final introduction = userData['introduction'] as String? ?? '自己紹介がありません';
    final rank = userData['rank'] as String? ?? 'beginner';
    final isCurrentUser = FirebaseAuth.instance.currentUser!.uid == widget.userId;
    final isFollowing = ref.watch(followingNotifierProvider).value?.contains(widget.userId) ?? false;

    // 統計情報を監視
    final followersCount = ref.watch(followersCountProvider(widget.userId)).value ?? 0;
    final followingCount = ref.watch(followingCountProvider(widget.userId)).value ?? 0;
    final savedPostsCount = ref.watch(savedPostsCountProvider(widget.userId)).value ?? 0;

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 上段：プロフィール情報 & 統計 ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RankedCircleAvatar(photoUrl: photoUrl, rank: rank, radius: 35),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ユーザー名とランクバッジ
                    Row(
                      children: [
                        Flexible(child: Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        _buildRankBadge(rank),
                        IconButton(
                          icon: Icon(Icons.help_outline, color: Colors.grey.shade600, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('ランクと大会について'),
                                content: const Text('ランクが上がった場合、新しいランクに対応する大会に参加できるのは翌月の1日からとなります。'),
                                actions: [
                                  TextButton(
                                    child: const Text('OK'),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ひとこと（自己紹介）
                    Text(introduction, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 16),
          
          // --- 中段：統計情報 ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('フォロワー', followersCount.toString(), () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => FollowerListPage(userId: widget.userId, listType: FollowListType.followers)));
              }),
              _buildStatColumn('フォロー', followingCount.toString(), () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => FollowerListPage(userId: widget.userId, listType: FollowListType.following)));
              }),
              if (isCurrentUser)
                _buildStatColumn('保存済み', savedPostsCount.toString(), () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => SavedPostsPage(userId: widget.userId)));
                }),
            ],
          ),

          // --- 下段：ボタン（自分以外のプロフィールの場合） ---
          if (!isCurrentUser) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('チャット'),
                    onPressed: () => _startChat(context, userDoc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.withOpacity(0.5))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref.read(followingNotifierProvider.notifier).handleFollow(widget.userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.white : Colors.blue,
                      foregroundColor: isFollowing ? Colors.blue : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.withOpacity(0.5))),
                    ),
                    child: Text(isFollowing ? 'フォロー中' : '+ フォロー'),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

    Widget _buildHighlightItem(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        // 文字色を黒系に変更
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        // 文字色をグレー系に変更
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
  
  Widget _buildAchievementsAndHighlightsCard(BuildContext context, WidgetRef ref, DocumentSnapshot userDoc) {
  final userData = userDoc.data() as Map<String, dynamic>? ?? {};
  final totalCatches = userData['totalCatches']?.toString() ?? '0';
  final maxSize = userData['maxSize']?.toStringAsFixed(1) ?? '0.0';
  final titlesAsync = ref.watch(awardedTitlesProvider(widget.userId));

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // 背景を白系のグラデーションに変更
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        // 縁取りはゴールドのまま
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            // 影を薄く調整
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: titlesAsync.when(
        data: (titles) {
          final winCount = titles.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['title'] as String?)?.contains('優勝') ?? false;
          }).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('獲得した称号', style: TextStyle(color: Color(0xFF13547a), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (titles.docs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1), // 背景色を調整
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events_outlined, color: Colors.amber, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        '大会で入賞して称号をゲットしよう！',
                        textAlign: TextAlign.center,
                        // 文字色を調整
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  children: titles.docs.map((doc) {
                    final titleData = doc.data() as Map<String, dynamic>;
                    final titleText = titleData['title'] ?? '';
                    final isGold = titleText.contains('優勝');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isGold
                              ? [Colors.amber.shade300, Colors.amber.shade600]
                              : [Colors.white, Colors.grey.shade200], // 優勝以外は白〜グレー系
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: isGold ? Colors.amber.withOpacity(0.4) : Colors.black.withOpacity(0.1),
                            blurRadius: 6, offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, color: isGold ? Colors.white : const Color(0xFF13547a), size: 16),
                          const SizedBox(width: 8),
                          Flexible(child: Text(titleText, style: TextStyle(color: isGold ? Colors.white : const Color(0xFF13547a), fontWeight: FontWeight.bold))),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              // === 区切り線 ===
              Divider(color: Colors.grey.shade200, height: 32),

              // === ハイライトエリア ===
              IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHighlightItem(Icons.military_tech, '大会優勝', '$winCount 回', Colors.amber),
                    VerticalDivider(color: Colors.grey.shade200, thickness: 1, indent: 8, endIndent: 8),
                    _buildHighlightItem(Icons.straighten, '最大サイズ', '$maxSize cm', Colors.lightBlue),
                    VerticalDivider(color: Colors.grey.shade200, thickness: 1, indent: 8, endIndent: 8),
                    _buildHighlightItem(Icons.phishing, '総釣果数', '$totalCatches 杯', Colors.lightGreen),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Text('エラーが発生しました'),
      ),
    ),
  );
}

  Widget _buildStatColumn(String label, String count, [VoidCallback? onTap]) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildChartSection(Map<int, int> data) {
    final bool hasDataForYear = data.values.any((v) => v > 0);
    final maxCount = hasDataForYear ? data.values.reduce((a, b) => a > b ? a : b) : 0;
    double maxY = 10;
    if (maxCount >= 10) {
      maxY = (maxCount / 10).ceil() * 10.0;
    }

    const barGradient = LinearGradient(
      colors: [
        Colors.lightBlueAccent,
        Colors.blueAccent,
      ],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // パディングを少し調整
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // クリック可能なタイトル部分
          InkWell(
            onTap: () {
              setState(() {
                _isChartExpanded = !_isChartExpanded; // 状態を反転させる
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // --- 中央に配置するタイトルとアイコン ---
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Rowの幅をコンテンツに合わせる
                      children: [
                        const Icon(Icons.bar_chart_rounded, color: Color(0xFF13547a)),
                        const SizedBox(width: 8),
                        const Text(
                          '月別釣果グラフ',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13547a)),
                        ),
                      ],
                    ),
                  ),
                  // --- 右端に配置する開閉アイコン ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      _isChartExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // _isChartExpandedがtrueの場合のみ、グラフと年セレクターを表示
          if (_isChartExpanded) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () => setState(() {
                    _currentYear--;
                    _touchedIndex = null;
                  }),
                ),
                Text(
                  '$_currentYear年',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () => setState(() {
                    _currentYear++;
                    _touchedIndex = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: hasDataForYear
                  ? BarChart(
                      BarChartData(
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => Colors.blueGrey,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.round()} 杯',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                          touchCallback: (event, response) {
                            if (event.isInterestedForInteractions && response?.spot != null) {
                              setState(() {
                                _touchedIndex = response!.spot!.touchedBarGroupIndex;
                              });
                            } else {
                              setState(() {
                                _touchedIndex = -1;
                              });
                            }
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Text(
                                '${value.toInt() + 1}月',
                                style: const TextStyle(fontSize: 10, color: Colors.black54),
                              ),
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                 if (value == 0 || value == meta.max) return const Text('');
                                 return DefaultTextStyle(
                                   style: const TextStyle(color: Colors.black54, fontSize: 10),
                                   child: Text(value.toInt().toString(), textAlign: TextAlign.left),
                                 );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(12, (index) {
                          final isTouched = index == _touchedIndex;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: data[index + 1]?.toDouble() ?? 0,
                                gradient: barGradient,
                                width: isTouched ? 20 : 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'この年の投稿はありません。',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }


  Map<int, int> _createMonthlyChartData(List<Post> posts, int year) {
    final Map<int, int> data = {for (var i = 1; i <= 12; i++) i: 0};
    final yearlyPosts = posts.where((post) => post.createdAt.year == year);
    for (var post in yearlyPosts) {
      data.update(post.createdAt.month, (value) => value + 1, ifAbsent: () => 1);
    }
    return data;
  }

  // 5. 投稿リスト
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

  // 6. ヘルパーメソッド群
  Future<void> _startChat(BuildContext context, DocumentSnapshot otherUserDoc) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final myId = currentUser.uid;
    final otherUserId = otherUserDoc.id;
    final otherUserData = otherUserDoc.data() as Map<String, dynamic>;
    final userIds = [myId, otherUserId]..sort();
    final chatRoomId = userIds.join('_');
    final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId);
    final docSnapshot = await chatRoomRef.get();
    if (!docSnapshot.exists) {
      await chatRoomRef.set({
        'userIds': userIds,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) {
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
        badgeColor = const Color.fromARGB(255, 210, 84, 25);
        badgeText = 'アマチュア';
        break;
      case 'pro':
        badgeColor = const Color.fromARGB(255, 255, 60, 60);
        badgeText = 'プロ';
        break;
      default:
        badgeColor = const Color.fromARGB(255, 0, 163, 19);
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
}

class SortHeader extends ConsumerWidget {
  final StateProvider<SortBy> sortByProvider;
  const SortHeader({super.key, required this.sortByProvider});

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