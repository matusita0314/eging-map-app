// lib/features/chat/tabs/talks_tab_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../talk_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TalksTabView extends StatelessWidget {
  const TalksTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('ログインが必要です。', style: TextStyle(color: Colors.white)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('userIds', arrayContains: currentUser.uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだトークがありません。', style: TextStyle(color: Colors.white, fontSize: 16)));
        }
        final chatDocs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatRoomData = chatDocs[index].data() as Map<String, dynamic>;
            return _ChatRoomTile(
              chatRoomId: chatDocs[index].id,
              chatRoomData: chatRoomData,
              currentUserId: currentUser.uid,
            );
          },
        );
      },
    );
  }
}

class _ChatRoomTile extends StatefulWidget {
  final String chatRoomId;
  final Map<String, dynamic> chatRoomData;
  final String currentUserId;

  const _ChatRoomTile({
    required this.chatRoomId,
    required this.chatRoomData,
    required this.currentUserId,
  });

  @override
  State<_ChatRoomTile> createState() => _ChatRoomTileState();
}

class _ChatRoomTileState extends State<_ChatRoomTile> {
  DocumentSnapshot? _otherUserDoc;
  bool _isLoading = true;

    String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageDate = timestamp.toDate();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (messageDate.isAfter(today)) {
      // 今日のメッセージ
      return DateFormat('HH:mm').format(messageDate);
    } else if (messageDate.isAfter(yesterday)) {
      // 昨日のメッセージ
      return '昨日';
    } else {
      // それより前のメッセージ
      return DateFormat('M/d').format(messageDate);
    }
  }

  @override
  void initState() {
    super.initState();
    final isGroup = (widget.chatRoomData['type'] ?? 'dm') == 'group';
    if (!isGroup) {
      _fetchOtherUserData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _fetchOtherUserData() {
    final List<String> userIds = List<String>.from(widget.chatRoomData['userIds'] ?? []);
    final otherUserId = userIds.firstWhere((id) => id != widget.currentUserId, orElse: () => '');

    if (otherUserId.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(otherUserId).get().then((doc) {
        if (mounted) setState(() {
          _otherUserDoc = doc;
          _isLoading = false;
        });
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTrailing(String time, int unreadCount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
            child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        else
          const SizedBox(height: 18), // 高さを合わせるためのSizedBox
      ],
    );
  }

    @override
  Widget build(BuildContext context) {
    final chatType = widget.chatRoomData['type'] ?? 'dm';
    final isGroup = chatType == 'group';
    final lastMessage = widget.chatRoomData['lastMessage'] as String? ?? '';
    final timestamp = widget.chatRoomData['lastMessageAt'] as Timestamp?;
    final lastMessageTime = _formatTimestamp(timestamp);
    final unreadMap = widget.chatRoomData['unreadCount'] as Map<String, dynamic>?;
    final unreadCount = unreadMap?[widget.currentUserId] as int? ?? 0;


    if (_isLoading) {
      return Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    Widget tileContent;

    if (isGroup) {
      final groupName = widget.chatRoomData['groupName'] ?? 'グループ名なし';
      final groupPhotoUrl = widget.chatRoomData['groupPhotoUrl'] ?? '';
      tileContent = ListTile(
        leading: CircleAvatar(
          backgroundImage: groupPhotoUrl.isNotEmpty ? CachedNetworkImageProvider(groupPhotoUrl) : null,
          child: groupPhotoUrl.isEmpty ? const Icon(Icons.group) : null,
        ),
        title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _buildTrailing(lastMessageTime, unreadCount),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => TalkPage(
              chatRoomId: widget.chatRoomId,
              chatTitle: groupName,
              isGroupChat: true,
            ),
          ));
        },
      );
    } else {
      if (_otherUserDoc == null || !_otherUserDoc!.exists) {
        return const SizedBox.shrink(); // 相手がいない場合は表示しない
      }
      final otherUserData = _otherUserDoc!.data() as Map<String, dynamic>;
      final photoUrl = otherUserData['photoUrl'] as String? ?? '';
      tileContent = ListTile(
        leading: CircleAvatar(
          backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
          child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(otherUserData['displayName'] ?? '名無しさん', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _buildTrailing(lastMessageTime, unreadCount),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => TalkPage(
              chatRoomId: widget.chatRoomId,
              chatTitle: otherUserData['displayName'] ?? '名無しさん',
              isGroupChat: false,
            ),
          ));
        },
      );
    }

    // ▼▼▼ カードUIでラップ ▼▼▼
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: tileContent,
    );
  }
}