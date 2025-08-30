import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpodをインポート

import 'app_scaffold.dart';
import '../features/auth/login_page.dart';
import 'fcm_service.dart';
import '../widgets/squid_loading_indicator.dart'; 
import '../providers/discover_feed_provider.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print("【デバッグ】2. 認証状態を確認中...");
        } else if (snapshot.hasData) {
          print("【デバッグ】2. ログイン状態を検知！データ読み込み画面へ。");
        } else {
          print("【デバッグ】2. 未ログイン状態を検知。ログインページへ。");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // 認証状態の確認中は、カスタムローディングを表示
          return const SquidLoadingIndicator();
        }
        
        if (snapshot.hasData) {
          // ▼▼▼【変更点】ログイン済みの場合、すぐにAppScaffoldを表示せず、
          // データ読み込み用の新しいウィジェットを返す ▼▼▼
          return const _DataLoadingAndRedirect();
        } else {
          // ログインしていない場合はログインページへ
          return const LoginPage();
        }
      },
    );
  }
}

class _DataLoadingAndRedirect extends ConsumerStatefulWidget {
  const _DataLoadingAndRedirect();

  @override
  ConsumerState<_DataLoadingAndRedirect> createState() => _DataLoadingAndRedirectState();
}

class _DataLoadingAndRedirectState extends ConsumerState<_DataLoadingAndRedirect> {
  final FcmService _fcmService = FcmService();
  bool _isInitialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    _fcmService.saveTokenToFirestore();
  }

  @override
  Widget build(BuildContext context) {
    // ▼▼▼【修正】ref.listen を build メソッド内に移動 ▼▼▼
    // ref.listen はUIの再構築は行わず、状態変化を監視して特定の処理（ここでは setState）を実行します。
    print("【デバッグ】3. _DataLoadingAndRedirect ウィジェット構築開始！");

    ref.listen<AsyncValue<DiscoverFeedState>>(discoverFeedNotifierProvider, (previous, next) {
      // 読み込みが完了し、データが入った初回のみフラグを更新する
      if (!_isInitialLoadComplete && next is AsyncData) {
        print("【デバッグ】6. Providerからデータ受信！isInitialLoadComplete を true にします。");
        setState(() {
          _isInitialLoadComplete = true;
        });
      }
    });

    // 初回ロードが完了したら、プロバイダーの状態に関わらず常に AppScaffold を表示する
    if (_isInitialLoadComplete) {
      return const AppScaffold();
    }

    // 初回ロードが完了するまでは、プロバイダーの状態を監視してUIを切り替える
    // ref.watch はUIの再構築を行う
    final timelineAsyncValue = ref.watch(discoverFeedNotifierProvider);
    return timelineAsyncValue.when(
      loading: () => const SquidLoadingIndicator(),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('データの読み込みに失敗しました: $err'),
        ),
      ),
      // listen によって isInitialLoadComplete が true になるまでの間、
      // データ取得後の一瞬だけローディングを表示する
      data: (_) => const SquidLoadingIndicator(),
    );
  }
}
