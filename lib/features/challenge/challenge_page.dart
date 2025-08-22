import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'challenge_detail_page.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/challenge_model.dart';

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _ranks = ['beginner', 'amateur', 'pro'];

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
                // ピン留めされるタブバー
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

// カスタムSliverPersistentHeaderDelegate
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
      return const Center(
        child: Text(
          'ログインが必要です。',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.combine2(
        FirebaseFirestore.instance
            .collection('challenges')
            .where('rank', isEqualTo: rank)
            .snapshots(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('completed_challenges')
            .snapshots(),
        (challengesSnapshot, completedChallengesSnapshot) => [
          challengesSnapshot,
          completedChallengesSnapshot,
        ],
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'エラーが発生しました',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data![0].docs.isEmpty) {
          return const Center(
            child: Text(
              'このランクのミッションはありません。',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        final allChallengesDocs = snapshot.data![0].docs;
        final completedChallengesDocs = snapshot.data![1].docs;

        final completedChallengeIds = completedChallengesDocs
            .map((doc) => doc.id)
            .toSet();

        final challenges = allChallengesDocs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList();

        return CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final challenge = challenges[index];
                  final isCompleted = completedChallengeIds.contains(challenge.id);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: isCompleted ? Colors.green.shade50 : Colors.white.withOpacity(0.95),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MissionDetailPage(challenge: challenge),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          challenge.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            challenge.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        trailing: isCompleted
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 40,
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Colors.grey,
                                size: 32,
                              ),
                      ),
                    ),
                  );
                },
                childCount: challenges.length,
              ),
            ),
            // 下部に余白を追加
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        );
      },
    );
  }
}

void _showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'チャレンジミッション',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
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
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF13547a),
          ),
          child: const Text('閉じる', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}