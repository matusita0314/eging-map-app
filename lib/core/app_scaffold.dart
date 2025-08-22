import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/home_feed/timeline_page.dart';
import '../features/map/map_page.dart';
import '../features/account/account.dart';
import '../features/tournament/tournament_portal_page.dart';
import '../features/challenge/challenge_page.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const List<NavItem> navItems = [
  NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'ホーム'),
  NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'マップ'),
  NavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: '大会'),
  NavItem(icon: Icons.shield_outlined, activeIcon: Icons.shield, label: 'チャレンジ'),
  NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'アカウント'),
];


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
      const TournamentPortalPage(),
      const ChallengePage(),
      MyPage(userId: _user.uid),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _CustomBottomNavBar(
        items: navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _CustomBottomNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      height: 65, // 全体の高さを確保
      color: const Color(0xFF13547a), // ここに背景色を設定
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // --- 1. ナビゲーションバーの背景 ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 65,
              decoration: const BoxDecoration(
                color: Color(0xFF13547a),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: -2,
                  )
                ],
              ),
            ),
          ),
          // --- 3. アイコンとテキスト ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  return _NavBarItem(
                    item: items[index],
                    isSelected: index == currentIndex,
                    onTap: () => onTap(index),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _NavBarItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color.fromARGB(255, 255, 255, 255) : const Color.fromARGB(255, 194, 194, 194);
    final fontWeight = isSelected ? FontWeight.w700 : FontWeight.w500;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}