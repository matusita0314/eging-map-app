import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // ▼▼▼ 追加 ▼▼▼
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  bool _termsViewed = false;       // 利用規約をタップしたか
  bool _privacyViewed = false;     // プライバシーポリシーをタップしたか
  bool _isTermsAccepted = false;   // 同意チェックボックスの状態

  Future<void> _signUp() async {
    // 同意していない場合は処理を中断
    if (!_isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('利用規約とプライバシーポリシーに同意してください。')),
      );
      return;
    }
    
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(_usernameController.text.trim());
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'uid': credential.user!.uid,
          'email': credential.user!.email,
          'displayName': _usernameController.text.trim().isNotEmpty
              ? _usernameController.text.trim()
              : '名無しさん',
          'photoUrl': '',
          'createdAt': Timestamp.now(),
          'hasChangedDisplayName': false,
          'hasChangedPhoto': false,
          'notificationSettings': {
            'follow': true,
            'likes': true,
            'saves': true,
            'comments': true,
          },
          'rank': 'beginner',
          'rankForCurrentMonth': 'beginner',
          'totalCatches': 0,
          'maxSize': 0,
          'maxWeight': 0,
          'followerCount': 0,
          'followingCount': 0,
          'totalLikesReceived': 0,
          'hasCreatedGroup': false,
          'hasJoinedTournament': false,
        });
      }
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginPage(successMessage: '会員登録が完了しました。ログインしてください。'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${e.message}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$urlString を開けませんでした。')),
        );
      }
    }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 登録ボタンが押せるかどうかを判定する変数
    final isButtonEnabled = _isTermsAccepted && !_isLoading;

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
                    '新規アカウント登録',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
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
                        // ユーザー名
                        const Text('ユーザー名', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameController,
                          maxLength: 7, 
                          decoration: InputDecoration(
                            hintText: 'アプリ内で表示される名前(7文字以内)',
                            counterText: "", 
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // メールアドレス
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
                        // パスワード
                        const Text('パスワード', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '6文字以上',
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ▼▼▼ 利用規約とプライバシーポリシーの同意セクション ▼▼▼
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _isTermsAccepted,
                              onChanged: (bool? value) {
                                // 規約とポリシーを両方表示済みの場合のみチェックを許可
                                if (_termsViewed && _privacyViewed) {
                                  setState(() {
                                    _isTermsAccepted = value ?? false;
                                  });
                                } else {
                                  // まだ表示していない場合はメッセージを表示
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('先に利用規約とプライバシーポリシーをご確認ください。')),
                                  );
                                }
                              },
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  children: [
                                    TextSpan(
                                      text: '利用規約',
                                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () async {
                                          // ▼▼▼ ご自身の利用規約ページのURLに書き換えてください ▼▼▼
                                          await _launchURL('https://eging-map-app.web.app/terms.html');
                                          setState(() {
                                            _termsViewed = true;
                                          });
                                        },
                                    ),
                                    const TextSpan(text: 'と'),
                                    TextSpan(
                                      text: 'プライバシーポリシー',
                                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () async {
                                          await _launchURL('https://eging-map-app.web.app/privacy.html');
                                          setState(() {
                                            _privacyViewed = true;
                                          });
                                        },
                                    ),
                                    const TextSpan(text: 'に同意する'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // 登録ボタン
                        ElevatedButton(
                          onPressed: isButtonEnabled ? _signUp : null, // 状態によって有効/無効を切り替え
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13547a),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // ボタンが無効な時の色を定義
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : const Text('登録する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // ログイン画面への案内
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('アカウントをお持ちですか？', style: TextStyle(color: Colors.white)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('ログイン', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
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