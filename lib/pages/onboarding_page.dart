// lib/pages/onboarding_page.dart (レイアウト最終修正版)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'auth_wrapper.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  bool _isLastPage = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景のスワイプページ
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _isLastPage = index == 2;
              });
            },
            children: [
              // 1ページ目
              _buildPageContent(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF68FFFC), Color(0xFFA2A2A2)],
                ),
                child: const Text(
                  'EGING ONE',
                  style: TextStyle(
                    color: Color(0xFFEAFF38),
                    fontSize: 54,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // 2ページ目
              _buildPageContent(
                imagePath: 'images/onboarding_2.jpg', // ご自身の画像パスに修正
                child: const Text(
                  'エギワンへようこそ！',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 3ページ目
              _buildPageContent(
                imagePath: 'images/onboarding_3.jpg', // ご自身の画像パスに修正
                child: const Text(
                  'それでは、始めましょう',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // ▼▼▼ 下部のインジケーターとボタンの配置を全面的に修正 ▼▼▼
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60.0), // 画面下からの余白
              child: Column(
                mainAxisSize: MainAxisSize.min, // Columnが必要な高さだけを使うようにする
                children: [
                  // 最後のページ以外ならインジケーターを表示
                  if (!_isLastPage)
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: 3,
                      effect: const WormEffect(
                        dotHeight: 12,
                        dotWidth: 12,
                        activeDotColor: Colors.white,
                        dotColor: Colors.white54,
                      ),
                    ),

                  const SizedBox(height: 24), // インジケーターとボタンの間の余白

                  SizedBox(
                    width: 250, // ← ここでボタンの横幅を指定します
                    child: ElevatedButton(
                      onPressed: _isLastPage
                          ? _onDone
                          : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF68A2FF), Color(0xFF14E5E1)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _isLastPage ? 'はじめる' : 'つぎへ',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 各ページの中身を構築するウィジェット（名前を変更）
  Widget _buildPageContent({
    required Widget child,
    Gradient? gradient,
    String? imagePath,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        image: imagePath != null
            ? DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Center(child: child),
    );
  }
}
