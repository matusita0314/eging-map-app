// lib/widgets/post_grid_card.dart (修正版)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../pages/my_page.dart';
import '../pages/post_detail_page.dart';

class PostGridCard extends StatefulWidget {
  final Post post;
  final int? rank;
  final bool isLikedByCurrentUser;
  final bool isSavedByCurrentUser;
  final bool isFollowingAuthor;

  const PostGridCard({
    super.key,
    required this.post,
    this.rank,
    required this.isLikedByCurrentUser,
    required this.isSavedByCurrentUser,
    required this.isFollowingAuthor,
  });

  @override
  State<PostGridCard> createState() => _PostGridCardState();
}

class _PostGridCardState extends State<PostGridCard> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  late bool _isLiked;
  late bool _isSaved;
  late bool _isFollowing;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLikedByCurrentUser;
    _isSaved = widget.isSavedByCurrentUser;
    _isFollowing = widget.isFollowingAuthor;
    _likeCount = widget.post.likeCount;
  }

  // --- いいね、保存、フォローの各メソッドは変更なし ---
  Future<void> _handleSave() async {
    setState(() => _isSaved = !_isSaved);
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('saved_posts')
        .doc(widget.post.id);
    _isSaved ? await ref.set({'savedAt': Timestamp.now()}) : await ref.delete();
  }

  Future<void> _handleLike() async {
    setState(() {
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
    final likedPostRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('liked_posts')
        .doc(widget.post.id);
    final batch = FirebaseFirestore.instance.batch();

    if (_isLiked) {
      batch.set(likedPostRef, {'likedAt': Timestamp.now()});
      batch.update(postRef, {'likeCount': FieldValue.increment(1)});
    } else {
      batch.delete(likedPostRef);
      batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  Future<void> _handleFollow() async {
    setState(() => _isFollowing = !_isFollowing);
    final batch = FirebaseFirestore.instance.batch();
    final myFollowingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('following')
        .doc(widget.post.userId);
    final theirFollowersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.userId)
        .collection('followers')
        .doc(_currentUser.uid);

    if (_isFollowing) {
      batch.set(myFollowingRef, {'followedAt': Timestamp.now()});
      batch.set(theirFollowersRef, {'followerAt': Timestamp.now()});
    } else {
      batch.delete(myFollowingRef);
      batch.delete(theirFollowersRef);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final isMyPost = _currentUser.uid == widget.post.userId;
    // ▼▼▼ 変更点: 画面サイズを取得 ▼▼▼
    final screenSize = MediaQuery.of(context).size;
    final isLargeCard = widget.rank == 1; // 1位のカードかどうかを判定

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailPage(post: widget.post),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ▼▼▼ 変更点: 画像表示部分をExpandedでラップし、比率を確保 ▼▼▼
            Expanded(
              flex: 3, // 画像エリアの比率を3に設定
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ▼▼▼ 変更点: サムネイルURLを優先的に使用 ▼▼▼
                  Image.network(
                    // サムネイルがあればそれを、なければ元の画像URLを使う
                    widget.post.thumbnailUrl.isNotEmpty
                        ? widget.post.thumbnailUrl
                        : widget.post.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.error, color: Colors.grey),
                  ),
                  // --- 投稿者情報 ---
                  Positioned(
                    bottom: 3,
                    left: 3,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              MyPage(userId: widget.post.userId),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            // ▼▼▼ 変更点: サイズを画面幅に応じて調整 ▼▼▼
                            radius: isLargeCard ? 20 : 14,
                            backgroundImage: widget.post.userPhotoUrl.isNotEmpty
                                ? NetworkImage(widget.post.userPhotoUrl)
                                : null,
                            child: widget.post.userPhotoUrl.isEmpty
                                ? Icon(
                                    Icons.person,
                                    size: isLargeCard ? 24 : 18,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.post.userName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              // ▼▼▼ 変更点: サイズを画面幅に応じて調整 ▼▼▼
                              fontSize: isLargeCard ? 16 : 11,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // --- フォローボタン ---
                  if (!isMyPost)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ElevatedButton(
                        onPressed: _handleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.white.withOpacity(0.9)
                              : Colors.blue,
                          foregroundColor: _isFollowing
                              ? Colors.blue
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: Colors.blue.withOpacity(0.5),
                            ),
                          ),
                          // ▼▼▼ 変更点: paddingを調整 ▼▼▼
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap, // ボタンの高さを詰める
                          minimumSize: const Size(0, 30), // 最小高さを設定
                        ),
                        child: Text(
                          _isFollowing ? 'フォロー中' : '+ フォロー',
                          style: TextStyle(
                            // ▼▼▼ 変更点: サイズを調整 ▼▼▼
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // --- ランキング表示 ---
                  if (widget.rank != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '${widget.rank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: ClipOval(
                      // インクエフェクト（波紋）が円形になるようにします
                      child: Material(
                        color: Colors.grey.withOpacity(0.7), // 背景色
                        child: InkWell(
                          onTap: _handleSave,
                          child: Padding(
                            // ★★★ このpaddingで円の大きさが変わります ★★★
                            padding: const EdgeInsets.all(5), // この数値を変更してください

                            child: Icon(
                              _isSaved ? Icons.bookmark : Icons.bookmark_border,
                              color: _isSaved
                                  ? Colors.lightBlueAccent
                                  : Colors.white,
                              size: 24, // アイコン自体の大きさ
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ▼▼▼ 変更点: 情報表示部分をExpandedでラップし、比率を確保 ▼▼▼
            Expanded(
              flex: 2, // 情報エリアの比率を2に設定
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 要素を均等に配置
                  children: [
                    // --- 釣果情報 ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'イカ ${widget.post.squidSize} cm',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isLargeCard ? 16 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ヒットエギ: ${widget.post.egiName}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: isLargeCard ? 13 : 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // --- アイコンボタン ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildActionButton(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          _isLiked ? Colors.red : Colors.grey,
                          _likeCount,
                          _handleLike,
                        ),
                        const SizedBox(width: 0), // 少し間隔を広げる
                        _buildActionButton(
                          Icons.chat_bubble_outline,
                          Colors.grey,
                          widget.post.commentCount,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PostDetailPage(
                                  post: widget.post,
                                  scrollToComments: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ▼▼▼ 追加: アイコンボタンを生成するヘルパーメソッド ▼▼▼
  Widget _buildActionButton(
    IconData icon,
    Color color,
    int? count,
    VoidCallback onPressed,
  ) {
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(icon, color: color, size: 22),
          onPressed: onPressed,
        ),
        if (count != null)
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }
}
