// lib/widgets/post_grid_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../post_model.dart';
import '../my_page.dart';
import '../post_detail_page.dart';
import '../comment_page.dart';

class PostGridCard extends StatefulWidget {
  final Post post;
  // ランキング表示用に順位をオプションで受け取る
  final int? rank;

  const PostGridCard({super.key, required this.post, this.rank});

  @override
  State<PostGridCard> createState() => _PostGridCardState();
}

class _PostGridCardState extends State<PostGridCard> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isFollowing = false;
  bool _isLoadingFollow = true;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _checkIfLiked();
    _checkIfFollowing();
  }

  // いいね状態を確認する
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

  // フォロー状態を確認する
  Future<void> _checkIfFollowing() async {
    if (widget.post.userId == _currentUser.uid) {
      setState(() => _isLoadingFollow = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('following')
        .doc(widget.post.userId)
        .get();
    if (mounted) {
      setState(() {
        _isFollowing = doc.exists;
        _isLoadingFollow = false;
      });
    }
  }

  // いいね処理
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

  // フォロー処理
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
            // 画像とユーザー情報、フォローボタン、ランキング表示
            SizedBox(
              // ExpandedをSizedBoxに変更し、高さを制限
              height: 250, // ここで画像の表示高さを調整 (例: 150px)
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(widget.post.imageUrl, fit: BoxFit.cover),
                  // ユーザー情報
                  Positioned(
                    bottom: 20,
                    left: 8,
                    child: GestureDetector(
                      onTap: () {
                        // ユーザーアイコンや名前をタップした場合はマイページへ
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                MyPage(userId: widget.post.userId),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: widget.post.userPhotoUrl.isNotEmpty
                                ? NetworkImage(widget.post.userPhotoUrl)
                                : null,
                            child: widget.post.userPhotoUrl.isEmpty
                                ? const Icon(Icons.person, size: 12)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.post.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // フォローボタン
                  if (!isMyPost && !_isLoadingFollow)
                    Positioned(
                      bottom: 4,
                      right: 8,
                      child: SizedBox(
                        height: 26,
                        child: ElevatedButton(
                          onPressed: _handleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? Colors.blue
                                : Colors.white.withOpacity(0.9),
                            foregroundColor: _isFollowing
                                ? Colors.white
                                : Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.blue.withOpacity(0.5),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            elevation: 1,
                          ),
                          child: Text(
                            _isFollowing ? 'フォロー中' : '+ フォロー',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // ランキング表示
                  if (widget.rank != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.rank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 釣果情報
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'イカ ${widget.post.squidSize} cm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ヒットエギ: ${widget.post.egiName}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.post.caption != null &&
                      widget.post.caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '🔦 ${widget.post.caption!}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // いいね・コメント数
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // いいねボタン
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          // scrollToCommentsフラグをtrueにしてページ遷移
                          builder: (context) => PostDetailPage(
                            post: widget.post,
                            scrollToComments: true,
                          ),
                        ),
                      );
                    },
                  ),
                  Text('$_likeCount', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  // コメントボタン
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey,
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
