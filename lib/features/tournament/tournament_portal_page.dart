import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/tournament_model.dart';
import 'lp_webview_page.dart';
import 'tournament_dashboard.dart';

class TournamentPortalPage extends StatelessWidget {
  const TournamentPortalPage({super.key});

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
              Color(0xFF13547a),
              Color(0xFF80d0c7),
            ],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // SliverToBoxAdapter の代わりに SliverPersistentHeader を使用
                SliverPersistentHeader(
                  pinned: true, // これでヘッダーが画面上部に固定されます
                  delegate: _StickyAppBarDelegate(
                    child: Container( // 既存のヘッダーUIをそのまま child に渡します
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
                              '開催中の大会',
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
                            tooltip: '大会の利用規約',
                            onPressed: () => _showTermsDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .where('endDate', isGreaterThan: Timestamp.now())
                  .orderBy('endDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('現在開催中の大会はありません。', style: TextStyle(color: Colors.white, fontSize: 16)),
                  );
                }
                final tournaments = snapshot.data!.docs
                    .map((doc) => Tournament.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    return _TournamentCard(tournament: tournaments[index]);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

void _showTermsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '大会の利用規約',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: const SingleChildScrollView(
        // ★★★ Textウィジェットの中身を新しい利用規約に差し替え ★★★
        child: Text(
          '''前文
この利用規約（以下「本規約」といいます）は、「（ここにアプリ名を入力）」が提供するすべての大会（以下「本大会」といいます）に参加する際のルールを定めるものです。本大会へのエントリーをもって、参加者は本規約のすべての内容に同意したものとみなします。

---

#### 第1条（禁止事項）
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

#### 第2条（投稿に関するルール）
1.  サイズや匹数を競う大会においては、運営が指定する方法（例：公式メジャーや指定アイテムを釣果と共に撮影する等）で証拠を提出する必要があります。指定外の方法で投稿された場合、審査の対象外となることがあります。
2.  投稿された画像やコメントに含まれる知的財産権は、投稿したユーザー本人に帰属します。ただし、ユーザーは運営に対し、本アプリの広告宣伝やプロモーションの目的で、これらを無償かつ非独占的に使用（複製、編集、公開等）する権利を許諾するものとします。

---

#### 第3条（参加者の責任と免責事項）
1.  参加者は、自身の安全管理を徹底し、関連法規（漁業権、立入禁止区域、遊漁規則等）を遵守する責任を負います。
2.  本大会への参加中に発生した事故、盗難、参加者間のトラブル、その他一切の損害について、運営は責任を負いません。
3.  通信障害やシステムメンテナンス等により、一時的にサービスが利用できなくなる可能性があることを、参加者はあらかじめ承諾するものとします。

---

#### 第4条（運営の権限）
1.  本大会の内容、期間、賞品等は、運営の判断により予告なく変更、中断、または中止される場合があります。
2.  本規約に定めのない事項や、規約の解釈に疑義が生じた場合は、すべて運営の判断が最終決定となり、参加者はこれに従うものとします。なお、運営は個別の判断理由について開示する義務を負いません。

---

#### 第5条（規約の改定）
運営は、必要と判断した場合、参加者への予告なく本規約を改定できるものとします。改定後の規約は、本アプリ内に掲示された時点からその効力を生じるものとします。

**附則**
2025年8月11日 制定・施行''',
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return;

          final entryDoc = await FirebaseFirestore.instance
              .collection('tournaments').doc(tournament.id)
              .collection('entries').doc(currentUser.uid)
              .get();

          if (context.mounted) {
            if (entryDoc.exists) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => TournamentDashboardPage(tournamentId: tournament.id),
              ));
            } else {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => LpWebviewPage(tournament: tournament),
              ));
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournament.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.military_tech, 'ルール: ${_getMetricDisplayName(tournament.rule.metric)}', Colors.blue),
                      const SizedBox(width: 8),
                      if (tournament.eligibleRank != null)
                        _buildInfoChip(Icons.workspace_premium, '対象: ${tournament.eligibleRank}', Colors.orange),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${DateFormat('M月d日').format(tournament.endDate)} 23:59まで',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Row(
                        children: [
                          Text('詳細を見る', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
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

class _StickyAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyAppBarDelegate({required this.child});

  @override
  double get minExtent => 70.0; // ヘッダーの最小の高さ

  @override
  double get maxExtent => 70.0; // ヘッダーの最大の高さ

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent, // 背景のグラデーションを活かすため透明に
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}