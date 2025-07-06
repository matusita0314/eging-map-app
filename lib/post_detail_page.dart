import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'post_model.dart';
import 'my_page.dart';
import 'comment_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 投稿詳細を表示するための専用ページ
class PostDetailPage extends StatelessWidget {
  final Post post;
  const PostDetailPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${post.userName}の投稿'),
      ),
      body: SingleChildScrollView(
        child: _TimelinePostCard(post: post), // タイムラインのカードを再利用
      ),
    );
  }
}

// タイムラインのカードウィジェット（timeline_page.dartからコピー＆ペースト）
// NOTE: 本来は共通のウィジェットとして別ファイルに切り出すのが望ましいですが、
//       ここでは説明を簡単にするために、一旦このページに含めます。
class _TimelinePostCard extends StatefulWidget {
  final Post post;
  const _TimelinePostCard({required this.post});

  @override
  State<_TimelinePostCard> createState() => _TimelinePostCardState();
}

class _TimelinePostCardState extends State<_TimelinePostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final doc = await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('likes').doc(_currentUser.uid).get();
    if (mounted && doc.exists) {
      setState(() => _isLiked = true);
    }
  }

  Future<void> _handleLike() async {
    setState(() {
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
    final likeRef = postRef.collection('likes').doc(_currentUser.uid);
    if (_isLiked) {
      await likeRef.set({'likedAt': Timestamp.now()});
      await postRef.update({'likeCount': FieldValue.increment(1)});
    } else {
      await likeRef.delete();
      await postRef.update({'likeCount': FieldValue.increment(-1)});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(0), // 詳細ページでは余白をなくす
      elevation: 0, // 詳細ページでは影をなくす
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => MyPage(userId: widget.post.userId))),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: widget.post.userPhotoUrl.isNotEmpty ? NetworkImage(widget.post.userPhotoUrl) : null,
                    child: widget.post.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.post.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // 画像は画面幅いっぱいに表示
          Image.network(widget.post.imageUrl, width: double.infinity, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('イカ ${widget.post.squidSize} cm', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('ヒットエギ: ${widget.post.egiType}', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text(DateFormat('yyyy.MM.dd').format(widget.post.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.grey),
                  onPressed: _handleLike,
                ),
                Text('$_likeCount'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => CommentPage(post: widget.post)));
                  },
                ),
                Text('${widget.post.commentCount}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
