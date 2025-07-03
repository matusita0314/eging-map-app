import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'app_scaffold.dart';

void main() async {
  // main関数に「async」を追加
  // FlutterアプリでFirebaseを初期化するために必要な1行
  WidgetsFlutterBinding.ensureInitialized();
  // 先ほど自動生成されたfirebase_options.dartを使ってFirebaseを初期化
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eging App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // homeプロパティをStreamBuilderに置き換える
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 接続を待っている間は、ローディング画面を表示
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // snapshotにデータ（ログイン済みのユーザー情報）があれば、
          // ログイン後の仮ページを表示
          if (snapshot.hasData) {
            // ログイン後に表示されるページ
            return const AppScaffold();
          }
          // snapshotにデータがなければ、LoginPageを表示
          return const LoginPage();
        },
      ),
    );
  }
}
