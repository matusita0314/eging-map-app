import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'common_app_bar.dart';
import 'post_detail_sheet.dart';
import 'post_model.dart';
import 'edit_profile_page.dart'; // プロフィール編集ページをインポート

class MyPage extends StatefulWidget {
  final String userId;
  const MyPage({super.key, required this.userId});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // フォローしているかどうかを管理する状態変数
  bool _isFollowing = false;
  // フォロー状態をチェック中かどうか
  bool _isLoadingFollowStatus = true;

  @override
  void initState() {
    super.initState();
    // 画面が表示された時に、フォロー状態をチェックする
    _checkIfFollowing();
  }

  // フォロー状態をチェックするメソッド
  Future<void> _checkIfFollowing() async {
    // 自分自身のプロフィールの場合はチェック不要
    if (widget.userId == _currentUser.uid) {
      setState(() => _isLoadingFollowStatus = false);
      return;
    }
    setState(() => _isLoadingFollowStatus = true);
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('following')
        .doc(widget.userId)
        .get();

    if (mounted) {
      setState(() {
        _isFollowing = doc.exists;
        _isLoadingFollowStatus = false;
      });
    }
  }

  // フォロー/アンフォローを処理するメソッド
  Future<void> _handleFollow() async {
    // WriteBatchを使って、複数の書き込みを一度に（アトミックに）実行
    final batch = FirebaseFirestore.instance.batch();

    // 自分のfollowingコレクションへの参照
    final myFollowingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('following')
        .doc(widget.userId);

    // 相手のfollowersコレクションへの参照
    final theirFollowersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .doc(_currentUser.uid);

    if (_isFollowing) {
      // アンフォローの場合：ドキュメントを削除
      batch.delete(myFollowingRef);
      batch.delete(theirFollowersRef);
    } else {
      // フォローの場合：ドキュメントを作成
      batch.set(myFollowingRef, {'followedAt': Timestamp.now()});
      batch.set(theirFollowersRef, {'followerAt': Timestamp.now()});
    }

    // バッチ処理を実行
    await batch.commit();

    // 画面上のフォロー状態を更新
    setState(() {
      _isFollowing = !_isFollowing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'プロフィール'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const Divider(),
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
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final photoUrl = userData['photoUrl'] as String? ?? '';
        final displayName = userData['displayName'] as String? ?? '名無しさん';
        final isCurrentUser = _currentUser.uid == widget.userId;

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
              Expanded(
                child: Column(
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
                    // --- ボタンの表示ロジック ---
                    if (isCurrentUser)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EditProfilePage(),
                            ),
                          );
                        },
                        child: const Text('プロフィールを編集'),
                      )
                    else if (_isLoadingFollowStatus)
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      )
                    else
                      ElevatedButton(
                        onPressed: _handleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.grey[300]
                              : Theme.of(context).primaryColor,
                          foregroundColor: _isFollowing
                              ? Colors.black
                              : Colors.white,
                        ),
                        child: Text(_isFollowing ? 'フォロー中' : 'フォローする'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: Text('まだ投稿がありません。')),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: snapshot.data!.docs.length,

          // _buildUserPostsGridメソッドの中のitemBuilderを修正
          itemBuilder: (context, index) {
            final post = Post.fromFirestore(snapshot.data!.docs[index]);
            return GestureDetector(
              onTap: () => _showPostDetailSheet(post),
              // Stackを使って、画像の上にいいね数を重ねる
              child: Stack(
                alignment: Alignment.bottomRight, // 重ねるウィジェットを右下に配置
                children: [
                  // 背景の画像
                  Image.network(
                    post.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  // いいね数表示の背景
                  Container(
                    margin: const EdgeInsets.all(4.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5), // 半透明の黒
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    // いいねアイコンと数
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // コンテンツのサイズに合わせる
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPostDetailSheet(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostDetailSheet(post: post),
    );
  }
}
