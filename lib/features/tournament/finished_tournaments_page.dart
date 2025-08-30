import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/tournament_model.dart';
import '../tournament/tournament_result_page.dart';

// Providerの定義（変更なし）
final finishedTournamentsProvider = StreamProvider.autoDispose<List<Tournament>>((ref) {
  return FirebaseFirestore.instance
      .collection('tournaments')
      .where('status', isEqualTo: 'finished')
      .orderBy('endDate', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList());
});

class FinishedTournamentsPage extends ConsumerWidget {
  const FinishedTournamentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTournaments = ref.watch(finishedTournamentsProvider);

    return Scaffold(
      // 背景をAppBarの後ろまで広げる
      extendBodyBehindAppBar: true,
      body: Container(
        // 全画面にグラデーション背景を適用
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
                      const Expanded(
                        child: Text(
                          '終了した大会',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13547a),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // 右側のスペース確保用
                    ],
                  ),
                ),
              ),
              // 大会リストの表示
              asyncTournaments.when(
                data: (tournaments) {
                  if (tournaments.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Text('終了した大会はありません。', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _FinishedTournamentCard(tournament: tournaments[index]);
                        },
                        childCount: tournaments.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.white))),
                error: (err, stack) => SliverFillRemaining(child: Center(child: Text('エラー: $err', style: const TextStyle(color: Colors.white)))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 新しいモダンなカードウィジェット
class _FinishedTournamentCard extends StatelessWidget {
  final Tournament tournament;
  const _FinishedTournamentCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        // 光沢のある銀色の枠線
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade500, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.0), // 枠線の太さ
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => TournamentResultPage(
                tournamentId: tournament.id,
                tournamentName: tournament.name,
              ),
            ));
          },
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.8, // 少し横長に
                      child: CachedNetworkImage(
                        imageUrl: tournament.bannerUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
                    // バナー画像の上に半透明の黒いオーバーレイ
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ),
                    // 「終了」バッジ
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Chip(
                        avatar: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                        label: const Text('終了', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            '${DateFormat('yyyy年M月d日').format(tournament.endDate)} 終了',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const Spacer(),
                          const Row(
                            children: [
                              Text('結果を見る', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}