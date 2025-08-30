import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'finished_tournaments_page.dart';

import '../../models/tournament_model.dart';
import 'lp_webview_page.dart';
import 'tournament_dashboard.dart';
import 'tournament_lp_page.dart';

enum TournamentRankFilter { beginner, amateur, pro }

final tournamentsProvider = StreamProvider.autoDispose.family<List<Tournament>, TournamentRankFilter>((ref, rankFilter) {
  final db = FirebaseFirestore.instance;
  final rankString = rankFilter.toString().split('.').last;

    final query = db.collection('tournaments')
      .where('status', whereIn: ['pending', 'ongoing', 'judging']) // 'judging'を追加
      .where('eligibleRank', whereIn: [rankString, 'common']);

  return query.snapshots().map((snapshot) {
    final tournaments = snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList();

    tournaments.sort((a, b) {
      // ステータスに優先度をつけます (開催中: 0, 結果集計中: 1, 開催予定: 2)
      int getStatusOrder(String? status) {
        switch (status) {
          case 'ongoing': return 0;
          case 'judging': return 1;
          case 'pending': return 2;
          default: return 3;
        }
      }

      final statusOrderA = getStatusOrder(a.status);
      final statusOrderB = getStatusOrder(b.status);

      // 1. まずステータスで比較
      int compare = statusOrderA.compareTo(statusOrderB);
      if (compare != 0) {
        return compare;
      }

      // 2. ステータスが同じなら、displayOrderで比較
      final orderA = a.displayOrder ?? 999;
      final orderB = b.displayOrder ?? 999;
      compare = orderA.compareTo(orderB);
      if (compare != 0) {
        return compare;
      }

      // 3. displayOrderも同じなら、終了日で比較
      return a.endDate.compareTo(b.endDate);
    });
    
    return tournaments;
  });
});


// 3. StatefulWidgetとTabControllerを3タブ構成に変更
class TournamentPortalPage extends ConsumerStatefulWidget {
  const TournamentPortalPage({super.key});
  @override
  ConsumerState<TournamentPortalPage> createState() => _TournamentPortalPageState();
}

class _TournamentPortalPageState extends ConsumerState<TournamentPortalPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _tabs = ['ビギナー', 'アマチュア', 'プロ']; // ★タブを3つに変更

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this); // ★長さを3に変更
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
            colors: [Color(0xFF13547a), Color(0xFF80d0c7)],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        const Expanded(child: Text('大会', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13547a)))),
                        IconButton(icon: const Icon(Icons.help_outline, color: Color(0xFF13547a)), tooltip: '大会の利用規約', onPressed: () => _showTermsDialog(context)),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: Container(
                      // ★ 1. 左右の余白を調整
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        // ★ 2. 背景色を半透明の白に変更し、影を追加
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
                          // ★ 3. インジケーターの内側に余白を追加
                          indicatorPadding: const EdgeInsets.all(4),
                          labelColor: Colors.white,
                          // ★ 4. 未選択タブの文字色を変更
                          unselectedLabelColor: const Color(0xFF13547a),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          tabs: _tabs.map((tabName) => Tab(text: tabName)).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView( // ★TabBarViewを3タブ構成に変更
              controller: _tabController,
              children: [
                _buildTournamentList(TournamentRankFilter.beginner),
                _buildTournamentList(TournamentRankFilter.amateur),
                _buildTournamentList(TournamentRankFilter.pro),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTournamentList(TournamentRankFilter rankFilter) {
    final tournamentsAsync = ref.watch(tournamentsProvider(rankFilter));
    return tournamentsAsync.when(
      data: (tournaments) {
        if (tournaments.isEmpty) {
          return const Center(child: Text('現在開催中の大会はありません。', style: TextStyle(color: Colors.white, fontSize: 16)));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          itemCount: tournaments.length + 1,
          itemBuilder: (context, index) {
            if (index == tournaments.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text(
                    '過去の大会結果を見る',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const FinishedTournamentsPage(),
                    ));
                  },
                ),
              );
            }
            return _TournamentCard(tournament: tournaments[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (err, stack) => Center(child: Text('エラー: $err', style: const TextStyle(color: Colors.white))),
    );
  }
}

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
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return true;
  }
}


class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  const _TournamentCard({required this.tournament});

  String _getMetricDisplayName(String metric) {
    switch (metric) {
      case 'SIZE': return 'サイズ';
      case 'COUNT': return '匹数';
      case 'LIKE_COUNT': return 'いいね数';
      default: return '総合';
    }
  }

  ({Color color, String text}) _getRankStyle(String? rank) {
    switch (rank) {
      case 'amateur':
        return (color: const Color.fromARGB(255, 210, 84, 25), text: 'アマチュア');
      case 'pro':
        return (color: const Color.fromARGB(255, 255, 60, 60), text: 'プロ');
      case 'beginner':
        return (color: const Color.fromARGB(255, 0, 163, 19), text: 'ビギナー');
      default: // ★ランクがnull（共通）の場合のスタイル
        return (color: Color.fromARGB(255, 105, 103, 0).withOpacity(0.6), text: '全員');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMainTournament = tournament.name.contains("サイズコンテスト") || tournament.name.contains("ナンバーコンテスト");
    final Gradient? borderGradient = isMainTournament
        ? LinearGradient(colors: [Colors.amber.shade200, Colors.amber.shade600, Colors.amber.shade200], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade500, Colors.grey.shade300], begin: Alignment.topLeft, end: Alignment.bottomRight);

    // 3つのステータスに応じて表示を切り替える
    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    switch (tournament.status) {
      case 'pending':
        statusText = '開催準備中';
        statusColor = const Color.fromARGB(255, 46, 104, 204);
        statusIcon = Icons.event;
        break;
      case 'judging':
        statusText = '結果集計中...';
        statusColor = const Color.fromARGB(255, 255, 64, 198);
        statusIcon = Icons.hourglass_top;
        break;
      default: // 'ongoing'
        statusText = '開催中';
        statusColor = Colors.redAccent;
        statusIcon = Icons.whatshot;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(gradient: borderGradient, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: isMainTournament ? BoxDecoration(gradient: LinearGradient(colors: [Colors.yellow.shade100, Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight)) : null,
            child: InkWell(
              // 開催予定(pending)の場合はSnackBarを表示
              onTap: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;

                // 1. ユーザーランクを取得して参加資格を判定
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                final userRank = userDoc.data()?['rankForCurrentMonth'] ?? userDoc.data()?['rank'] ?? 'beginner';
                final isEligible = (userRank == tournament.eligibleRank || tournament.eligibleRank == 'common');

                // --- ランクが参加条件を満たしていない場合 ---
                if (!isEligible) {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('参加ランクが異なります'),
                        content: const Text('この大会には参加できませんが、大会の様子を見ますか？'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('キャンセル'),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          TextButton(
                            child: const Text('はい'),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ],
                      );
                    },
                  );
                  // 「はい」が押されなかった場合は処理を終了
                  if (confirm != true) return;
                  // 「はい」が押された後、開催状況をチェック
                  if (tournament.status == 'pending') {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('この大会はまだ開催されていません。'),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    }
                  } else { // 開催中 or 結果集計中の場合
                    if (context.mounted) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => TournamentDashboardPage(tournamentId: tournament.id)
                      ));
                    }
                  }
                  return; // 処理を終了
                }
                
                // --- ランクが条件を満たしている場合 ---
                if (tournament.status == 'pending') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('まだ開催されていません！もう少しお待ちください。'),
                      backgroundColor: Colors.blueAccent,
                    ),
                  );
                  return;
                }
                
                // 既存のエントリー処理
                try {
                  final entryDoc = await FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).collection('entries').doc(currentUser.uid).get();
                  if (context.mounted) {
                    if (entryDoc.exists) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => TournamentDashboardPage(tournamentId: tournament.id)));
                    } else {
                      if (tournament.lpType == 'NATIVE') {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => TournamentLpPage(tournament: tournament)));
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => LpWebviewPage(tournament: tournament)));
                      }
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: CachedNetworkImage(
                          imageUrl: tournament.bannerUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Chip(
                          avatar: Icon(statusIcon, color: Colors.white, size: 16),
                          label: Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: statusColor.withOpacity(0.8),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Chip(
                          avatar: const Icon(Icons.people, color: Colors.white, size: 16),
                          label: Text('${tournament.participantCount}人参加中', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color.fromARGB(255, 105, 103, 0).withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tournament.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (tournament.status == 'pending')
                          Text('開催期間: ${DateFormat('M/d').format(tournament.startDate)} - ${DateFormat('M/d').format(tournament.endDate)}', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold))
                        else if (tournament.status == 'judging')
                          Text('投稿受付終了', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold))
                        else
                          Text('終了まで: ${tournament.endDate.difference(DateTime.now()).inDays}日', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildInfoChip(Icons.military_tech, 'ルール: ${_getMetricDisplayName(tournament.rule.metric)}', tournament.rule.metric == 'LIKE_COUNT' ? Colors.pink.shade800 : Colors.blue),
                            const SizedBox(width: 8),
                            Builder(builder: (context) {
                              final rankStyle = _getRankStyle(tournament.eligibleRank);
                              return _buildInfoChip(Icons.workspace_premium, '対象: ${rankStyle.text}', rankStyle.color);
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

void _showTermsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('大会の利用規約', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const SingleChildScrollView(
        child: Text(
          '''前文
            この利用規約（以下「本規約」といいます）は、「エギワン」が提供するすべての大会（以下「本大会」といいます）に参加する際のルールを定めるものです。本大会へのエントリーをもって、参加者は本規約のすべての内容に同意したものとみなします。

            ---

            第1条（禁止事項）
            参加者は、本大会への参加にあたり、以下の行為を行ってはなりません。運営は、禁止行為が確認された投稿を予告なく削除し、当該ユーザーに対して警告、アカウントの一時停止または永久削除等の措置を講じることができます。

            1.  **不正行為**
                * 釣果のサイズや匹数を偽る行為（デジタル加工、計測方法のごまかし等）。
                * 自身で撮影していない画像（インターネットからの転載、第三者の釣果写真等）を利用する行為。
                * 大会期間外や対象エリア外で得た釣果を投稿する行為。
                * 同一人物が複数のアカウントを利用して大会に参加する行為。
                * その他、運営が不正または不公平と判断する一切の行為。

            2.  **迷惑行為**
                * 他者への誹謗中傷、脅迫、嫌がらせ、プライバシーを侵害するコメントや投稿。
                * わいせつ、暴力的、差別的、その他公序良俗に反する内容の投稿。
                * 本大会の運営を妨害し、または本アプリの信頼を毀損する一切の行為。
                * その他、運営が本アプリの秩序を乱すと判断する行為。

            ---

            第2条（投稿に関するルール）
            1.  サイズや匹数を競う大会においては、運営が指定する方法（例：公式メジャーや指定アイテムを釣果と共に撮影する等）で証拠を提出する必要があります。指定外の方法で投稿された場合、審査の対象外となることがあります。
            2.  投稿された画像やコメントに含まれる知的財産権は、投稿したユーザー本人に帰属します。ただし、ユーザーは運営に対し、本アプリの広告宣伝やプロモーションの目的で、これらを無償かつ非独占的に使用（複製、編集、公開等）する権利を許諾するものとします。

            ---

            第3条（参加者の責任と免責事項）
            1.  参加者は、自身の安全管理を徹底し、関連法規（漁業権、立入禁止区域、遊漁規則等）を遵守する責任を負います。
            2.  本大会への参加中に発生した事故、盗難、参加者間のトラブル、その他一切の損害について、運営は責任を負いません。
            3.  通信障害やシステムメンテナンス等により、一時的にサービスが利用できなくなる可能性があることを、参加者はあらかじめ承諾するものとします。

            ---

            第4条（運営の権限）
            1.  本大会の内容、期間、賞品等は、運営の判断により予告なく変更、中断、または中止される場合があります。
            2.  本規約に定めのない事項や、規約の解釈に疑義が生じた場合は、すべて運営の判断が最終決定となり、参加者はこれに従うものとします。なお、運営は個別の判断理由について開示する義務を負いません。

            ---

            第5条（規約の改定）
            運営は、必要と判断した場合、参加者への予告なく本規約を改定できるものとします。改定後の規約は、本アプリ内に掲示された時点からその効力を生じるものとします。

            **附則**
            2025年8月11日 制定・施行''',
          style: TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF13547a)),
          child: const Text('閉じる', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}