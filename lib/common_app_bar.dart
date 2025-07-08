import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// AppBarはPreferredSizeWidgetという特別な種類を実装する必要があります
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onFilterPressed; // フィルターボタン用のコールバック

  const CommonAppBar({
    super.key,
    required this.title,
    this.onFilterPressed, // コンストラクタで受け取る
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        // onFilterPressedが設定されている場合のみ、フィルターボタンを表示
        if (onFilterPressed != null)
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: onFilterPressed,
            tooltip: 'フィルター',
          ),
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