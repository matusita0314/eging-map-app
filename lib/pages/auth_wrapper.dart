// lib/pages/auth_wrapper.dart (新規作成)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_scaffold.dart';
import 'login_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
        if (snapshot.hasData) {
          // ログイン済み
          return const AppScaffold();
        }
        // 未ログイン
        return const LoginPage();
      },
    );
  }
}