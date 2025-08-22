import 'package:flutter/material.dart';
import 'dart:async';

class SquidLoadingIndicator extends StatefulWidget {
  const SquidLoadingIndicator({super.key});

  @override
  State<SquidLoadingIndicator> createState() => _SquidLoadingIndicatorState();
}

class _SquidLoadingIndicatorState extends State<SquidLoadingIndicator> {
  // アニメーションの状態を管理します (0=なし, 1=., 2=.., 3=...)
  int _animationStep = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          // ステップを 0, 1, 2, 3 のサイクルで更新します
          _animationStep = (_animationStep + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    // ドット3つ分の横幅を確保するためのSizedBox
    const spacer = SizedBox(width: 35);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF13547a), // 深い青
              Color(0xFF80d0c7), // 明るい水色
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/squid.png', // ★ご自身のファイル名に書き換えてください
                height: 120,
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 「Loading」の左側に、ドットと同じ幅の空白を配置します
                  spacer,

                  // これで「Loading」テキストが常に中央に配置されます
                  const Text('Loading', style: textStyle),

                  // ドットを表示するための、左寄せのコンテナです
                  SizedBox(
                    width: 35, // 左の空白と同じ幅
                    child: Text(
                      '.' * _animationStep,
                      textAlign: TextAlign.left,
                      style: textStyle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}