import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/home_feed/timeline_page.dart';
import '../features/map/map_page.dart';
import '../features/account/account.dart';
import '../features/tournament/tournament_page.dart';
import '../features/chat/chat_page.dart';
import '../features/challenge/challenge_page.dart';

class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  int _selectedIndex = 0;
  final _user = FirebaseAuth.instance.currentUser!;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      const TimelinePage(), // ホーム
      const MapPage(),
      const TournamentPage(),
      const ChallengePage(),
      MyPage(userId: _user.uid), // アカウント
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home), // ホームアイコンに変更
            label: 'ホーム',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'マップ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: '大会',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'チャレンジ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'アカウント',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        unselectedItemColor: Colors.grey,
        selectedItemColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
