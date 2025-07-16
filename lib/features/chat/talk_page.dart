import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// メッセージのデータモデル
class Message {
  final String text;
  final String senderId;
  final DateTime createdAt;

  Message.fromFirestore(DocumentSnapshot doc)
      : text = (doc.data() as Map<String, dynamic>)['text'] ?? '',
        senderId = (doc.data() as Map<String, dynamic>)['senderId'] ?? '',
        createdAt = ((doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp).toDate();
}

class TalkPage extends StatefulWidget {
  final String chatRoomId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  const TalkPage({
    super.key,
    required this.chatRoomId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
  });

  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  final _messageController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // メッセージを送信する処理
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final messageRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
        .collection('messages');
    
    final chatRoomRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId);

    // 入力内容をクリア
    _messageController.clear();

    // 2つの書き込み処理を同時に行う
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // 1. 新しいメッセージを追加
      transaction.set(messageRef.doc(), {
        'text': text,
        'senderId': _currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(), // サーバー側のタイムスタンプを利用
      });
      // 2. チャットルームの最終メッセージ情報を更新
      transaction.update(chatRoomRef, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {}), // 履歴(時計)
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}), // 電話
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}), // その他
        ],
      ),
      body: Column(
        children: [
          // メッセージ一覧
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
                  return const Center(child: Text('メッセージを送信してみましょう！'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0), // 全体に少し余白
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = Message.fromFirestore(messages[index]);
                    final isMe = message.senderId == _currentUser.uid;
                    // ▼▼▼ 相手のアイコンを表示するために修正 ▼▼▼
                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      otherUserPhotoUrl: widget.otherUserPhotoUrl,
                    );
                  },
                );
              },
            ),
          ),
          // メッセージ入力欄
          _buildMessageInputField(),
        ],
      ),
    );
  }

  // メッセージ入力欄のウィジェット
  Widget _buildMessageInputField() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'メッセージを入力...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// メッセージの吹き出しUI
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String otherUserPhotoUrl;

  const _MessageBubble({required this.message, required this.isMe, required this.otherUserPhotoUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}