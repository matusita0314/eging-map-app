import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/login_page.dart'; // ログインページをインポート

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  // ▼▼▼【変更】タイトルをWidget型にして、柔軟性を持たせる ▼▼▼
  final Widget? title;
  final List<Widget> actions;
  // ▼▼▼【追加】TabBarなどを配置するためのbottomプロパティ ▼▼▼
  final PreferredSizeWidget? bottom;

  const CommonAppBar({
    super.key,
    this.title,
    this.actions = const [],
    this.bottom,
  });

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // AppBarのプロパティをそのまま受け渡す
      title: title,
      bottom: bottom,
      // ▼▼▼【変更】既存のactionsにログアウトボタンを必ず追加する ▼▼▼
      actions: actions + [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _logout(context),
          tooltip: 'ログアウト',
        ),
      ],
    );
  }

  // AppBarの高さを指定
  @override
  Size get preferredSize {
    // bottomがある場合はその高さも考慮する
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }
}