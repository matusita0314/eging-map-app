import 'package:flutter/material.dart';
import '../features/home_feed/timeline_page.dart';
import '../features/map/map_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/tournament/tournament_page.dart';
import '../features/chat/chat_list_page.dart';
import '../features/challenge/challenge_page.dart';
import '../features/account/my_account_page.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;
  final _user = FirebaseAuth.instance.currentUser!;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 新しいページ構成
    _pages = <Widget>[
      const TimelinePage(),
      const MapPage(),
      const TournamentPage(),
      const ChallengePage(),
      const ChatListPage(),
      MyAccountPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        // 新しいタブのアイテムリスト
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'タイムライン'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'マップ'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: '大会'),
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'チャレンジ'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'チャット'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'アカウント'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // タブが多くなったので、タイプをfixedに設定
        type: BottomNavigationBarType.fixed,
        // 選択されていないアイテムの色も指定
        unselectedItemColor: Colors.grey,
        // 選択されているアイテムの色を指定
        selectedItemColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
