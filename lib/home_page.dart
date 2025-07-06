import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'common_app_bar.dart';
import 'post_model.dart'; // Postモデルをインポート
import 'profile_page.dart'; // ProfilePageをインポート
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'タイムライン'),
      // StreamBuilderを使って、Firestoreの投稿をリアルタイムで表示
      body: StreamBuilder<QuerySnapshot>(
        // 'posts'コレクションを'createdAt'フィールドの降順（新しい順）で監視
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // データ取得中のローディング表示
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // エラーが発生した場合の表示
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          // データがまだない場合の表示
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('まだ投稿がありません。'));
          }

          // 取得したドキュメントのリスト
          final docs = snapshot.data!.docs;

          // ListView.builderで、スクロール可能な投稿リストを作成
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              // 各ドキュメントをPostモデルに変換
              final post = Post.fromFirestore(docs[index]);
              // 投稿カードウィジェットを返す
              return _PostCard(post: post);
            },
          );
        },
      ),
    );
  }
}

// 投稿一つ分を表示するための、プライベートなカードウィジェット
class _PostCard extends StatefulWidget {
  final Post post;

  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  // いいねの状態を管理する変数
  bool _isLiked = false;
  // いいねの数を管理する変数
  int _likeCount = 0;
  // 現在のユーザー情報
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    // 初期状態として、投稿のいいね数をセット
    _likeCount = widget.post.likeCount;
    // 自分が既にいいねしているかチェック
    _checkIfLiked();
  }

  // 自分が既にいいねしているかチェックするメソッド
  Future<void> _checkIfLiked() async {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('likes')
        .doc(_currentUser.uid)
        .get();
    if (mounted && doc.exists) {
      setState(() {
        _isLiked = true;
      });
    }
  }

  // いいね処理を実行するメソッド
  Future<void> _handleLike() async {
    // 状態を先に画面に反映させる（UIの応答性を良くするため）
    setState(() {
      if (_isLiked) {
        _likeCount--;
        _isLiked = false;
      } else {
        _likeCount++;
        _isLiked = true;
      }
    });

    // Firestoreの更新処理
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
    final likeRef = postRef.collection('likes').doc(_currentUser.uid);

    if (_isLiked) {
      // いいねする場合
      await likeRef.set({'likedAt': Timestamp.now()});
      await postRef.update({'likeCount': FieldValue.increment(1)});
    } else {
      // いいねを取り消す場合
      await likeRef.delete();
      await postRef.update({'likeCount': FieldValue.increment(-1)});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ユーザー情報（アイコンと名前）
          GestureDetector(
            onTap: () {
              // タップされたら、その投稿のユーザーIDを渡してプロフィール画面に移動
              Navigator.of(context).push(
                MaterialPageRoute(
                  // ▼▼▼ ここを修正 ▼▼▼
                  builder: (context) => ProfilePage(userId: widget.post.userId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    // ▼▼▼ ここを修正 ▼▼▼
                    backgroundImage: widget.post.userPhotoUrl.isNotEmpty
                        ? NetworkImage(widget.post.userPhotoUrl)
                        : null,
                    // ▼▼▼ ここを修正 ▼▼▼
                    child: widget.post.userPhotoUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    // ▼▼▼ ここを修正 ▼▼▼
                    widget.post.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          // 投稿画像
          Image.network(
            // ▼▼▼ ここを修正 ▼▼▼
            widget.post.imageUrl,
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
          ),
          // 釣果情報といいねボタン
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ▼▼▼ ここを修正 ▼▼▼
                Text(
                  '${widget.post.squidSize} cm',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // ▼▼▼ ここを修正 ▼▼▼
                Text('ヒットエギ: ${widget.post.egiType}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      // ▼▼▼ ここを修正 ▼▼▼
                      DateFormat(
                        'yyyy/MM/dd HH:mm',
                      ).format(widget.post.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : Colors.grey,
                          ),
                          onPressed: _handleLike,
                        ),
                        Text('$_likeCount'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
