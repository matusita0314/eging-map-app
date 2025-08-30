import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/tournament_model.dart';
import 'tournament_terms_page.dart';
import 'tournament_dashboard.dart';

class LpWebviewPage extends StatefulWidget {
  final Tournament tournament;
  const LpWebviewPage({super.key, required this.tournament});

  @override
  State<LpWebviewPage> createState() => _LpWebviewPageState();
}

class _LpWebviewPageState extends State<LpWebviewPage> {
  late final WebViewController _controller;
  // ★ 1. ページの読み込み状態を管理する変数
  bool _isPageLoading = true;

  @override
  void initState() {
    super.initState();

    final String assetPath = (widget.tournament.lpUrl != null && widget.tournament.lpUrl!.isNotEmpty)
        ? widget.tournament.lpUrl!
        : 'assets/index.html';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // ★ 2. WebViewの読み込みイベントを監視する 'NavigationDelegate' を設定
      ..setNavigationDelegate(
        NavigationDelegate(
          // ページの読み込みが完了したら呼ばれる
          onPageFinished: (String url) {
            // mountedチェックで安全にStateを更新
            if (mounted) {
              setState(() {
                _isPageLoading = false; // ローディング完了
              });
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'EntryButton',
        onMessageReceived: (JavaScriptMessage message) async {
          if (message.message == 'entry' && mounted) {
            final bool? didEnter = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => TournamentTermsPage(tournamentId: widget.tournament.id),
              ),
            );

            if (didEnter == true && mounted) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) => TournamentDashboardPage(tournamentId: widget.tournament.id),
              ));
            }
          }
        },
      )
      ..loadFlutterAsset(assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★ 3. 背景色をLPのテーマカラーに合わせることで、白い画面のチラつきをなくす
      backgroundColor: const Color(0xff010a1a),
      appBar: AppBar(
        title: Text(widget.tournament.name),
        backgroundColor: const Color(0xff010a1a),
        elevation: 0,
      ),
      // ★ 4. Stackを使って、WebViewとローディングインジケーターを重ねる
      body: Stack(
        children: [
          // WebViewは常に背後に配置
          WebViewWidget(controller: _controller),

          // _isPageLoadingがtrueの場合のみ、ローディング画面を前面に表示
          if (_isPageLoading)
            const Center(
              // ここではシンプルなインジケーターを使いますが、
              // お持ちのSquidLoadingIndicatorのコンテンツ部分だけをウィジェットとして切り出して使うことも可能です。
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}