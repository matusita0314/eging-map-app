import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'common_app_bar.dart';
import 'post_model.dart';
import 'post_detail_page.dart';
import 'my_page.dart';
import 'comment_page.dart';
import 'widgets/post_grid_card.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'ランキング'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('squidSize', descending: true)
            .limit(15)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('requires an index')) {
              return _buildIndexError(context, snapshot.error.toString());
            }
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ランキング対象の投稿がありません。'));
          }

          final docs = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              if (docs.isNotEmpty)
                _TopRankCard(post: Post.fromFirestore(docs[0])),

              const SizedBox(height: 8),

              if (docs.length > 1)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: docs.length - 1,
                  itemBuilder: (context, index) {
                    final post = Post.fromFirestore(docs[index + 1]);
                    final rank = index + 2;
                    return PostGridCard(post: post, rank: rank);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIndexError(BuildContext context, String error) {
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch(error);
    final url = match?.group(0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'データベースの準備が必要です',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'ランキングを表示するには、Firestoreのインデックスを作成する必要があります。以下のリンクを開いて「作成」ボタンを押してください。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (url != null)
              ElevatedButton(
                child: const Text('インデックス作成リンクを開く'),
                onPressed: () {
                  print('Open this URL: $url');
                },
              )
            else
              Text('エラーメッセージからURLを抽出できませんでした。コンソールを確認してください。'),
          ],
        ),
      ),
    );
  }
}

// 1位の投稿を表示するためのカードウィジェット
class _TopRankCard extends StatefulWidget {
  final Post post;
  const _TopRankCard({required this.post});

  @override
  State<_TopRankCard> createState() => _TopRankCardState();
}

class _TopRankCardState extends State<_TopRankCard> {
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailPage(post: widget.post),
        ),
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  widget.post.imageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
                const Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
                const Positioned(
                  top: 16,
                  left: 18,
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'イカ ${widget.post.squidSize} cm',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      'ヒットエギ: ${widget.post.egiName}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MyPage(userId: widget.post.userId),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.post.userPhotoUrl.isNotEmpty
                              ? NetworkImage(widget.post.userPhotoUrl)
                              : null,
                          child: widget.post.userPhotoUrl.isEmpty
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.post.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!isMyPost && !_isLoadingFollow)
                    SizedBox(
                      height: 28,
                      child: ElevatedButton(
                        onPressed: _handleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.blue
                              : Colors.white,
                          foregroundColor: _isFollowing
                              ? Colors.white
                              : Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Colors.blue.withOpacity(0.5),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                        ),
                        child: Text(
                          _isFollowing ? 'フォロー中' : '+ フォロー',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey,
                    ),
                    onPressed: _handleLike,
                  ),
                  Text('$_likeCount'),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CommentPage(post: widget.post),
                      ),
                    ),
                  ),
                  Text('${widget.post.commentCount}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2位以下の投稿を表示するためのカードウィジェット
class _RankingGridCard extends StatefulWidget {
  final Post post;
  final int rank;
  const _RankingGridCard({required this.post, required this.rank});

  @override
  State<_RankingGridCard> createState() => _RankingGridCardState();
}

class _RankingGridCardState extends State<_RankingGridCard> {
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
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PostDetailPage(post: widget.post),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.post.imageUrl,
                    fit: BoxFit.cover, // 画像を領域いっぱいに表示
                  ),
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              'イカ ${widget.post.squidSize} cm',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MyPage(userId: widget.post.userId),
                    ),
                  ),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isMyPost && !_isLoadingFollow)
                  SizedBox(
                    height: 24,
                    child: ElevatedButton(
                      onPressed: _handleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? Colors.blue
                            : Colors.white,
                        foregroundColor: _isFollowing
                            ? Colors.white
                            : Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        elevation: 0,
                      ),
                      child: Text(
                        _isFollowing ? 'フォロー中' : '+ フォロー',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentPage(post: widget.post),
                    ),
                  ),
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
    );
  }
}
