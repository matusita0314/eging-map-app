import 'package:flutter/material.dart';
import 'ranking_page.dart';
import 'timeline_page.dart';
import 'map_page.dart';
import 'my_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tournament_page.dart';

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
      const RankingPage(),
      const MapPage(),
      const TournamentPage(),
      const TimelinePage(),
      MyPage(userId: _user.uid),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'ランキング',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'マップ'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: '大会'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'タイムライン'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'マイページ'),
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
