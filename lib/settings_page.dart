import 'package:flutter/material.dart';
import 'common_app_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 作成したCommonAppBarを呼び出し、titleプロパティを渡す
      appBar: CommonAppBar(title: '設定'),
      body: const Center(child: Text('設定画面')),
    );
  }
}
