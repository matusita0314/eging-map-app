import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_scaffold.dart';
import '../features/auth/login_page.dart';
import 'fcm_service.dart'; // 作成したサービスクラスをインポート

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FcmService _fcmService = FcmService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // ▼▼▼ ログイン状態に応じてトークンを管理 ▼▼▼
        if (snapshot.hasData) {
          // ログイン済み：トークンを保存
          _fcmService.saveTokenToFirestore();
          return const AppScaffold();
        } else {
          // 未ログイン：トークンを削除（厳密には不要だが安全のため）
          // _fcmService.deleteTokenFromFirestore(); // ログアウト処理は別途実装が望ましい
          return const LoginPage();
        }
      },
    );
  }
}
