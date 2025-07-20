import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/login_page.dart';
import '../providers/unread_notifications_provider.dart';
import '../features/notifications/notification_page.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget> actions;
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
  // ▼▼▼ buildメソッドに WidgetRef ref を追加 ▼▼▼
  Widget build(BuildContext context, WidgetRef ref) {
    // Providerを監視して未読数を取得
    final unreadCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return AppBar(
      title: title,
      bottom: bottom,
      actions: [
        // ▼▼▼ ここから通知ベルのUIを追加 ▼▼▼
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const NotificationPage(),
            ));
          },
          tooltip: 'お知らせ',
        ),
        // ▲▲▲ ここまで通知ベルのUI ▲▲▲

        // 既存のactions（ログアウトボタンなど）を追加
        ...actions,
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _logout(context),
          tooltip: 'ログアウト',
        ),
      ],
    );
  }

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }
}