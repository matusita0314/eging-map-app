import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 入力されたメールアドレスとパスワードを管理するための変数
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ログイン処理を実行するメソッド
  Future<void> _signIn() async {
    try {
      // FirebaseAuthの機能を使って、サインイン
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // 成功した場合の処理
      // main.dartのStreamBuilderが自動で画面遷移を処理してくれる
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ログインしました。')));
      }
    } on FirebaseAuthException catch (e) {
      // エラーが発生した場合
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.message}')));
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      // 1. Google認証のプロバイダを準備
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // 2. ポップアップウィンドウを表示してサインインを実行し、結果を受け取る
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithPopup(googleProvider);

      // 3. Firestoreにユーザー情報を保存（または更新）
      if (userCredential.user != null) {
        final user = userCredential.user!;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? '名無しさん',
          'photoUrl': user.photoURL ?? '',
          'lastSignInAt': Timestamp.now(),
        }, SetOptions(merge: true)); // merge:trueで既存のデータを安全に更新
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Googleサインインに成功しました。')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  // ウィジェットが不要になった際に、コントローラーを破棄する
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // メールアドレス入力フォーム
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'メールアドレス'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // パスワード入力フォーム
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            // ログインボタン
            ElevatedButton(onPressed: _signIn, child: const Text('ログイン')),
            // ... 既存のログインボタンの下
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.login), // Googleのロゴアイコンなどにするとより分かりやすい
              label: const Text('Googleでサインイン'),
              onPressed: _signInWithGoogle, // これから作成するGoogleサインイン用のメソッドを呼ぶ
            ),
            const SizedBox(height: 16),
            // 新規登録画面へ遷移するためのボタン
            TextButton(
              onPressed: () {
                // `Navigator.push`で新規登録画面へ遷移
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                );
              },
              child: const Text('新規登録はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}
