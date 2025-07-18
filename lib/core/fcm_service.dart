import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initializeLocalNotifications() async {
    // Android用の初期化設定
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // アイコンを指定

    // iOS用の初期化設定 (Macがなくても記述だけしておく)
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);
  }

  // ▼▼▼ フォアグラウンド通知を表示するチャンネル設定を追加 ▼▼▼
  Future<void> createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // チャンネルID (AndroidManifest.xmlと一致させる)
      'High Importance Notifications', // チャンネル名
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // FCMトークンを取得し、Firestoreに保存する
  Future<void> saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // ログインしていない場合は何もしない

    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // 既存のトークンリストに、新しいトークンを追加する
      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

      // トークンが更新された場合にも対応
      _messaging.onTokenRefresh.listen((newToken) {
        userRef.update({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
        });
      });
    } catch (e) {
      print("FCMトークンの保存に失敗しました: $e");
    }
  }

  // ログアウト時にFCMトークンを削除する
  Future<void> deleteTokenFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      // ログアウトする端末のトークンのみをリストから削除
      await userRef.update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      print("FCMトークンの削除に失敗しました: $e");
    }
  }
}
