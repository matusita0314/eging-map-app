import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart' show kIsWeb; // Webかどうかを判定するためにインポート
// import 'package:google_sign_in/google_sign_in.dart'; // モバイル用に再度インポート
import 'password_reset_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final String? successMessage;
  const LoginPage({super.key, this.successMessage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // （変更なし）
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'エラーが発生しました。';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'メールアドレスまたはパスワードが間違っています。';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

//   Future<void> _googleLogin() async {
//   if (_isLoading) return;
//   setState(() => _isLoading = true);

//   try {
//     UserCredential userCredential;

//     if (kIsWeb) {
//       // --- Webの場合の処理 ---
//       final provider = GoogleAuthProvider();
//       userCredential = await FirebaseAuth.instance.signInWithProvider(provider);
//     } else {
//       // --- モバイル (Android/iOS) の場合の処理 ---

//       // 1. 【ここが重要】initializeメソッドでserverClientIdを設定
//       await GoogleSignIn.instance.initialize(
//         serverClientId: '211367399364-bj9q7v983a3g8hsm69ksupjb5vp8bdbb.apps.googleusercontent.com',
//       );

//       // 2. 認証を実行
//       final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      
//       if (googleUser == null) {
//         if (mounted) setState(() => _isLoading = false);
//         return; // ユーザーがキャンセル
//       }
      
//       // 3. 認証情報からFirebase用のCredentialを作成
//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//       final credential = GoogleAuthProvider.credential(
//         accessToken: null, // accessTokenは不要
//         idToken: googleAuth.idToken,
//       );

//       // 4. Firebaseにサインイン
//       userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
//     }

//     final user = userCredential.user;

//     // Firestoreへのユーザー情報保存処理 (共通)
//     if (user != null) {
//       final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
//       final doc = await userDocRef.get();
//       if (!doc.exists) {
//         await userDocRef.set({
//           'uid': user.uid,
//           'email': user.email,
//           'displayName': user.displayName ?? '名無しさん',
//           'photoUrl': user.photoURL ?? '',
//           'createdAt': Timestamp.now(),
//           'hasChangedDisplayName': false,
//           'hasChangedPhoto': false,
//           'notificationSettings': {
//             'follow': true, 'likes': true, 'saves': true, 'comments': true,
//           },
//         });
//       }
//     }
//   } catch (e) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Googleログインに失敗しました: $e'), backgroundColor: Colors.redAccent),
//       );
//     }
//   } finally {
//     if (mounted) setState(() => _isLoading = false);
//   }
// }


  @override
  Widget build(BuildContext context) {
    // （UI部分は変更なし）
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF13547a),
              Color(0xFF80d0c7),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  const Text(
                    'EGING ONE へようこそ',
                    style: TextStyle( color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('メールアドレス', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'example@example.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('パスワード', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'パスワード',
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const PasswordResetPage()),
                              );
                            },
                            child: const Text('パスワードをお忘れですか？'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13547a),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : const Text('ログイン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        // const SizedBox(height: 16),
                        // ElevatedButton.icon(
                        //   onPressed: _isLoading ? null : _googleLogin,
                        //   // icon: Image.asset('assets/images/google_logo.png', height: 24.0),
                        //   label: const Text('Googleでログイン'),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: Colors.white,
                        //     foregroundColor: Colors.black,
                        //      padding: const EdgeInsets.symmetric(vertical: 16),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(12),
                        //       side: const BorderSide(color: Colors.grey)
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('アカウントをお持ちでないですか？', style: TextStyle(color: Colors.white)),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const SignupPage()),
                          );
                        },
                        child: const Text('新規登録', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}