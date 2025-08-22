import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/tournament_model.dart';
import 'tournament_terms_page.dart';
import 'tournament_dashboard.dart';

class LpWebviewPage extends StatefulWidget {
  // ★ 1. tournamentオブジェクトを受け取るための変数を追加
  final Tournament tournament;
  
  // ★ 2. コンストラクタでtournamentを必須パラメータとして受け取るように変更
  const LpWebviewPage({super.key, required this.tournament});

  @override
  State<LpWebviewPage> createState() => _LpWebviewPageState();
}

class _LpWebviewPageState extends State<LpWebviewPage> {
  late final WebViewController _controller;
  var _loadingPercentage = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
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
      ..loadFlutterAsset('assets/index.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament.name),
        backgroundColor: const Color(0xff010a1a),
        elevation: 0,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}