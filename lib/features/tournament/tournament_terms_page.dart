import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentTermsPage extends StatefulWidget {
  final String tournamentId;
  const TournamentTermsPage({super.key, required this.tournamentId});

  @override
  State<TournamentTermsPage> createState() => _TournamentTermsPageState();
}

class _TournamentTermsPageState extends State<TournamentTermsPage> {
  bool _isRegistering = false;
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // エントリー処理 (ロジックは変更なし)
  Future<void> _registerEntry() async {
    setState(() { _isRegistering = true; });

    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('entries')
          .doc(_currentUser.uid)
          .set({
            'entryDate': Timestamp.now(),
            'userName': _currentUser.displayName ?? '名無しさん',
            'userPhotoUrl': _currentUser.photoURL ?? '',
          });
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エントリーに失敗しました: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isRegistering = false; });
      }
    }
  }

  // ★★★ UI構造を全面的に刷新 ★★★
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // ★ bottomNavigationBar を削除
      body: Container(
        // ★ 背景グラデーションを追加
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
        child: Stack(
          children: [
            // ★ メインのスクロールコンテンツ
            SafeArea(
              bottom: false,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    // ★ フローティングAppBar
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Expanded(
                              child: Text(
                                '大会利用規約',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF13547a),
                                ),
                              ),
                            ),
                            const SizedBox(width: 48), // タイトルを中央に保つためのスペーサー
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // ★ 利用規約を白いカードの中に表示
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          '''前文
                          この利用規約（以下「本規約」といいます）は、「（エギングワン）」が提供するすべての大会（以下「本大会」といいます）に参加する際のルールを定めるものです。本大会へのエントリーをもって、参加者は本規約のすべての内容に同意したものとみなします。

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
                          2025年9月10日 制定・施行''',
                          style: TextStyle(height: 1.5, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                    ),
                    onPressed: _isRegistering ? null : _registerEntry,
                    child: _isRegistering
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('同意してエントリーする', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}