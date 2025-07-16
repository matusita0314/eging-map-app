// lib/pages/tournament_dashboard_page.dart (実装版)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_tournament_post_page.dart'; // 後で作成

class TournamentDashboardPage extends StatefulWidget {
  final String tournamentId;
  const TournamentDashboardPage({super.key, required this.tournamentId});

  @override
  State<TournamentDashboardPage> createState() =>
      _TournamentDashboardPageState();
}

class _TournamentDashboardPageState extends State<TournamentDashboardPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  Timer? _timer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    _fetchTournamentEndDate();
  }

  @override
  void dispose() {
    _timer?.cancel(); // ページが閉じられたらタイマーを停止
    super.dispose();
  }

  // 大会の終了日時を取得してタイマーを開始する
  Future<void> _fetchTournamentEndDate() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();

    if (mounted && doc.exists) {
      final data = doc.data()!;
      final endDate = (data['endDate'] as Timestamp).toDate();

      // 1秒ごとに残り時間を更新するタイマーを開始
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        if (now.isBefore(endDate)) {
          setState(() {
            _remainingTime = endDate.difference(now);
          });
        } else {
          setState(() {
            _remainingTime = Duration.zero;
          });
          _timer?.cancel();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.tournamentId} 大会')),
      body: Column(
        children: [
          _buildMyRank(), // 自分の戦績
          const Divider(),
          _buildCountdownTimer(), // 残り時間タイマー
          const Divider(),
          const Text(
            'ランキング',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(child: _buildRankingList()), // ランキング一覧
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 大会用投稿ページへ遷移
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AddTournamentPostPage(tournamentId: widget.tournamentId),
            ),
          );
        },
        label: const Text('釣果を提出する'),
        icon: const Icon(Icons.add_photo_alternate),
        backgroundColor: Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // 残り時間タイマーのUI
  Widget _buildCountdownTimer() {
    if (_remainingTime == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('残り時間を計算中...'),
      );
    }
    if (_remainingTime!.isNegative) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '大会は終了しました',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    final days = _remainingTime!.inDays;
    final hours = _remainingTime!.inHours.remainder(24);
    final minutes = _remainingTime!.inMinutes.remainder(60);
    final seconds = _remainingTime!.inSeconds.remainder(60);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        '残り ${days}日 ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  // 自分の戦績を表示するUI
  Widget _buildMyRank() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('rankings')
          .doc(_currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ListTile(
            title: Text('あなたの戦績'),
            subtitle: Text('まだ釣果がありません。'),
          );
        }
        final myRankData = snapshot.data!.data() as Map<String, dynamic>;
        // 注: ここでは順位の数字は表示していません。表示するにはCloud Functionsでの集計が推奨されます。
        return ListTile(
          tileColor: Colors.blue.withOpacity(0.1),
          leading: const Icon(Icons.person, color: Colors.blue),
          title: Text('あなたのスコア: ${myRankData['totalScore'] ?? 0} pt'),
          subtitle: Text(
            '最大サイズ: ${myRankData['maxSize'] ?? 0} cm / ${myRankData['catchCount'] ?? 0} 杯',
          ),
        );
      },
    );
  }

  // ランキング一覧を表示するUI
  Widget _buildRankingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('rankings')
          .orderBy('totalScore', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('まだランキングデータがありません。'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final rankData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final rank = index + 1;

            return ListTile(
              leading: Text(
                '$rank位',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(rankData['userName'] ?? '名無しさん'),
              subtitle: Text(
                '最大: ${rankData['maxSize'] ?? 0} cm / ${rankData['catchCount'] ?? 0} 杯',
              ),
              trailing: Text(
                '${rankData['totalScore'] ?? 0} pt',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
