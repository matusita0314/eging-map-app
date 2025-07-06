import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'post_model.dart';
import 'comment_model.dart';

class CommentPage extends StatefulWidget {
  final Post post;

  const CommentPage({super.key, required this.post});

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // コメントを投稿するメソッド
  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    // コメントデータをFirestoreに保存
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .add({
      'text': text,
      'userId': _currentUser.uid,
      'userName': _currentUser.displayName ?? '名無しさん',
      'userPhotoUrl': _currentUser.photoURL ?? '',
      'createdAt': Timestamp.now(),
    });

    // 投稿数をインクリメント
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .update({'commentCount': FieldValue.increment(1)});

    // 入力フィールドをクリア
    _commentController.clear();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コメント'),
      ),
      body: Column(
        children: [
          // コメント一覧を表示する部分
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('comments')
                  .orderBy('createdAt', descending: false) // 古い順で表示
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('最初のコメントを投稿しよう！'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final comment = Comment.fromFirestore(snapshot.data!.docs[index]);
                    return _CommentTile(comment: comment);
                  },
                );
              },
            ),
          ),
          // コメント入力欄
          _buildCommentInputField(),
        ],
      ),
    );
  }

  // コメント入力欄を構築するウィジェット
  Widget _buildCommentInputField() {
    return Container(
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
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'コメントを追加...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _postComment,
          ),
        ],
      ),
    );
  }
}

// コメント一つ分を表示するためのタイルウィジェット
class _CommentTile extends StatelessWidget {
  final Comment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: comment.userPhotoUrl.isNotEmpty
            ? NetworkImage(comment.userPhotoUrl)
            : null,
        child: comment.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(comment.text),
      trailing: Text(
        DateFormat('MM/dd HH:mm').format(comment.createdAt),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
