import 'package:flutter/material.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'profile_page.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  // 現在選択されているタブのインデックス
  int _selectedIndex = 0;

  // 各タブに対応するページのリスト
  static const List<Widget> _pages = <Widget>[
    HomePage(),
    MapPage(),
    ProfilePage(),
  ];

  // タブがタップされたときに呼ばれるメソッド
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // メインのコンテンツ表示部分
      body: _pages.elementAt(_selectedIndex),
      // 下部のナビゲーションバー
      bottomNavigationBar: BottomNavigationBar(
        // タブのアイテムリスト
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'マップ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'プロファイル',
          ),
        ],
        currentIndex: _selectedIndex, // 現在選択されているタブ
        onTap: _onItemTapped, // タップされたときの処理
      ),
    );
  }
}