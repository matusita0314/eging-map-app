import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import '../models/post_model.dart';
import 'my_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comment_page.dart';
import '../widgets/post_detail_page.dart';
import '../widgets/post_grid_card.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _CustomTabSwitcher(
            selectedIndex: _selectedTabIndex,
            onTabSelected: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: const [
          _TodayTimeline(),
          Center(child: Text('現在、お知らせはありません。')),
        ],
      ),
    );
  }
}

class _CustomTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  const _CustomTabSwitcher({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 220,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              width: 110,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildTabItem(context, 'Today', 0),
              _buildTabItem(context, 'お知らせ', 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String title, int index) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayTimeline extends StatelessWidget {
  const _TodayTimeline();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('createdAt', isGreaterThanOrEqualTo: startOfToday)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('今日の投稿はまだありません。'));
        }
        final docs = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            // ▼▼▼ 縦横比を調整して、カードの高さを低くする ▼▼▼
            childAspectRatio: 1.0,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = Post.fromFirestore(docs[index]);
            return PostGridCard(post: post);
          },
        );
      },
    );
  }
}

class _TimelineGridCard extends StatefulWidget {
  final Post post;
  const _TimelineGridCard({required this.post});

  @override
  State<_TimelineGridCard> createState() => _TimelineGridCardState();
}

class _TimelineGridCardState extends State<_TimelineGridCard> {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ▼▼▼ 画像部分をタップすると詳細ページへ ▼▼▼
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PostDetailPage(post: widget.post),
                  ),
                );
              },
              child: Image.network(
                widget.post.imageUrl,
                fit: BoxFit.contain, // 画像全体を表示
                width: double.infinity,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ▼▼▼ ユーザー情報とフォローボタン ▼▼▼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                GestureDetector(
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
                          side: const BorderSide(color: Colors.blue),
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
          // ▼▼▼ いいね・コメントボタン ▼▼▼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
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
    );
  }
}
