import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

final tournamentRankingProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, tournamentId) {
  return FirebaseFirestore.instance
      .collection('tournaments')
      .doc(tournamentId)
      .collection('rankings')
      .orderBy('rank')
      .limit(100)
      .snapshots();
});

class TournamentResultPage extends ConsumerWidget {
  final String tournamentId;
  final String tournamentName;

  const TournamentResultPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(tournamentRankingProvider(tournamentId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF13547a), Color(0xFF80d0c7)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // フローティング風ヘッダー
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 15, 16, 16),
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF13547a)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          tournamentName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13547a),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              // ランキングリスト
              rankingAsync.when(
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.white))),
                error: (err, stack) => SliverFillRemaining(child: Center(child: Text("エラー: $err", style: const TextStyle(color: Colors.white)))),
                data: (snapshot) {
                  if (snapshot.docs.isEmpty) {
                    return const SliverFillRemaining(child: Center(child: Text("ランキングデータがありません。", style: TextStyle(color: Colors.white))));
                  }
                  final rankings = snapshot.docs;
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final rankData = rankings[index].data() as Map<String, dynamic>;
                          return _RankingTile(rankData: rankData);
                        },
                        childCount: rankings.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 新しいモダンなランキングタイルウィジェット
class _RankingTile extends StatelessWidget {
  final Map<String, dynamic> rankData;
  const _RankingTile({required this.rankData});

  @override
  Widget build(BuildContext context) {
    final rank = rankData['rank'] ?? 0;
    final userName = rankData['userName'] ?? '名無しさん';
    final userPhotoUrl = rankData['userPhotoUrl'] as String?;
    final score = rankData['score'] ?? 0;

    Color medalColor;
    IconData medalIcon;
    switch (rank) {
      case 1:
        medalColor = Colors.amber;
        medalIcon = Icons.emoji_events;
        break;
      case 2:
        medalColor = Colors.grey.shade400;
        medalIcon = Icons.emoji_events;
        break;
      case 3:
        medalColor = const Color(0xFFCD7F32); // Bronze
        medalIcon = Icons.emoji_events;
        break;
      default:
        medalColor = Colors.transparent;
        medalIcon = Icons.military_tech; // Placeholder icon
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: rank <= 3 ? medalColor : Colors.white.withOpacity(0.5),
          width: rank <= 3 ? 2.0 : 1.0,
        ),
      ),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (rank <= 3)
              Icon(medalIcon, color: medalColor, size: 28)
            else
              Text(
                '${rank}位',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
          ],
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: userPhotoUrl != null && userPhotoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(userPhotoUrl)
                  : null,
              child: (userPhotoUrl == null || userPhotoUrl.isEmpty)
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Text(
          '$score pt',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: rank <= 3 ? medalColor : Colors.deepOrange,
          ),
        ),
      ),
    );
  }
}