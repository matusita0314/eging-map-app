import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../pages/my_page.dart';
import '../pages/post_detail_page.dart';

class PostGridCard extends StatefulWidget {
  final Post post;
  final int? rank;
  // ▼▼▼ 親から状態を受け取るためのプロパティを追加 ▼▼▼
  final bool isLikedByCurrentUser;
  final bool isSavedByCurrentUser;
  final bool isFollowingAuthor;

  const PostGridCard({
    super.key,
    required this.post,
    this.rank,
    // ▼▼▼ コンストラクタで状態を受け取る ▼▼▼
    required this.isLikedByCurrentUser,
    required this.isSavedByCurrentUser,
    required this.isFollowingAuthor,
  });

  @override
  State<PostGridCard> createState() => _PostGridCardState();
}

class _PostGridCardState extends State<PostGridCard> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // ▼▼▼ 親から渡された初期状態で変数を初期化 ▼▼▼
  late bool _isLiked;
  late bool _isSaved;
  late bool _isFollowing;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    // ▼▼▼ Stateの初期化を、親から渡された値で行う ▼▼▼
    _isLiked = widget.isLikedByCurrentUser;
    _isSaved = widget.isSavedByCurrentUser;
    _isFollowing = widget.isFollowingAuthor;
    _likeCount = widget.post.likeCount;
    // ▼▼▼ これで、このウィジェット内でのFirestoreへの問い合わせは不要になった ▼▼▼
  }

  // ▼▼▼ 以下、いいね・保存・フォローの「実行」メソッドは変更なし ▼▼▼

  Future<void> _handleSave() async {
    // UIを即時反映
    setState(() {
      _isSaved = !_isSaved;
    });

    final savedDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('saved_posts')
        .doc(widget.post.id);

    if (_isSaved) {
      await savedDocRef.set({'savedAt': Timestamp.now()});
    } else {
      await savedDocRef.delete();
    }
  }

  Future<void> _handleLike() async {
    // UIを即時反映
    setState(() {
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);

    // ▼▼▼ 新しい「いいね」の保存場所を参照 ▼▼▼
    final likedPostRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('liked_posts') // users/{userID}/liked_posts/
        .doc(widget.post.id);

    // ▼▼▼ バッチ処理で2つの書き込みを同時に行う ▼▼▼
    final batch = FirebaseFirestore.instance.batch();

    if (_isLiked) {
      // 新しい構造に「いいね」を記録
      batch.set(likedPostRef, {'likedAt': Timestamp.now()});
      // 投稿のlikeCountを増やす
      batch.update(postRef, {'likeCount': FieldValue.increment(1)});
    } else {
      // 新しい構造から「いいね」を削除
      batch.delete(likedPostRef);
      // 投稿のlikeCountを減らす
      batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
    }

    // バッチ処理を実行
    try {
      await batch.commit();
    } catch (e) {
      // エラーが発生した場合はUIを元に戻すなどの処理も検討できる
      print('いいね処理のエラー: $e');
    }
  }

  Future<void> _handleFollow() async {
    // UIを即時反映
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
            SizedBox(
              height: 230,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(widget.post.imageUrl, fit: BoxFit.cover),
                  Positioned(
                    bottom: 20,
                    left: 8,
                    child: GestureDetector(
                      onTap: () {
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
                            radius: 20,
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
                  // ▼▼▼ _isLoadingFollowの判定を削除 ▼▼▼
                  if (!isMyPost)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: SizedBox(
                        height: 40,
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
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
                  SizedBox(
                    height: 22,
                    child:
                        (widget.post.caption != null &&
                            widget.post.caption!.isNotEmpty)
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '📢 ${widget.post.caption!}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey,
                      size: 25,
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
                      color: Colors.grey,
                      size: 25,
                    ),
                    onPressed: () {
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
                  Text(
                    '${widget.post.commentCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: _isSaved ? Colors.blue : Colors.grey,
                      size: 25,
                    ),
                    onPressed: _handleSave,
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
