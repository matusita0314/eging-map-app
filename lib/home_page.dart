import 'package:flutter/material.dart';
import 'common_app_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 作成したCommonAppBarを呼び出し、titleプロパティを渡す
      appBar: CommonAppBar(title: 'ホーム'),
      body: const Center(child: Text('ホーム画面のコンテンツ')),
    );
  }
}
