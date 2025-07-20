import 'package:flutter/material.dart';
import '../home_feed/notification_list_view.dart'; // 既存のウィジェットを再利用

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お知らせ'),
      ),
      // 既存のお知らせ一覧ウィジェットをそのまま配置
      body: NotificationListView(),
    );
  }
}