// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'auth_wrapper.dart';
// import '../features/onboarding/onboarding_page.dart';

// class LaunchPage extends StatefulWidget {
//   const LaunchPage({super.key});

//   @override
//   State<LaunchPage> createState() => _LaunchPageState();
// }

// class _LaunchPageState extends State<LaunchPage> {
//   @override
//   void initState() {
//     super.initState();
//     _checkIfFirstLaunch();
//   }

//   Future<void> _checkIfFirstLaunch() async {
//     final prefs = await SharedPreferences.getInstance();
//     // 'hasSeenOnboarding' の値を取得。なければtrue（初回とみなす）
//     final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

//     if (mounted) {
//       if (hasSeenOnboarding) {
//         // 2回目以降の起動
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const AuthWrapper()),
//         );
//       } else {
//         // 初回起動
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const OnboardingPage()),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // 起動時は常にローディング画面を表示し、すぐに判定処理に移行
//     return const Scaffold(body: Center(child: CircularProgressIndicator()));
//   }
// }
