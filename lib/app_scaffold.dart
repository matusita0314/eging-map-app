import 'package:flutter/material.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  // ログインしているユーザー情報を取得
  final _user = FirebaseAuth.instance.currentUser!;

  // _pagesリストをStateの中に移動し、動的に生成するように変更
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // ページリストを初期化
    _pages = <Widget>[
      const HomePage(),
      const MapPage(),
      // ProfilePageに、ログインしている自分のユーザーIDを渡す
      ProfilePage(userId: _user.uid),
    ];
  }

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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'マップ'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロファイル'),
        ],
        currentIndex: _selectedIndex, // 現在選択されているタブ
        onTap: _onItemTapped, // タップされたときの処理
      ),
    );
  }
}
