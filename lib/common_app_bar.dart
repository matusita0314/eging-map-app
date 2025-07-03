import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// AppBarはPreferredSizeWidgetという特別な種類を実装する必要があります
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  // 各ページからタイトルを受け取るための変数
  final String title;

  // コンストラクタでタイトルを受け取る
  const CommonAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // 受け取ったタイトルを表示
      title: Text(title),
      // ログアウトボタンは共通なので、ここにまとめて記述
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
          tooltip: 'ログアウト',
        ),
      ],
    );
  }

  // AppBarの高さを指定するための決まり文句
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}