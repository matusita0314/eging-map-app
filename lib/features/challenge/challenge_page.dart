import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/challenge_model.dart';

// ChallengeDetailPageは不要になったのでimport文を削除

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // ▼▼▼ DBの日本語化に合わせて、このリストのみを使用します ▼▼▼
  final List<String> _ranks = ['ビギナー', 'アマチュア', 'プロ'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _ranks.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF13547a), // 深い青
              Color(0xFF80d0c7), // 明るい水色
            ],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // フローティング風AppBar (変更なし)
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
                        const Expanded(
                          child: Text(
                            'チャレンジ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF13547a),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.help_outline, color: Color(0xFF13547a)),
                          tooltip: 'チャレンジミッション',
                          onPressed: () => _showHelpDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                // ピン留めされるタブバー (変更なし)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF13547a).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(35),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.all(4),
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF13547a),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          tabs: _ranks.map((rank) => Tab(text: rank.toUpperCase())).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 1)),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: _ranks.map((rank) => _MissionList(rank: rank)).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// _StickyTabBarDelegate (変更なし)
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});
  @override
  double get minExtent => 70.0;
  @override
  double get maxExtent => 70.0;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.transparent,
      child: SizedBox(height: 75.0, child: child),
    );
  }
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate != this;
  }
}

class _MissionList extends StatelessWidget {
  final String rank;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  _MissionList({required this.rank});

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('ログインが必要です。', style: TextStyle(color: Colors.white, fontSize: 16)));
    }

    final userStream = FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots();
    final challengesStream = CombineLatestStream.combine2(
      FirebaseFirestore.instance.collection('challenges').where('rank', isEqualTo: rank).snapshots(),
      FirebaseFirestore.instance.collection('users').doc(_currentUserId).collection('completed_challenges').snapshots(),
      (QuerySnapshot challenges, QuerySnapshot completed) => {'challenges': challenges, 'completed': completed},
    );

    return StreamBuilder<DocumentSnapshot>(
      stream: userStream,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
        }
        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

        return StreamBuilder<Map<String, QuerySnapshot>>(
          stream: challengesStream,
          builder: (context, challengesSnapshot) {
            if (challengesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
            }
            if (challengesSnapshot.hasError) {
              return const Center(child: Text('エラーが発生しました', style: TextStyle(color: Colors.red, fontSize: 16)));
            }
            if (!challengesSnapshot.hasData || challengesSnapshot.data!['challenges']!.docs.isEmpty) {
              return const Center(child: Text('このランクのミッションはありません。', style: TextStyle(color: Colors.white, fontSize: 16)));
            }

            final allChallengesDocs = challengesSnapshot.data!['challenges']!.docs;
            final completedChallengesDocs = challengesSnapshot.data!['completed']!.docs;
            final completedChallengeIds = completedChallengesDocs.map((doc) => doc.id).toSet();
            final challenges = allChallengesDocs.map((doc) => Challenge.fromFirestore(doc)).toList();

             challenges.sort((a, b) {
              final aIsCompleted = completedChallengeIds.contains(a.id);
              final bIsCompleted = completedChallengeIds.contains(b.id);

              if (aIsCompleted && !bIsCompleted) {
                return 1; // a（達成済み）をb（未達成）より前に配置
              } else if (!aIsCompleted && bIsCompleted) {
                return -1;  // b（達成済み）をa（未達成）より前に配置
              } else {
                return 0;  // 両方達成済み、または両方未達成の場合は順序を変えない
              }
            });

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: challenges.length,
              itemBuilder: (context, index) {
                final challenge = challenges[index];
                final isCompleted = completedChallengeIds.contains(challenge.id);
                
                return _ChallengeCard(
                  challenge: challenge,
                  isCompleted: isCompleted,
                  userData: userData,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ▼▼▼【新規】各チャレンジカードのウィジェットを分離 ▼▼▼
class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final bool isCompleted;
  final Map<String, dynamic> userData;

  const _ChallengeCard({
    required this.challenge,
    required this.isCompleted,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    num currentValue = 0;
    num threshold = challenge.threshold;
    String unit = '';
    bool isBooleanType = false;

    switch (challenge.type) {
      case 'totalCatches': currentValue = userData['totalCatches'] ?? 0; unit = '杯'; break;
      case 'maxSize': currentValue = userData['maxSize'] ?? 0; unit = 'cm'; break;
      case 'maxWeight': currentValue = userData['maxWeight'] ?? 0; unit = 'g'; break;
      case 'followerCount': currentValue = userData['followerCount'] ?? 0; unit = '人'; break;
      case 'followingCount': currentValue = userData['followingCount'] ?? 0; unit = '人'; break;
      case 'totalLikesReceived': currentValue = userData['totalLikesReceived'] ?? 0; unit = '個'; break;
      case 'hasCreatedGroup': isBooleanType = true; currentValue = (userData['hasCreatedGroup'] == true) ? 1 : 0; break;
      case 'hasJoinedTournament': isBooleanType = true; currentValue = (userData['hasJoinedTournament'] == true) ? 1 : 0; break;
    }

    final double progress = (threshold > 0) ? (currentValue / threshold).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: isCompleted ? 2 : 6, // 達成済みは影を控えめに
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isCompleted ? const Color.fromARGB(255, 223, 255, 226) : Colors.white, // 達成済みは淡いグリーン
      child: Padding(
        padding: const EdgeInsets.all(20.0), // 全体的にパディングを増やす
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトルと達成アイコン
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    challenge.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18, // 少し大きめに
                      color: isCompleted ? const Color(0xFF2E7D32) : const Color(0xFF13547a),
                    ),
                  ),
                ),
                if (isCompleted)
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 36),
              ],
            ),
            const SizedBox(height: 12),
            // 説明文
            Text(
              challenge.description,
              style: TextStyle(
                fontSize: 14,
                color: isCompleted ? Colors.black54 : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // 進捗バーと数値
            if (!isBooleanType) // Booleanタイプ以外のみ進捗数値表示
              Column(
                children: [
                  _FillableRainbowProgressIndicator(progress: progress),
                  const SizedBox(height: 10),
                  Text(
                    '${currentValue.toStringAsFixed(0)} $unit / ${threshold.toStringAsFixed(0)} $unit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? const Color(0xFF2E7D32) : const Color(0xFF13547a),
                    ),
                  ),
                ],
              )
            else // Booleanタイプの場合
              _FillableRainbowProgressIndicator(progress: progress),

            const SizedBox(height: 16),
            // 達成状況テキスト
            Center(
              child: Text(
                progress >= 1.0
                    ? '🎉 ミッション達成！🎉'
                    : isBooleanType
                        ? '未達成'
                        : 'あと ${(threshold - currentValue).clamp(0, threshold).toStringAsFixed(0)} $unit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1.0 ? Colors.green.shade600 : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillableRainbowProgressIndicator extends StatelessWidget {
  final double progress;
  const _FillableRainbowProgressIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    // 表示したい虹色のグラデーションを定義
    const List<Color> rainbowColors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
    ];

    return Container(
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          // 1. 背景のタンク
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.15)),
            ),
          ),

          // 2. 虹色のプログレス部分
          // ClipRRectで角を丸く切り取る
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            // AlignのwidthFactorを使って表示領域を制御
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              // このContainerは常に全幅で描画されようとする
              child: Container(
                decoration: const BoxDecoration(
                  // グラデーションは常に虹色全体を描画
                  gradient: LinearGradient(
                    colors: rainbowColors,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text( 'チャレンジミッション', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const SingleChildScrollView(
        child: Text(
          'チャレンジミッションは、あなたのエギングスキルを証明するための課題です。\n\n'
          '■ ランクと昇格\n'
          'エギワンでは「ビギナー」「アマチュア」「プロ」の3つのランクが存在します。\n'
          '各ランクに設定された全てのミッションをクリアすると、次のランクに昇格することができます。\n\n'
          'ここでのランクによって大会で出場できる階級が決まります。\n\n'
          '■ ミッションの達成\n'
          'ミッションは、日々の釣果を投稿することで自動的に達成されます。\n'
          '例えば、「累計で5杯釣る」というミッションは、あなたが5回釣果を投稿した時点で自動的にクリアとなります。\n\n'
          '■ プロのミッション\n'
          'プロミッションもすべてクリアすると、バッジがもらえます！\n'
          'プロのエギンガーとして認定されます！\n\n'
          'より高みを目指し、全てのミッション達成に挑戦してみてください！',
          style: TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom( foregroundColor: const Color(0xFF13547a)),
          child: const Text('閉じる', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}