import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'post_model.dart';
import 'my_page.dart';
import 'comment_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class PostDetailPage extends StatelessWidget {
  final Post post;
  final bool scrollToComments;
  const PostDetailPage({
    super.key,
    required this.post,
    this.scrollToComments = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${post.userName}の投稿')),
      body: _PostDetailCard(post: post, scrollToComments: scrollToComments),
    );
  }
}

class _PostDetailCard extends StatefulWidget {
  final Post post;
  final bool scrollToComments;
  const _PostDetailCard({required this.post, this.scrollToComments = false});

  @override
  State<_PostDetailCard> createState() => _PostDetailCardState();
}

class _PostDetailCardState extends State<_PostDetailCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final _commentSectionKey = GlobalKey();
  String? _address;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _checkIfLiked();
    _getAddressFromLatLng();

    if (widget.scrollToComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToComments();
      });
    }
  }

  void _scrollToComments() {
    Scrollable.ensureVisible(
      _commentSectionKey.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  Future<void> _getAddressFromLatLng() async {
    try {
      // 緯度経度からPlacemark（場所情報）のリストを取得
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.post.location.latitude,
        widget.post.location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        // 取得した情報から住所を組み立てる
        // 例: "石川県 金沢市"
        setState(() {
          _address =
              '${place.administrativeArea ?? ''} ${place.locality ?? ''} ${place.street ?? ''}';
        });
      }
    } catch (e) {
      print("住所の取得に失敗しました: $e");
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

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments');

    await commentRef.add({
      'text': text,
      'userId': _currentUser.uid,
      'userName': _currentUser.displayName ?? '名無しさん',
      'userPhotoUrl': _currentUser.photoURL ?? '',
      'createdAt': Timestamp.now(),
    });

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .update({'commentCount': FieldValue.increment(1)});

    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    // タップされたら、そのユーザーのIDを使ってMyPageに移動
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MyPage(userId: widget.post.userId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: widget.post.userPhotoUrl.isNotEmpty
                              ? NetworkImage(widget.post.userPhotoUrl)
                              : null,
                          child: widget.post.userPhotoUrl.isEmpty
                              ? const Icon(Icons.person)
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
                ),
                Image.network(
                  widget.post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
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
                      const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${widget.post.commentCount}'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'イカ ${widget.post.squidSize} cm',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '投稿日時: ${DateFormat('yyyy.MM.dd HH:mm').format(widget.post.createdAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_address != null) // 住所が取得できたら表示
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _address!,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      _buildSectionTitle('釣果情報'),
                      _buildInfoRow(
                        Icons.label_outline,
                        'エギ・ルアー名',
                        widget.post.egiName,
                      ),
                      _buildInfoRow(
                        Icons.business_outlined,
                        'メーカー',
                        widget.post.egiMaker,
                      ),
                      _buildInfoRow(
                        Icons.scale_outlined,
                        '重さ',
                        widget.post.weight?.toString(),
                      ),
                      _buildSectionTitle('気象情報'),
                      _buildInfoRow(
                        Icons.wb_sunny_outlined,
                        '天気',
                        widget.post.weather,
                      ),
                      _buildInfoRow(
                        Icons.thermostat_outlined,
                        '気温',
                        widget.post.airTemperature?.toString(),
                      ),
                      _buildInfoRow(
                        Icons.waves_outlined,
                        '水温',
                        widget.post.waterTemperature?.toString(),
                      ),
                      _buildSectionTitle('タックル情報'),
                      _buildInfoRow(
                        Icons.sports_esports_outlined,
                        'ロッド',
                        widget.post.tackleRod,
                      ),
                      _buildInfoRow(
                        Icons.catching_pokemon_outlined,
                        'リール',
                        widget.post.tackleReel,
                      ),
                      _buildInfoRow(
                        Icons.timeline_outlined,
                        'ライン',
                        widget.post.tackleLine,
                      ),
                      if (widget.post.caption != null &&
                          widget.post.caption!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('ひとこと'),
                            ListTile(
                              leading: const Text(
                                '💬',
                                style: TextStyle(fontSize: 24),
                              ),
                              title: Text(
                                widget.post.caption!,
                                style: const TextStyle(height: 1.5), // 行間を少し広げる
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildSectionTitle('コメント'),
                ),
                _buildCommentList(),
              ],
            ),
          ),
        ),
        _buildCommentInputField(),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(
            (label.contains('℃') || label.contains('g'))
                ? value
                : '$value ${label.contains("気温") || label.contains("水温")
                      ? "℃"
                      : label.contains("重さ")
                      ? "g"
                      : ""}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '最初のコメントを投稿しよう！',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final comment = Comment.fromFirestore(snapshot.data!.docs[index]);
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: comment.userPhotoUrl.isNotEmpty
                    ? NetworkImage(comment.userPhotoUrl)
                    : null,
                child: comment.userPhotoUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                comment.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(comment.text),
              trailing: Text(
                DateFormat('MM/dd HH:mm').format(comment.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'コメントを追加...',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.blue),
              onPressed: _postComment,
            ),
          ],
        ),
      ),
    );
  }
}
