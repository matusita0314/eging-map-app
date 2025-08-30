import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// メッセージのデータモデル
class Message {
  final String text;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final DateTime createdAt;

  Message.fromFirestore(DocumentSnapshot doc)
      : text = (doc.data() as Map<String, dynamic>)['text'] ?? '',
        senderId = (doc.data() as Map<String, dynamic>)['senderId'] ?? '',
        senderName =
            (doc.data() as Map<String, dynamic>)['senderName'] ?? '名無しさん',
        senderPhotoUrl =
            (doc.data() as Map<String, dynamic>)['senderPhotoUrl'] ?? '',
        createdAt =
            ((doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp)
                .toDate();
}

class TalkPage extends StatefulWidget {
  final String chatRoomId;
  final String chatTitle;
  final bool isGroupChat;

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
    initializeDateFormatting('ja_JP');
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

  Future<void> _markAsRead() async {
    final chatRoomRef =
        FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId);
    await chatRoomRef.update({'unreadCount.${_currentUser.uid}': 0});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
        .collection('messages');
    final chatRoomRef =
        FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId);

    _messageController.clear();

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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF13547a), Color(0xFF80d0c7)],
          ),
        ),
        // ★★★ ColumnをStackに変更 ★★★
        child: Stack(
          children: [
            // メインコンテンツ（ヘッダーとメッセージリスト）
            Column(
              children: [
                _buildHeader(),
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
                        return Center(
                            child: Text('${widget.chatTitle}にメッセージを送信しましょう！',
                                style: const TextStyle(color: Colors.white)));
                      }
                      final messages = snapshot.data!.docs;
                      return ListView.builder(
                        // ★★★ 下部に余白を追加 ★★★
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final currentMessage =
                              Message.fromFirestore(messages[index]);
                          final isMe =
                              currentMessage.senderId == _currentUser.uid;

                          bool needsSeparator = false;
                          if (index == messages.length - 1) {
                            // チャットの最初のメッセージ
                            needsSeparator = true;
                          } else {
                            final olderMessage =
                                Message.fromFirestore(messages[index + 1]);
                            if (!_isSameDay(currentMessage.createdAt,
                                olderMessage.createdAt)) {
                              needsSeparator = true;
                            }
                          }

                          final messageBubble = _MessageBubble(
                            message: currentMessage,
                            isMe: isMe,
                            isGroupChat: widget.isGroupChat,
                          );

                          if (needsSeparator) {
                            return Column(
                              children: [
                                _DateSeparator(date: currentMessage.createdAt),
                                messageBubble,
                              ],
                            );
                          } else {
                            return messageBubble;
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            // ★★★ 画面下部に固定する入力欄 ★★★
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMessageInputField(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 15, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF13547a)),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: '戻る',
            ),
            Expanded(
              child: Text(
                widget.chatTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF13547a)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    // このウィジェットはPositionedによって配置される
    return SafeArea(
      top: false,
      child: Container(
        // ★★★ スタイルを微調整 ★★★
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, -4),
              spreadRadius: 1,
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                style: const TextStyle(fontSize: 16),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

  @override
  Widget build(BuildContext context) {
    final String displayText = _isSameDay(date, DateTime.now())
        ? '今日'
        : DateFormat('M/d (E)', 'ja_JP').format(date);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

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
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMe ? const Color.fromARGB(255, 77, 205, 96) : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    final showAvatarAndName = !isMe && isGroupChat;

    final time = DateFormat('HH:mm').format(message.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (showAvatarAndName)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, bottom: 4.0),
              child: Text(message.senderName,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                  child: Text(time,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ),
              if (showAvatarAndName)
                CircleAvatar(
                  radius: 16,
                  backgroundImage: message.senderPhotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(message.senderPhotoUrl)
                      : null,
                  child: message.senderPhotoUrl.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
              if (showAvatarAndName) const SizedBox(width: 8),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(20.0)),
                child: Text(message.text, style: TextStyle(color: textColor)),
              ),
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                  child: Text(time,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}