import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'likes', 'saves', 'comments'
  final String fromUserName;
  final String fromUserId;
  final String postId;
  final String postThumbnailUrl;
  final String? commentText; // コメント通知の場合のみ
  final DateTime createdAt;
  final bool isRead;
  final String? chatRoomId;
  final String? fromUserPhotoUrl;

  NotificationModel({
    required this.id,
    required this.type,
    required this.fromUserName,
    required this.fromUserId,
    required this.postId,
    required this.postThumbnailUrl,
    this.commentText,
    required this.createdAt,
    required this.isRead,
    this.chatRoomId,
    this.fromUserPhotoUrl,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      type: data['type'] ?? '',
      fromUserName: data['fromUserName'] ?? '名無しさん',
      fromUserId: data['fromUserId'] ?? '',
      postId: data['postId'] ?? '',
      postThumbnailUrl: data['postThumbnailUrl'] ?? '',
      commentText: data['commentText'],
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      isRead: data['isRead'] ?? false,
      chatRoomId: data['chatRoomId'],
      fromUserPhotoUrl: data['fromUserPhotoUrl'],
    );
  }
}
