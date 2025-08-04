import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/tournament_model.dart';
import 'tournament_dashboard.dart'; 
import 'tournament_terms_page.dart';

class TournamentLpPage extends StatelessWidget {
  final Tournament tournament;
  const TournamentLpPage({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(tournament.name, style: const TextStyle(shadows: [Shadow(blurRadius: 8)])),
              background: CachedNetworkImage(
                imageUrl: tournament.bannerUrl,
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
                  const Text('大会ルール', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('ここに大会の詳細なルールが表示されます...'),
                  const SizedBox(height: 200), // ダミーのスペース
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      // 規約ページにプッシュし、エントリーが成功したか(true)を待つ
                      final bool? didEnter =
                          await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) =>
                              TournamentTermsPage(tournamentId: tournament.id),
                        ),
                      );

                      // エントリーに成功した場合のみダッシュボードへ遷移
                      if (didEnter == true && context.mounted) {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (context) => TournamentDashboardPage(
                              tournamentId: tournament.id),
                        ));
                      }
                    },
                    child: const Text('エントリーする！', style: TextStyle(fontSize: 18)),
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