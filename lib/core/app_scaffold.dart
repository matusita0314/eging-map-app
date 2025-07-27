import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/home_feed/timeline_page.dart';
import '../features/map/map_page.dart';
import '../features/account/account.dart';
import '../features/tournament/tournament_page.dart';
import '../features/chat/chat_page.dart';
import '../features/challenge/challenge_page.dart';
import '../providers/chat_provider.dart';

// StatefulWidget を ConsumerStatefulWidget に変更
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
      const TimelinePage(),
      const MapPage(),
      const TournamentPage(),
      const ChallengePage(),
      const ChatPage(),
      MyPage(userId: _user.uid),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Providerを監視し、未読数を取得
    final unreadCount = ref.watch(unreadChatCountProvider).value ?? 0;

    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'タイムライン',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'マップ'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: '大会',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'チャレンジ',
          ),
          // ▼▼▼ チャットアイコンをStackで囲んでバッジを表示 ▼▼▼
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'チャット',
          ),
          const BottomNavigationBarItem(
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
