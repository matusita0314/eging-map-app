import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_wrapper.dart';
import '../features/onboarding/onboarding_page.dart';

import 'fcm_service.dart';
import 'firebase_options.dart';
import '../widgets/squid_loading_indicator.dart';
import 'navigator_key.dart';
import '../models/post_model.dart';
import '../features/post/post_detail_page.dart';
import '../features/chat/talk_page.dart';
import '../features/account/account.dart';

// バックグラウンドメッセージハンドラはトップレベルに定義する必要があります
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("--- バックグラウンドでメッセージを受信 ---");
  if (message.notification != null) {
    print('タイトル: ${message.notification!.title}');
    print('本文: ${message.notification!.body}');
  }
}

class InitializationPage extends StatefulWidget {
  const InitializationPage({super.key});

  @override
  State<InitializationPage> createState() => _InitializationPageState();
}

class _InitializationPageState extends State<InitializationPage> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Firebase等のサービス初期化 (既存のコード)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    final fcmService = FcmService();
    await fcmService.createNotificationChannel();
    await fcmService.initializeLocalNotifications();
    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _setupFcmListeners();
    // 2. 初回起動かどうかを判定
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // 3. 判定結果に応じて次に表示するページを決定
    final Widget destination = hasSeenOnboarding
        ? const AuthWrapper()     
        : const OnboardingPage();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => destination), // 行き先を動的に変更
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初期化中はローディングインジケーターを表示
    return const SquidLoadingIndicator();
  }

  // 通知からの画面遷移を制御するリスナー
  void _setupFcmListeners() {
    final localNotifications = FlutterLocalNotificationsPlugin();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      
      if (notification != null) {
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
      final String? type = message.data['type'];
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      if (type == 'dm') {
        final chatRoomId = message.data['chatRoomId'];
        final chatRoomDoc = await FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).get();
        if (chatRoomDoc.exists) {
            final chatRoomData = chatRoomDoc.data()!;
            final isGroup = (chatRoomData['type'] ?? 'dm') == 'group';
            final chatTitle = isGroup ? (chatRoomData['groupName'] ?? 'グループ') : (message.data['fromUserName'] ?? 'トーク');
            
            navigator.push(MaterialPageRoute(
              builder: (_) => TalkPage(
                chatRoomId: chatRoomId,
                chatTitle: chatTitle,
                isGroupChat: isGroup,
              ),
            ));
        }
      } else if (type == 'follow') {
        final fromUserId = message.data['fromUserId'];
        if (fromUserId != null) {
          navigator.push(MaterialPageRoute(builder: (_) => MyPage(userId: fromUserId)));
        }
      } else if (['likes', 'comments', 'saves'].contains(type)) {
        final postId = message.data['postId'];
        if (postId != null && postId.isNotEmpty) {
          final postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            final post = Post.fromFirestore(postDoc);
            navigator.push(MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
          }
        }
      }
    });
  }
}