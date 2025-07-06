import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'common_app_bar.dart';
import 'post_model.dart'; // Postモデルをインポート
import 'profile_page.dart'; // ProfilePageをインポート

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
class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

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
                  builder: (context) => ProfilePage(userId: post.userId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    // ユーザーのプロフィール画像があれば表示、なければデフォルトアイコン
                    backgroundImage: post.userPhotoUrl.isNotEmpty
                        ? NetworkImage(post.userPhotoUrl)
                        : null,
                    child: post.userPhotoUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          // 投稿画像
          Image.network(
            post.imageUrl,
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
          ),
          // 釣果情報
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${post.squidSize} cm',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('ヒットエギ: ${post.egiType}'),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(post.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
