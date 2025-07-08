import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'post_detail_page.dart';
import 'post_model.dart';
import 'edit_profile_page.dart';
import 'comment_page.dart';
import 'widgets/post_grid_card.dart';

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
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          introduction,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentUser)
                    Row(
                      children: [
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
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: '設定',
                          onPressed: () {},
                        ),
                      ],
                    ),
                ],
              ),
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

  // ▼▼▼ 投稿一覧を2列のグリッド形式で構築するウィジェットに変更 ▼▼▼
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
            childAspectRatio: 1.0, // カードの縦横比を調整
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final post = Post.fromFirestore(snapshot.data!.docs[index]);
            // 2列表示用の新しいカードウィジェットを呼び出す
            return PostGridCard(post: post);
          },
        );
      },
    );
  }
}

// マイページ用の新しい2列グリッドカード（StatefulWidgetに変更）
class _MyPageGridCard extends StatefulWidget {
  final Post post;
  const _MyPageGridCard({required this.post});

  @override
  State<_MyPageGridCard> createState() => _MyPageGridCardState();
}

class _MyPageGridCardState extends State<_MyPageGridCard> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('likes')
        .doc(_currentUser.uid)
        .get();
    if (mounted && doc.exists) {
      setState(() => _isLiked = true);
    }
  }

  Future<void> _handleLike() async {
    setState(() {
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
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
    return GestureDetector(
      onTap: () {
        // タップしたら投稿詳細ページに移動
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailPage(post: widget.post),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像
            Expanded(
              child: Image.network(
                widget.post.imageUrl,
                width: double.infinity,
                // ▼▼▼ 画像の表示方法をcontainに変更 ▼▼▼
                fit: BoxFit.contain,
              ),
            ),
            // 釣果情報
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                'イカ ${widget.post.squidSize} cm',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ▼▼▼ いいね・コメントボタンを復活 ▼▼▼
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: _handleLike,
                  ),
                  Text('$_likeCount', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Color.fromARGB(255, 202, 95, 95),
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CommentPage(post: widget.post),
                        ),
                      );
                    },
                  ),
                  Text(
                    '${widget.post.commentCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
