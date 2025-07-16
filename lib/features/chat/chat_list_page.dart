import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'talk_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text('チャット機能を利用するにはログインが必要です。'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('チャット')),
      body: StreamBuilder<QuerySnapshot>(
        // 'userIds'フィールドに自分のIDが含まれるチャットルームを全て取得
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('userIds', arrayContains: _currentUser!.uid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('エラーが発生しました。'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('まだチャットがありません。'));
          }

          final chatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              final chatRoomData =
                  chatDocs[index].data() as Map<String, dynamic>;
              // _ChatRoomTileにデータを渡して各タイルを生成
              return _ChatRoomTile(
                chatRoomId: chatDocs[index].id,
                chatRoomData: chatRoomData,
                currentUserId: _currentUser!.uid,
              );
            },
          );
        },
      ),
    );
  }
}

// チャットルーム一つ分を表示するためのウィジェット
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
    _fetchOtherUserData();
  }

  // チャット相手のユーザー情報を取得
  void _fetchOtherUserData() {
    final List<String> userIds = List<String>.from(
      widget.chatRoomData['userIds'] ?? [],
    );
    final otherUserId = userIds.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get()
          .then((doc) {
            if (mounted) {
              setState(() {
                _otherUserDoc = doc;
              });
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_otherUserDoc == null) {
      // 相手のユーザー情報が読み込まれるまでは、シンプルな表示にしておく
      return const ListTile(title: Text('読み込み中...'));
    }

    final otherUserData = _otherUserDoc!.data() as Map<String, dynamic>;
    final lastMessage =
        widget.chatRoomData['lastMessage'] as String? ?? 'まだメッセージはありません';
    final timestamp = widget.chatRoomData['lastMessageAt'] as Timestamp?;
    final lastMessageTime = timestamp != null
        ? DateFormat('MM/dd HH:mm').format(timestamp.toDate())
        : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            (otherUserData['photoUrl'] as String?).toString().isNotEmpty
            ? NetworkImage(otherUserData['photoUrl'])
            : null,
        child: (otherUserData['photoUrl'] as String?).toString().isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        otherUserData['displayName'] ?? '名無しさん',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        lastMessageTime,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TalkPage(
              chatRoomId: widget.chatRoomId,
              otherUserName: otherUserData['displayName'] ?? '名無しさん',
              otherUserPhotoUrl: otherUserData['photoUrl'] ?? '',
            ),
          ),
        );
      },
    );
  }
}
