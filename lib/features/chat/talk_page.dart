import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

// メッセージのデータモデルを修正
class Message {
  final String text;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final DateTime createdAt;

  Message.fromFirestore(DocumentSnapshot doc)
      : text = (doc.data() as Map<String, dynamic>)['text'] ?? '',
        senderId = (doc.data() as Map<String, dynamic>)['senderId'] ?? '',
        senderName = (doc.data() as Map<String, dynamic>)['senderName'] ?? '名無しさん',
        senderPhotoUrl = (doc.data() as Map<String, dynamic>)['senderPhotoUrl'] ?? '',
        createdAt = ((doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp).toDate();
}


class TalkPage extends StatefulWidget {
  final String chatRoomId;
  final String chatTitle; // otherUserNameから変更
  final bool isGroupChat; // 追加

  const TalkPage({
    super.key,
    required this.chatRoomId,
    required this.chatTitle,
    required this.isGroupChat,
  });

  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  final _messageController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId);
    await chatRoomRef.update({'unreadCount.${_currentUser.uid}': 0});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageRef = FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId).collection('messages');
    final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId);

    _messageController.clear();

    // メッセージに送信者の名前と写真URLも含める
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(messageRef.doc(), {
        'text': text,
        'senderId': _currentUser.uid,
        'senderName': _currentUser.displayName ?? '名無しさん',
        'senderPhotoUrl': _currentUser.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(chatRoomRef, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatTitle)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('${widget.chatTitle}との最初のメッセージを送信しましょう！'));
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = Message.fromFirestore(messages[index]);
                    final isMe = message.senderId == _currentUser.uid;
                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      isGroupChat: widget.isGroupChat,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageInputField() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(hintText: 'メッセージを入力...', border: InputBorder.none),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
          ],
        ),
      ),
    );
  }
}

// メッセージの吹き出しUIを修正
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isGroupChat;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isGroupChat,
  });

  @override
  Widget build(BuildContext context) {
    final showAvatarAndName = !isMe && isGroupChat;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showAvatarAndName)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, bottom: 2.0),
              child: Text(message.senderName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showAvatarAndName)
                CircleAvatar(
                  radius: 16,
                  backgroundImage: message.senderPhotoUrl.isNotEmpty ? CachedNetworkImageProvider(message.senderPhotoUrl) : null,
                  child: message.senderPhotoUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
                ),
              if (showAvatarAndName) const SizedBox(width: 8),
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Text(message.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}