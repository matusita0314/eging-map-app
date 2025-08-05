import 'dart:math';
import 'package:flutter/material.dart';

class _Bubble extends StatelessWidget {
  final double size;
  const _Bubble({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SquidLoadingIndicator extends StatefulWidget {
  const SquidLoadingIndicator({super.key});

  @override
  State<SquidLoadingIndicator> createState() => _SquidLoadingIndicatorState();
}

class _SquidLoadingIndicatorState extends State<SquidLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _squidVerticalPosition;
  late final Animation<double> _squidScale;

  late final List<AnimationController> _bubbleControllers;
  final int _bubbleCount = 50;
  
  late final List<double> _bubbleSizes;
  late final List<double> _bubblePositions;


  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _squidVerticalPosition = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.2).chain(CurveTween(curve: Curves.easeOut)), weight: 8),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 8),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.2).chain(CurveTween(curve: Curves.easeOut)), weight: 8),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 8),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -1.5).chain(CurveTween(curve: Curves.easeOut)), weight: 33),
    ]).animate(_controller);

    _squidScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 13),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 13),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 38),
    ]).animate(_controller);

    // ▼▼▼【変更】泡の大きさと位置をランダムに初期化 ▼▼▼
    final random = Random();
    _bubbleSizes = List.generate(_bubbleCount, (_) => 6.0 + random.nextDouble() * 6.0);
    _bubblePositions = List.generate(_bubbleCount, (_) => -0.9 + random.nextDouble() * 1.8);

    _bubbleControllers = List.generate(_bubbleCount, (index) {
      final controller = AnimationController(
        vsync: this,
        // 速度もランダムにする
        duration: Duration(milliseconds: 2500 + random.nextInt(2500)),
      );
      Future.delayed(Duration(milliseconds: random.nextInt(5000)), () {
        if(mounted) controller.repeat();
      });
      return controller;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _bubbleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ▼▼▼ グラデーション背景 ▼▼▼
          Container(
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
          ),
          ...List.generate(_bubbleCount, (index) {
            return AnimatedBuilder(
              animation: _bubbleControllers[index],
              builder: (context, child) {
                final value = _bubbleControllers[index].value;
                final position = Alignment(
                  _bubblePositions[index], // X位置
                  1.1 - (value * 2.2),     // Y位置
                );
                return Align(
                  alignment: position,
                  child: Opacity(
                    opacity: 1.0 - value,
                    child: child,
                  ),
                );
              },
              child: _Bubble(size: _bubbleSizes[index]),
            );
          }),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment(0, _squidVerticalPosition.value),
                child: Transform.scale(
                  scale: _squidScale.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/squid.png', width: 100),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}