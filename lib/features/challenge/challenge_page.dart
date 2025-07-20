import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'mission_detail_page.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/challenge_model.dart';

// --- メインのUI ---
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
      appBar: CommonAppBar(
        title: const Text('チャレンジミッション'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'チャレンジミッションとは？',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _ranks.map((rank) => Tab(text: rank.toUpperCase())).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _ranks.map((rank) => _MissionList(rank: rank)).toList(),
      ),
    );
  }
}

class _MissionList extends StatelessWidget {
  final String rank;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  _MissionList({required this.rank});

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('ログインが必要です。'));
    }

    // 2つのStreamを結合する
    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.combine2(
        FirebaseFirestore.instance
            .collection('challenges')
            .where('rank', isEqualTo: rank)
            .snapshots(),
        // ユーザーがクリアしたチャレンジを取得
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('エラーが発生しました'));
        }
        // ★★★本来の実装★★★
        // 絞り込まれた結果、データがなければメッセージを表示
        if (!snapshot.hasData || snapshot.data![0].docs.isEmpty) {
          return const Center(child: Text('このランクのミッションはありません。'));
        }

        final allChallengesDocs = snapshot.data![0].docs;
        final completedChallengesDocs = snapshot.data![1].docs;

        final completedChallengeIds = completedChallengesDocs
            .map((doc) => doc.id)
            .toSet();

        final challenges = allChallengesDocs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            final isCompleted = completedChallengeIds.contains(challenge.id);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              color: isCompleted ? Colors.green.shade50 : null,
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // MissionDetailPage に challenge オブジェクトを渡す
                      builder: (context) =>
                          MissionDetailPage(challenge: challenge),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  challenge.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(challenge.description),
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
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

void _showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('チャレンジミッションとは？'),
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
          child: const Text('閉じる'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
