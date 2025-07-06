import 'package:flutter/material.dart';
import 'common_app_bar.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'ランキング'),
      body: const Center(
        child: Text('ランキング画面'),
      ),
    );
  }
}
