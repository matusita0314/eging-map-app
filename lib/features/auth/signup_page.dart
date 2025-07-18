import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // 入力されたメールアドレス、パスワード、ユーザー名を管理するための変数
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  // 新規登録処理を実行するメソッド
  Future<void> _signUp() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );

      // ユーザー作成成功後、Firestoreにユーザー情報を保存
      if (credential.user != null) {
        await credential.user!.updateDisplayName(_usernameController.text);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'uid': credential.user!.uid,
              'email': credential.user!.email,
              'displayName': _usernameController.text.isNotEmpty
                  ? _usernameController.text
                  : '名無しさん',
              'photoUrl': '', // 初期のプロフィール画像URL（空）
              'createdAt': Timestamp.now(),
              'hasChangedDisplayName': false, // プロフィール変更フラグ
              'hasChangedPhoto': false, // プロフィール変更フラグ

              'notificationSettings': {
                'follow': true,
                'likes': true, // いいね通知の初期値
                'saves': true, // 保存通知の初期値
                'comments': true, // コメント通知の初期値
              },
            });
      }
      await FirebaseAuth.instance.signOut();

      // 成功した場合、この画面が有効（mounted）であれば、前の画面に戻るなどの処理
      if (mounted) {
        // ★★★ ログインページに戻り、メッセージを渡す ★★★
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                const LoginPage(successMessage: '会員登録が完了しました。ログインしてください。'),
          ),
        );
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

  // ウィジェットが不要になった際に、コントローラーを破棄する
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ここで画面の見た目（UI）を作成
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.50, 0.00),
            end: Alignment(0.50, 1.00),
            colors: [Color(0xFF94D3D2), Color(0xFF9AAEAE), Color(0xFF9D9D9D)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 59),
                Text(
                  '新規会員登録',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 104),

                // ユーザー名フィールド
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 41),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          'ユーザー名',
                          style: TextStyle(
                            color: const Color(0xFF232222),
                            fontSize: 18,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 45,
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(width: 1, color: Colors.white),
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            hintStyle: TextStyle(
                              color: const Color(0xFF232222),
                              fontSize: 16,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // メールアドレスフィールド
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 41),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          'メールアドレス',
                          style: TextStyle(
                            color: const Color(0xFF232222),
                            fontSize: 18,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 45,
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(width: 1, color: Colors.white),
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintStyle: TextStyle(
                              color: const Color(0xFF391713),
                              fontSize: 20,
                              fontFamily: 'League Spartan',
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // パスワードフィールド
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 41),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          'パスワード',
                          style: TextStyle(
                            color: const Color(0xFF232222),
                            fontSize: 18,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 45,
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(width: 1, color: Colors.white),
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintStyle: TextStyle(
                              color: const Color(0xFF232222),
                              fontSize: 16,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              letterSpacing: 3.68,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 34),

                // 利用規約とプライバシーポリシーのテキスト
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 71),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '会員登録するには',
                          style: TextStyle(
                            color: const Color(0xFF391713),
                            fontSize: 8,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '利用規約',
                          style: TextStyle(
                            color: Color.fromARGB(255, 105, 82, 255),
                            fontSize: 8,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'と',
                          style: TextStyle(
                            color: const Color(0xFF391713),
                            fontSize: 8,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'プライバシーポリシー',
                          style: TextStyle(
                            color: Color.fromARGB(255, 105, 82, 255),
                            fontSize: 8,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'に同意してください。',
                          style: TextStyle(
                            color: const Color(0xFF391713),
                            fontSize: 8,
                            fontFamily: 'League Spartan',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 37),

                // 会員登録ボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            spreadRadius: 1,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                            side: const BorderSide(
                              color: Colors.white,
                              width: 0.5,
                            ),
                          ),
                          elevation: 8,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF34369B),
                                Color(0xFF494E92),
                                Color(0xFF3EE57B),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Container(
                            width: 178.56,
                            height: 44,
                            alignment: Alignment.center,
                            child: Text(
                              '会員登録',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
