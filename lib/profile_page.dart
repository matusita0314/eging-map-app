import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'common_app_bar.dart';
import 'post_model.dart';
import 'post_detail_sheet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 現在ログインしているユーザー情報を取得
  final user = FirebaseAuth.instance.currentUser!;

  // _ProfilePageStateクラスの中に追加
  void _showPostDetailSheet(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // シートの高さをコンテンツに合わせる
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PostDetailSheet(post: post);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'プロフィール'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- ユーザー情報表示エリア ---
            _buildProfileHeader(),
            const Divider(),
            // --- 投稿一覧表示エリア ---
            _buildUserPostsGrid(),
          ],
        ),
      ),
    );
  }

  // ユーザーのヘッダー情報（アイコン、名前など）を構築するウィジェット
  Widget _buildProfileHeader() {
    // usersコレクションからリアルタイムでユーザー情報を取得
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // 取得したデータがない場合（新規登録直後など）も考慮
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final photoUrl = userData['photoUrl'] as String? ?? '';
        final displayName = userData['displayName'] as String? ?? '名無しさん';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // TODO: ここに「プロフィールを編集」ボタンを後で追加
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ユーザーの投稿一覧をグリッド形式で構築するウィジェット
  Widget _buildUserPostsGrid() {
    return StreamBuilder<QuerySnapshot>(
      // postsコレクションから、現在のユーザーの投稿のみを新しい順で取得
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: Text('まだ投稿がありません。')),
          );
        }

        // GridView.builderで投稿画像をグリッド表示
        return GridView.builder(
          // GridViewをスクロール可能にし、親のSingleChildScrollViewと競合しないようにする
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 1行に3つの画像
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: snapshot.data!.docs.length,
          // _buildUserPostsGridメソッドの中
          itemBuilder: (context, index) {
            final post = Post.fromFirestore(snapshot.data!.docs[index]);
            // GestureDetectorで画像をラップして、タップ可能にする
            return GestureDetector(
              onTap: () {
                // タップされた投稿のデータを渡して、詳細シートを表示
                _showPostDetailSheet(post);
              },
              child: Image.network(
                post.imageUrl,
                fit: BoxFit.cover,
                // 画像読み込み中の表示
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
