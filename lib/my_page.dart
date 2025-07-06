import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'post_detail_sheet.dart';
import 'post_model.dart';
import 'edit_profile_page.dart';
import 'comment_page.dart';

class MyPage extends StatefulWidget {
  final String userId;
  const MyPage({super.key, required this.userId});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 16),
            const Divider(),
            _buildBadgeSection(),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'これまでの投稿',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildUserPostsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final photoUrl = userData['photoUrl'] as String? ?? '';
        final displayName = userData['displayName'] as String? ?? '名無しさん';
        final introduction =
            userData['introduction'] as String? ?? '自己紹介がありません';
        final isCurrentUser = _currentUser.uid == widget.userId;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 24),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isCurrentUser)
                    Row(
                      children: [
                        // プロフィール編集ボタン
                        IconButton(
                          icon: const Icon(Icons.edit_note),
                          tooltip: 'プロフィールを編集',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const EditProfilePage(),
                              ),
                            );
                          },
                        ),
                        // 設定ボタン（今回はダミー）
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: '設定',
                          onPressed: () {
                            // TODO: 設定画面への遷移を実装
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // 自己紹介文
              Text(introduction, style: const TextStyle(fontSize: 16)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          '釣果数',
          FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: widget.userId),
        ),
        _buildStatItem(
          'フォロワー',
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('followers'),
        ),
        _buildStatItem(
          'フォロー中',
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('following'),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, Query query) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        );
      },
    );
  }

  Widget _buildBadgeSection() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'バッジ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Center(child: Text('取得したバッジはありません')),
        ],
      ),
    );
  }

  // ユーザーの投稿一覧をグリッド形式で構築するウィジェット
  Widget _buildUserPostsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('まだ投稿がありません。'),
            ),
          );
        }
        // GridView.builderに変更
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2列表示
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.7, // カードの縦横比を調整
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final post = Post.fromFirestore(snapshot.data!.docs[index]);
            // 新しいカードウィジェットを呼び出す
            return _PostGridCard(post: post);
          },
        );
      },
    );
  }
}

// マイページ用の新しい2列グリッドカード
class _PostGridCard extends StatelessWidget {
  final Post post;
  const _PostGridCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias, // 画像が角丸からはみ出ないようにする
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 投稿画像
          Expanded(
            child: Image.network(
              post.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // 釣果情報
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'イカ ${post.squidSize} cm', // 仮の魚種名
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  post.egiType, // 場所として流用
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy.MM.dd').format(post.createdAt),
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
