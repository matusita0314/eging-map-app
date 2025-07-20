import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/fcm_service.dart';
import 'core/firebase_options.dart';
import 'core/launch_page.dart';
import 'core/navigator_key.dart';
import 'features/post/post_detail_page.dart';
import 'models/post_model.dart';
import 'features/account/follower_list_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/chat/talk_page.dart';
import 'features/account/account.dart';

// バックグラウンドで通知を受信した際のハンドラ
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("--- バックグラウンドでメッセージを受信 ---");
  print("メッセージID: ${message.messageId}");
  if (message.notification != null) {
    print('タイトル: ${message.notification!.title}');
    print('本文: ${message.notification!.body}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCMサービスをインスタンス化
  final fcmService = FcmService();
  await fcmService.createNotificationChannel();
  await fcmService.initializeLocalNotifications();

  await FirebaseMessaging.instance.requestPermission();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // FCMのリスナーを設定
  _setupFcmListeners();

  runApp(const ProviderScope(child: MyApp()));
}

// FCMリスナー設定用のトップレベル関数
void _setupFcmListeners() {
  final localNotifications = FlutterLocalNotificationsPlugin();

  // 1. アプリがフォアグラウンドのときに通知を受信した場合の処理
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('--- フォアグラウンドでメッセージを受信 ---');
    final notification = message.notification;
    if (notification != null) {
      print('タイトル: ${notification.title}');
      print('本文: ${notification.body}');

      // ローカル通知として画面上部にバナー表示する
      localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    final String? postId = message.data['postId'];
    final String? type = message.data['type'];
    final String? fromUserId = message.data['fromUserId'];

    if (type == 'follow') {
      final fromUserId = message.data['fromUserId'];
      if (fromUserId != null) {
        print('フォロワーID: $fromUserId のプロフィールページに遷移します。');
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => MyPage(userId: fromUserId)),
        );
      }
    } else if (postId != null && postId.isNotEmpty) {
      // それ以外の通知（いいね、コメント等）の場合：投稿詳細ページへ
      print('投稿ID: $postId の詳細ページに遷移します。');
      try {
        final postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get();
        if (postDoc.exists) {
          final post = Post.fromFirestore(postDoc);
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
          );
        } else {
          print("投稿が見つかりませんでした。postId: $postId");
        }
      } catch (e) {
        print("投稿データの取得または画面遷移に失敗しました: $e");
      }
    } else if (type == 'dm') {
      // DM通知の場合：トークページへ
      final chatRoomId = message.data['chatRoomId'];
      final otherUserName = message.data['fromUserName'];
      final otherUserPhotoUrl = message.data['fromUserPhotoUrl'];

      if (chatRoomId != null && otherUserName != null) {
        print('チャットルームID: $chatRoomId のトークページに遷移します。');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => TalkPage(
              chatRoomId: chatRoomId,
              otherUserName: otherUserName,
              otherUserPhotoUrl: otherUserPhotoUrl ?? '',
            ),
          ),
        );
      }
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Eging One',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LaunchPage(),
    );
  }
}
