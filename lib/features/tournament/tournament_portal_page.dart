import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/tournament_model.dart';
import 'tournament_lp_page.dart';
import 'tournament_dashboard.dart';

class TournamentPortalPage extends StatelessWidget {
  const TournamentPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大会'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade900, // 背景をダークに
      body: StreamBuilder<QuerySnapshot>(
        // 終了日が未来の大会のみを取得
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .where('endDate', isGreaterThan: Timestamp.now())
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '現在開催中の大会はありません。',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final tournaments = snapshot.data!.docs
              .map((doc) => Tournament.fromFirestore(doc))
              .toList();

          return TournamentCarousel(tournaments: tournaments);
        },
      ),
    );
  }
}

class TournamentCarousel extends StatefulWidget {
  final List<Tournament> tournaments;
  const TournamentCarousel({super.key, required this.tournaments});

  @override
  State<TournamentCarousel> createState() => _TournamentCarouselState();
}

class _TournamentCarouselState extends State<TournamentCarousel> {
  // viewportFractionで左右のカードを少し見せる
  final PageController _pageController = PageController(viewportFraction: 0.75);
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page != null) {
        setState(() {
          _currentPage = _pageController.page!;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.tournaments.length,
      itemBuilder: (context, index) {
        // 現在ページと表示中カードのインデックスの差を計算
        final double difference = index - _currentPage;

        // 3D回転のための角度を計算 (中央から離れるほど回転)
        final double rotation = difference * -0.4;
        
        // 中央から離れるほど小さくする
        final double scale = 1 - (difference.abs() * 0.2);

        return GestureDetector(
          onTap: () async {
            final tournament = widget.tournaments[index];
            final currentUser = FirebaseAuth.instance.currentUser;

            if (currentUser == null) {
              // 必要に応じてログインを促すメッセージなどを表示
              return;
            }
            
            // エントリー済みか確認
            final entryDoc = await FirebaseFirestore.instance
                .collection('tournaments')
                .doc(tournament.id)
                .collection('entries')
                .doc(currentUser.uid)
                .get();

            if (context.mounted) {
              if (entryDoc.exists) {
                // エントリー済みなら直接ダッシュボードへ
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      TournamentDashboardPage(tournamentId: tournament.id),
                ));
              } else {
                // 未エントリーならLPページへ
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => TournamentLpPage(
                    tournament: tournament,
                  ),
                ));
              }
            }
          },
          child: Transform(
            alignment: Alignment.center,
            // ここが3Dに見せるためのキモ！
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // パース効果
              ..rotateY(rotation),   // Y軸回転
            child: Transform.scale(
              scale: scale,
              child: TournamentCard(tournament: widget.tournaments[index]),
            ),
          ),
        );
      },
    );
  }
}

class TournamentCard extends StatelessWidget {
  final Tournament tournament;
  const TournamentCard({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // バナー画像
          CachedNetworkImage(
            imageUrl: tournament.bannerUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey.shade700),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
          // タイトルが見やすいようにグラデーションを重ねる
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.5, 1.0],
              ),
            ),
          ),
          // 大会タイトル
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Text(
              tournament.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 10, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}