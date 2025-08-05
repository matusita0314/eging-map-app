import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart'; //
import 'package:cloud_firestore/cloud_firestore.dart'; //
import '../../models/tournament_model.dart';
import 'tournament_dashboard.dart';
import 'tournament_terms_page.dart';

class TournamentLpPage extends StatefulWidget {
  final Tournament tournament;
  const TournamentLpPage({super.key, required this.tournament});

  @override
  State<TournamentLpPage> createState() => _TournamentLpPageState();
}

class _TournamentLpPageState extends State<TournamentLpPage> {
  String? _userRank;
  bool _isLoading = true;
  bool _isEligible = false;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  // ユーザーのランクを取得し、参加資格を判定する
  Future<void> _checkEligibility() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() { _isLoading = false; });
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    if (mounted && userDoc.exists) {
      final rank = userDoc.data()?['rank'] as String? ?? 'beginner';
      final requiredRank = widget.tournament.eligibleRank;

      setState(() {
        _userRank = rank;
        // 参加資格ランクが設定されていない(null)か、ユーザーのランクと一致すれば参加可能
        _isEligible = (requiredRank == null || requiredRank == rank);
        _isLoading = false;
      });
    } else {
       setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.tournament.name, style: const TextStyle(shadows: [Shadow(blurRadius: 8)])),
              background: CachedNetworkImage(
                imageUrl: widget.tournament.bannerUrl,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.4),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.tournament.eligibleRank != null)
                    Card(
                      color: _isEligible ? Colors.green.shade50 : Colors.red.shade50,
                      child: ListTile(
                        leading: Icon(
                          _isEligible ? Icons.check_circle : Icons.cancel,
                          color: _isEligible ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          '参加資格: ${widget.tournament.eligibleRank?.toUpperCase()}ランク',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_isEligible
                            ? 'あなたはこの大会に参加できます！'
                            : 'あなたは現在$_userRankランクです！'),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  const Text('大会ルール', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('ここに大会の詳細なルールが表示されます...'),
                  const SizedBox(height: 200), // ダミーのスペース

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: _isEligible ? Colors.blue : Colors.grey, // 資格がなければ灰色に
                      foregroundColor: Colors.white,
                    ),
                    // 資格がない場合 or ロード中はボタンを押せなくする
                    onPressed: (_isEligible && !_isLoading) ? () async {
                      final bool? didEnter =
                          await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => TournamentTermsPage(tournamentId: widget.tournament.id),
                        ),
                      );

                      if (didEnter == true && context.mounted) {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (context) => TournamentDashboardPage(tournamentId: widget.tournament.id),
                        ));
                      }
                    } : null,
                    child: Text(
                      _isLoading
                          ? '資格を確認中...'
                          : (_isEligible ? 'エントリーする！' : '参加資格がありません'),
                      style: const TextStyle(fontSize: 18)
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}