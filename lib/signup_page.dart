import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // 入力されたメールアドレスとパスワードを管理するための変数
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 新規登録処理を実行するメソッド
  Future<void> _signUp() async {
    // try-catchでエラー処理を実装
    try {
      // FirebaseAuthの機能を使って、ユーザーを新規作成
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // 成功した場合、この画面が有効（mounted）であれば、前の画面に戻るなどの処理
      if (mounted) {
        // 例えば、成功したことを示すスナックバーを表示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('新規登録に成功しました。')),
        );
        // この後の画面遷移はmain.dartのStreamBuilderが自動でやってくれる
      }
    } on FirebaseAuthException catch (e) {
      // エラーが発生した場合
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${e.message}')),
        );
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

  // ここで画面の見た目（UI）を作成
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新規登録'),
      ),
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
              obscureText: true, // パスワードを隠す
            ),
            const SizedBox(height: 32),
            // 新規登録ボタン
            ElevatedButton(
              onPressed: _signUp, // ボタンが押されたら_signUpメソッドを実行
              child: const Text('新規登録'),
            ),
          ],
        ),
      ),
    );
  }
}