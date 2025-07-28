import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../post/post_detail_page.dart';
import '../account/follower_list_page.dart';
import '../chat/talk_page.dart';

class NotificationListView extends StatefulWidget {
  const NotificationListView({super.key});

  @override
  State<NotificationListView> createState() => _NotificationListViewState();
}

class _NotificationListViewState extends State<NotificationListView> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // 日本語用のTimeagoロケールを初期化
    timeago.setLocaleMessages('ja', timeago.JaMessages());
  }

  // 通知をタップしたときの処理
  Future<void> _onNotificationTapped(NotificationModel notification) async {
    if (_currentUser == null) return;

    // まず通知を既読にする
    FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications')
        .doc(notification.id)
        .update({'isRead': true});

    // タップされた通知に関連する投稿データを取得
    if (notification.type == 'follow') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FollowerListPage(
            userId: _currentUser!.uid,
            listType: FollowListType.followers,
          ),
        ),
      );
    } else if (notification.type == 'dm') {
      if (notification.chatRoomId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TalkPage(
              chatRoomId: notification.chatRoomId!,
              chatTitle: notification.fromUserName,
              isGroupChat: false,
            ),
          ),
        );
      }
    } else {
      // 'likes', 'comments', 'saves'
      if (notification.postId.isNotEmpty) {
        final postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(notification.postId)
            .get();
        if (postDoc.exists && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  PostDetailPage(post: Post.fromFirestore(postDoc)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text("ログインして、通知を確認しましょう。"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50) // パフォーマンスのため、最新50件まで表示
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('エラーが発生しました。'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('まだお知らせはありません。', style: TextStyle(color: Colors.grey)),
          );
        }

        final notifications = snapshot.data!.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList();

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _NotificationTile(
              notification: notification,
              onTap: () => _onNotificationTapped(notification),
            );
          },
        );
      },
    );
  }
}

// --- 通知一つ分を表示するウィジェット ---
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  // 通知タイプに応じたアイコンとテキストを返すヘルパーメソッド
  (IconData, TextSpan) _buildNotificationContent() {
    final userNameSpan = TextSpan(
      text: notification.fromUserName,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
    final defaultStyle = TextStyle(color: Colors.grey.shade800, height: 1.4);

    switch (notification.type) {
      case 'follow':
        return (
          Icons.person_add, // フォロー用のアイコン
          TextSpan(
            children: [
              userNameSpan,
              const TextSpan(text: 'さんがあなたをフォローしました。'),
            ],
            style: defaultStyle,
          ),
        );
      case 'likes':
        return (
          Icons.favorite,
          TextSpan(
            children: [
              userNameSpan,
              const TextSpan(text: 'さんがあなたの投稿に「いいね」しました。'),
            ],
            style: defaultStyle,
          ),
        );
      case 'saves':
        return (
          Icons.bookmark,
          TextSpan(
            children: [
              userNameSpan,
              const TextSpan(text: 'さんがあなたの投稿を保存しました。'),
            ],
            style: defaultStyle,
          ),
        );
      case 'comments':
        return (
          Icons.chat_bubble,
          TextSpan(
            children: [
              userNameSpan,
              const TextSpan(text: 'さんがコメントしました: '),
              TextSpan(
                text: '"${notification.commentText ?? ''}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            style: defaultStyle,
          ),
        );
      case 'dm':
        return (
          Icons.chat,
          TextSpan(
            children: [
              userNameSpan,
              const TextSpan(text: 'さんからメッセージ: '),
              TextSpan(
                text: '"${notification.commentText ?? ''}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            style: defaultStyle,
          ),
        );

      default:
        return (
          Icons.notifications,
          TextSpan(text: '新しいお知らせがあります。', style: defaultStyle),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (iconData, messageSpan) = _buildNotificationContent();
    final timeAgo = timeago.format(notification.createdAt, locale: 'ja');

    return ListTile(
      tileColor: notification.isRead
          ? Colors.transparent
          : Colors.blue.withOpacity(0.05),
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withOpacity(0.1),
        child: Icon(iconData, color: Colors.blueAccent, size: 20),
      ),
      title: RichText(text: messageSpan),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          timeAgo,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
      trailing: notification.postThumbnailUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Image.network(
                notification.postThumbnailUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.hide_image, color: Colors.grey),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
