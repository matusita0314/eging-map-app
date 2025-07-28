import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../talk_page.dart';

class TalksTabView extends StatelessWidget {
  const TalksTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('ログインが必要です。'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('userIds', arrayContains: currentUser.uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだトークがありません。'));
        }
        final chatDocs = snapshot.data!.docs;
        return ListView.builder(
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

  @override
  void initState() {
    super.initState();
    final isGroup = (widget.chatRoomData['type'] ?? 'dm') == 'group';
    if (!isGroup) {
      _fetchOtherUserData();
    }
  }

  void _fetchOtherUserData() {
    final List<String> userIds = List<String>.from(widget.chatRoomData['userIds'] ?? []);
    final otherUserId = userIds.firstWhere((id) => id != widget.currentUserId, orElse: () => '');

    if (otherUserId.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(otherUserId).get().then((doc) {
        if (mounted) setState(() => _otherUserDoc = doc);
      });
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
            child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        else
          const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatType = widget.chatRoomData['type'] ?? 'dm';
    final isGroup = chatType == 'group';

    final lastMessage = widget.chatRoomData['lastMessage'] as String? ?? '';
    final timestamp = widget.chatRoomData['lastMessageAt'] as Timestamp?;
    final lastMessageTime = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';
    final unreadMap = widget.chatRoomData['unreadCount'] as Map<String, dynamic>?;
    final unreadCount = unreadMap?[widget.currentUserId] as int? ?? 0;

    if (isGroup) {
      final groupName = widget.chatRoomData['groupName'] ?? 'グループ名なし';
      final groupPhotoUrl = widget.chatRoomData['groupPhotoUrl'] ?? '';

      return ListTile(
        leading: CircleAvatar(
          backgroundImage: groupPhotoUrl.isNotEmpty ? NetworkImage(groupPhotoUrl) : null,
          child: groupPhotoUrl.isEmpty ? const Icon(Icons.group) : null,
        ),
        title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _buildTrailing(lastMessageTime, unreadCount),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TalkPage(
                chatRoomId: widget.chatRoomId,
                chatTitle: groupName,
                isGroupChat: true,
              ),
            ),
          );
        },
      );
    }

    if (_otherUserDoc == null) {
      return const ListTile(title: Text('')); // 読み込み中のチラつき防止
    }
    if (!_otherUserDoc!.exists) {
      return const ListTile(title: Text('不明なユーザー'));
    }
    
    final otherUserData = _otherUserDoc!.data() as Map<String, dynamic>;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (otherUserData['photoUrl'] as String?).toString().isNotEmpty
            ? NetworkImage(otherUserData['photoUrl'])
            : null,
        child: (otherUserData['photoUrl'] as String?).toString().isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(otherUserData['displayName'] ?? '名無しさん', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _buildTrailing(lastMessageTime, unreadCount),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TalkPage(
              chatRoomId: widget.chatRoomId,
              chatTitle: otherUserData['displayName'] ?? '名無しさん',
              isGroupChat: false,
            ),
          ),
        );
      },
    );
  }
}