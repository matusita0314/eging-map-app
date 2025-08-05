import 'package:intl/intl.dart';
import '../../providers/liked_tournament_posts_provider.dart';
import 'package:egingapp/models/tournament_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './tournament_post_detail_page.dart';
import 'add_tournament_post_page.dart';
import 'tournament_user_submissions_page.dart';
import '../account/account.dart';
import '../../providers/following_provider.dart';

final tournamentSortProvider = StateProvider<String>((ref) => 'createdAt');

class TournamentDashboardPage extends StatefulWidget {
  final String tournamentId;
  const TournamentDashboardPage({super.key, required this.tournamentId});

  @override
  State<TournamentDashboardPage> createState() => _TournamentDashboardPageState();
}

class _TournamentDashboardPageState extends State<TournamentDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Tournament? _tournament;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTournamentData();
  }
    Future<void> _fetchTournamentData() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments').doc(widget.tournamentId).get();
    if (doc.exists && mounted) {
      setState(() {
        _tournament = Tournament.fromFirestore(doc);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tournament == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${_tournament!.name}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'マイページ'),
            Tab(icon: Icon(Icons.emoji_events), text: 'ランキング'),
            Tab(icon: Icon(Icons.groups), text: 'みんなの投稿'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyStatusTab(tournament: _tournament!),
          _RankingsTab(tournament: _tournament!),
          _TimelineTab(tournament: _tournament!),
        ],
      ),
    );
  }
}


class _MyStatusTab extends StatelessWidget {
  final Tournament tournament;
  const _MyStatusTab({required this.tournament});

  Widget _buildLikeStatusCard(BuildContext context, Map<String, dynamic> myEntryData) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final rank = myEntryData['currentRank'] as int?;

    // ユーザーの承認済み投稿をリアルタイムで監視するStream
    final userPostsStream = FirebaseFirestore.instance
        .collection('tournaments').doc(tournament.id)
        .collection('posts')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'approved')
        .snapshots();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Colors.pink, size: 36),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rank != null ? 'あなたの現在の順位は $rank 位です' : 'あなたの順位は集計中です',
                    style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,color: Colors.pink.shade800,),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: userPostsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                int totalLikes = 0;
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalLikes += (data['likeCount'] as int? ?? 0);
                }
                
                return Text(
                  '合計 $totalLikes いいね',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade800,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- ▼▼▼【追加】メイン大会用のステータスカード（既存のUI） ▼▼▼ ---
  Widget _buildRankStatusCard(Map<String, dynamic> myEntryData) {
    final rank = myEntryData['currentRank'] as int?;
    final score = myEntryData['currentScore'];
    final metricUnit = tournament.rule.metric == 'SIZE' ? 'cm' : '匹';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rank != null ? 'あなたの順位は$rank位です ！' : 'あなたの順位は集計中です',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'あなたのスコア: ${score ?? 0} $metricUnit',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final metricUnit = tournament.rule.metric == 'SIZE'
        ? 'cm'
        : (tournament.rule.metric == 'COUNT' ? '匹' : 'いいね');
    final Query postsQuery = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournament.id)
        .collection('posts')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['pending', 'approved'])
        .orderBy('createdAt', descending: true);


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tournaments').doc(tournament.id)
                .collection('entries').doc(currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ListTile(
                      title: Text('投稿して参戦しましょう！！'),
                    ),
                  ),
                );
              }

              final myEntryData = snapshot.data!.data() as Map<String, dynamic>;
              
              if (tournament.rule.metric == 'LIKE_COUNT') {
                return _buildLikeStatusCard(context,myEntryData);
              } else {
                return _buildRankStatusCard(myEntryData);
              }
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_a_photo),
            label: const Text('釣果/作品を提出する'),
            onPressed: () async {
              final postsQuery = await FirebaseFirestore.instance
                  .collection('tournaments').doc(tournament.id).collection('posts')
                  .where('userId', isEqualTo: currentUser.uid)
                  .where('status', whereIn: ['pending', 'approved'])
                  .limit(1)
                  .get();

              bool alreadySubmitted = postsQuery.docs.isNotEmpty;
              bool proceed = true;

              // ★ 2. もし投稿済みなら、アラートを表示
              if (alreadySubmitted &&
                  tournament.rule.submissionLimit == 'SINGLE_OVERWRITE' &&
                  context.mounted) {
                proceed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('投稿の更新'),
                    content: const Text(
                        '既に提出済みの投稿があります。新しい投稿が現在の記録を上回った場合、古い投稿は削除され、新しい記録に更新されます。よろしいですか？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('キャンセル')),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('OK')),
                    ],
                  ),
                ) ??
                false;
              }

              // ★ 3. OKが押された場合のみ、投稿ページへ
              if (proceed && context.mounted) {
                final doc = await FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).get();
                if (doc.exists && context.mounted) {
                  final tournament = Tournament.fromFirestore(doc);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TournamentSubmissionPage(tournament: tournament),
                  ));
                }
              }
            },
          ),
          const Divider(height: 48),
          const Text('あなたが提出した投稿', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: postsQuery.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('まだ投稿がありません。'));
              }
              final postDocs = snapshot.data!.docs;
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: postDocs.length,
                itemBuilder: (context, index) {
                  final postDoc = postDocs[index];
                  final postData = postDoc.data() as Map<String, dynamic>;
                  final status = postData['status'] as String? ?? 'pending';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Stack(
                      children: [
                        _TournamentFeedCard(
                          tournament: tournament,
                          post: postDoc,
                          showAuthorInfo: false,
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _buildStatusChip(status),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankingsTab extends StatelessWidget {
  final Tournament tournament;
  const _RankingsTab({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournament.id)
          .collection('rankings')
          .where('rank', isNotEqualTo: null) // rankフィールドが存在するドキュメントのみ取得
          .orderBy('rank') // rank(順位)の昇順で並び替え
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('エラーが発生しました'));
        }

        final rankings = snapshot.data?.docs ?? [];
        final top3 = rankings.take(3).toList();

        return SingleChildScrollView(
          child: Column(
            children: [
              _PodiumWidget(top3: top3, tournament: tournament),
              const Divider(),
              if (rankings.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text("ランキング集計ボタンが押されるまで、\nランキングは表示されません。", textAlign: TextAlign.center)),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rankings.length,
                itemBuilder: (context, index) {
                  final doc = rankings[index];
                  final rankData = doc.data() as Map<String, dynamic>;
                  final rank = rankData['rank'] as int;
                  final metricUnit = tournament.rule.metric == 'SIZE'
          ? 'cm'
          : (tournament.rule.metric == 'COUNT' ? '匹' : 'いいね');
                  
                  return _RankingTile(
                    rank: rank,
                    data: rankData,
                    tournament: tournament,
                    metricUnit: metricUnit,
                     onTap: () {
                      if (tournament.rule.submissionLimit == 'SINGLE_OVERWRITE') {
                        final postId = rankData['maxSizePostId'] as String?;
                        if (postId != null) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => TournamentPostDetailPage(
                              tournament: tournament,
                              tournamentId: tournament.id,
                              postId: postId,
                            ),
                          ));
                        }
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TournamentUserSubmissionsPage(
                            tournament: tournament,
                            tournamentId: tournament.id,
                            userId: doc.id,
                            userName: rankData['userName'] ?? '名無しさん',
                          ),
                        ));
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
// --- 表彰台ウィジェット（枠表示対応版） ---
class _PodiumWidget extends StatelessWidget {
  final List<QueryDocumentSnapshot> top3;
  final Tournament tournament;
  const _PodiumWidget({required this.top3, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final doc1 = top3.isNotEmpty ? top3[0] : null;
    final doc2 = top3.length > 1 ? top3[1] : null;
    final doc3 = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PodiumProfile(doc: doc2, rank: 2, height: 120, tournament: tournament),
          const SizedBox(width: 16),
          _PodiumProfile(doc: doc1, rank: 1, height: 160, tournament: tournament),
          const SizedBox(width: 16),
          _PodiumProfile(doc: doc3, rank: 3, height: 100, tournament: tournament),
        ],
      ),
    );
  }
}


class _PodiumProfile extends StatelessWidget {
  final QueryDocumentSnapshot? doc;
  final Tournament tournament;
  final int rank;
  final double height;
  

  const _PodiumProfile({
    this.doc,
    required this.tournament,
    required this.rank,
    required this.height
  });

  @override
  Widget build(BuildContext context) {
    final data = doc?.data() as Map<String, dynamic>?;
    final userId = doc?.id;
    final metricUnit = tournament.rule.metric == 'SIZE'
        ? 'cm'
        : (tournament.rule.metric == 'COUNT' ? '匹' : 'いいね');

    
    Color medalColor;
    switch (rank) {
      case 1: medalColor = Colors.amber; break;
      case 2: medalColor = Colors.grey.shade400; break;
      default: medalColor = const Color(0xFFCD7F32);
    }
    
    // データがある場合のみGestureDetectorを有効にする
    return GestureDetector(
      onTap: (userId != null && data != null) ? () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => TournamentUserSubmissionsPage(
            tournament: tournament,
            tournamentId: tournament.id,
            userId: userId,
            userName: data['userName'] ?? '',
          ),
        ));
      } : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // データがない場合はプレースホルダーを表示
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: (data?['userPhotoUrl'] != null && data!['userPhotoUrl'].isNotEmpty)
                ? CachedNetworkImageProvider(data['userPhotoUrl'])
                : null,
            child: (data?['userPhotoUrl'] == null || data!['userPhotoUrl'].isEmpty)
                ? Icon(Icons.person, color: Colors.grey.shade600)
                : null,
          ),
          const SizedBox(height: 4),
          Text(data?['userName'] ?? '--------', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(data != null ? '${data['score'] ?? 0} ${metricUnit}' : '---', style: TextStyle(fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 172, 165, 36))),
          const SizedBox(height: 8),

          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border(top: BorderSide(color: medalColor, width: 5)),
            ),
            child: Center(child: Text('$rank', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final Tournament tournament;
  final VoidCallback onTap;

  const _RankingTile({required this.rank, required this.data, required this.metricUnit, required this.onTap, required this.tournament});
  final String metricUnit;

  @override
  Widget build(BuildContext context) {
    final metricUnit = tournament.rule.metric == 'SIZE'
        ? 'cm'
        : (tournament.rule.metric == 'COUNT' ? '匹' : 'いいね');
    return ListTile(
      onTap: onTap,
      leading: Text('$rank位', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      title: Text(data['userName'] ?? '名無しさん'),
      trailing: Text('${data['score'] ?? 0} $metricUnit', style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 172, 165, 36), fontWeight: FontWeight.bold)),
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  final Tournament tournament;
  const _TimelineTab({required this.tournament});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortBy = ref.watch(tournamentSortProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Wrap(
            spacing: 8.0,
            alignment: WrapAlignment.center,
            children: tournament.rule.timelineSortOptions.map((option) {
              String label;
              switch (option) {
                case 'judgedSize': label = 'サイズ順'; break;
                case 'judgedCount': label = '匹数順'; break;
                case 'likeCount': label = 'いいね数順'; break;
                default: label = '新着順';
              }
              return ChoiceChip(
                label: Text(label),
                selected: sortBy == option,
                onSelected: (selected) {
                  if (selected) ref.read(tournamentSortProvider.notifier).state = option;
                },
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tournaments')
                .doc(tournament.id)
                .collection('posts')
                .where('status', isEqualTo: 'approved')
                .orderBy(sortBy, descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _TournamentFeedCard(
                    tournament: tournament,
                    post: post,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


class _TournamentFeedCard extends ConsumerWidget {
  final Tournament tournament;
  final DocumentSnapshot post;
  final bool showAuthorInfo;

  const _TournamentFeedCard({
    required this.tournament,
    required this.post,
    this.showAuthorInfo = true,
  });

   Widget _buildStyledScoreDisplay(
      Map<String, dynamic> postData, Tournament tournament) {
    // いいね数を競う大会の場合
    if (tournament.rule.metric == 'LIKE_COUNT') {
      final likeCount = postData['likeCount'] ?? 0;
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.pink.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: Colors.pink, size: 22),
              const SizedBox(width: 10),
              Text(
                '$likeCount いいね',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // 【分岐】それ以外（メイン大会）の場合
    else {
      final squidType = postData['squidType'] as String? ?? '釣果';
      String scoreText = '';
      final metricUnit =
          tournament.rule.metric == 'SIZE' ? 'cm' : '匹';

      if (tournament.rule.metric == 'SIZE') {
        final judgedSize = postData['judgedSize'] as num?;
        if (judgedSize != null) {
          scoreText = 'サイズ: $judgedSize $metricUnit';
        }
      } else if (tournament.rule.metric == 'COUNT') {
        final judgedCount = postData['judgedCount'] as num?;
        if (judgedCount != null) {
          scoreText = '匹数: $judgedCount $metricUnit';
        }
      }

      final displayText = '$squidType $scoreText'.trim();

      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.military_tech_outlined,
                  color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postData = post.data() as Map<String, dynamic>;
    final postId = post.id;
    final currentUser = FirebaseAuth.instance.currentUser!;
    final dynamic imageUrlsData = postData['imageUrls'] ?? postData['imageUrl'];
    List<String> imageUrls = List<String>.from(imageUrlsData);
    if (imageUrlsData is List) {
      // 新しいデータ形式 (List<dynamic>) の場合
      imageUrls = List<String>.from(imageUrlsData.map((e) => e.toString()));
    } else if (imageUrlsData is String) {
      // 古いデータ形式 (String) の場合
      imageUrls = [imageUrlsData];
    }

    // 必要なデータを安全に抽出
    final userName = postData['userName'] as String? ?? '名無しさん';
    final userPhotoUrl = postData['userPhotoUrl'] as String?;
    final userId = postData['userId'] as String;
    final judgedSize = postData['judgedSize'] as num?;
    final squidType = postData['squidType'] as String?;
    final createdAt = (postData['createdAt'] as Timestamp).toDate();
    final likeCount = postData['likeCount'] ?? 0;
    final commentCount = postData['commentCount'] ?? 0;
    final judgedCount = postData['judgedCount'] as num?;
    final pageController = PageController();


    // いいね状態をリアルタイムで監視
    final isLikedStream = FirebaseFirestore.instance
        .collection('tournaments').doc(tournament.id)
        .collection('posts').doc(postId)
        .collection('likes').doc(currentUser.uid)
        .snapshots();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ユーザー情報ヘッダー ---
          if (showAuthorInfo)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => MyPage(userId: userId))
                  ),
                  child: Row(
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
                      const SizedBox(width: 8),
                      Text(userName, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Color.fromARGB(255, 45, 210, 48)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy年M月d日').format(createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // --- 投稿画像 ---
          if (imageUrls.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => TournamentPostDetailPage(
                        tournament: tournament,
                        tournamentId: tournament.id,
                        postId: postId,
                      ))),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      controller: pageController,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: imageUrls[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                        );
                      },
                    ),
                    // 複数枚ある場合のみインジケータを表示
                    if (imageUrls.length > 1)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SmoothPageIndicator(
                          controller: pageController,
                          count: imageUrls.length,
                          effect: ScrollingDotsEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // --- 釣果情報 ---
          Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!showAuthorInfo)
                  _buildStyledScoreDisplay(postData, tournament)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       if (tournament.rule.metric == 'SIZE' && judgedSize != null)
                          Text('サイズ: $judgedSize cm', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       if (tournament.rule.metric == 'COUNT' && judgedCount != null)
                          Text('匹数: $judgedCount 匹', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       if (squidType != null) Text('種類: $squidType'),
                    ],
                  ),
            ],
          ),
        ),


          // --- アクションボタン ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // いいねボタン
                StreamBuilder<DocumentSnapshot>(
                  stream: isLikedStream,
                  builder: (context, snapshot) {
                    final isLiked = snapshot.hasData && snapshot.data!.exists;
                    return Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey
                          ),
                          onPressed: () => ref.read(likedTournamentPostsNotifierProvider.notifier)
                            .handleLike(tournament.id, postId),
                        ),
                        Text('$likeCount'),
                      ],
                    );
                  }
                ),
                const SizedBox(width: 16),
                // コメントボタン
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => TournamentPostDetailPage(
                          tournament: tournament,
                          tournamentId: tournament.id,
                          postId: postId,
                          scrollToComments: true,
                        ),
                      )),
                    ),
                    Text('$commentCount'),
                  ],
                ),
                const SizedBox(width: 100),
                // フォローボタン
                if (showAuthorInfo && userId != currentUser.uid)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('following')
                        .doc(userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final isFollowing = snapshot.hasData && snapshot.data!.exists;
                      return ElevatedButton(
                        onPressed: () {
                              ref
                                  .read(followingNotifierProvider.notifier)
                                  .handleFollow(userId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? Colors.white
                                  : Colors.blue,
                              foregroundColor: isFollowing
                                  ? Colors.blue
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: Colors.blue.withOpacity(0.5),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 30),
                            ),
                            child: Text(
                              isFollowing ? 'フォロー中' : '+ フォロー',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }
}

Widget _buildStatusChip(String status) {
  Color chipColor;
  String label;
  IconData icon;

  switch (status) {
    case 'approved':
      chipColor = Colors.green;
      label = '承認済み';
      icon = Icons.check_circle;
      break;
    case 'pending':
      chipColor = Colors.orange;
      label = '判定待ち';
      icon = Icons.hourglass_top;
      break;
    default: // 'rejected' などの他のステータスも想定
      chipColor = Colors.red;
      label = '却下';
      icon = Icons.cancel;
      break;
  }

  return Chip(
    avatar: Icon(icon, color: Colors.white, size: 16),
    label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    backgroundColor: chipColor,
    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
  );
}
