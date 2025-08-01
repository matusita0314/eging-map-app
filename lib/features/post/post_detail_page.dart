// lib/features/post/post_detail_page.dart (完全版)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../map/map_page.dart';
import '../../models/comment_model.dart';
import '../../models/post_model.dart';
import '../account/account.dart';
import 'edit_post_page.dart';

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
    return _PostDetailView(post: post, scrollToComments: scrollToComments);
  }
}

class _PostDetailView extends StatefulWidget {
  final Post post;
  final bool scrollToComments;
  const _PostDetailView({required this.post, required this.scrollToComments});

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  bool _isLiked = false;
  int _likeCount = 0;
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final _commentSectionKey = GlobalKey();
  String? _address;
  final _pageController = PageController();

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

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _scrollToComments() {
    if (_commentSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _commentSectionKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.post.location.latitude,
        widget.post.location.longitude,
      );
      if (mounted && placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        setState(() {
          _address =
              '${place.country ?? ''}${' '}${place.administrativeArea ?? ''}';
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
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
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

    final commentRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments');
    await commentRef.add({
      'text': text,
      'userId': _currentUser.uid,
      'userName': _currentUser.displayName ?? '名無しさん',
      'userPhotoUrl': _currentUser.photoURL ?? '',
      'createdAt': Timestamp.now(),
    });

    await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({'commentCount': FieldValue.increment(1)});

    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _onDeletePressed() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('投稿の削除'),
          content: const Text('この投稿を本当に削除しますか？\nこの操作は元に戻せません。'),
          actions: <Widget>[
            TextButton(
                child: const Text('キャンセル'),
                onPressed: () => Navigator.of(context).pop(false)),
            TextButton(
                child: const Text('削除', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      for (final imageUrl in widget.post.imageUrls) {
        if (imageUrl.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        }
      }
      for (final thumbnailUrl in widget.post.thumbnailUrls) {
        if (thumbnailUrl.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(thumbnailUrl).delete();
        }
      }

      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿を削除しました。')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('削除中にエラーが発生しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMyPost = widget.post.userId == _currentUser.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.post.userName}の投稿'),
        actions: [
          if (isMyPost)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => EditPostPage(post: widget.post)));
                } else if (value == 'delete') {
                  _onDeletePressed();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit', child: Text('編集')),
                const PopupMenuItem<String>(
                    value: 'delete', child: Text('削除')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: (widget.post.userPhotoUrl != null &&
                                    widget.post.userPhotoUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(
                                    widget.post.userPhotoUrl!)
                                : null,
                            child: (widget.post.userPhotoUrl == null ||
                                    widget.post.userPhotoUrl!.isEmpty)
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
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.post.imageUrls.length,
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: widget.post.imageUrls[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                  if (widget.post.imageUrls.length > 1)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: widget.post.imageUrls.length,
                          effect: WormEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                            activeDotColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
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
                        // ▼▼▼【修正】ここからレイアウトを整理 ▼▼▼
                        Text(
                          '${widget.post.squidType} ${widget.post.squidSize} cm',
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
                        if (_address != null)
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
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('地図上で見る'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Theme.of(context).primaryColor,
                            backgroundColor:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => MapPage(
                                focusedPostId: widget.post.id,
                                initialFocusLocation: widget.post.location,
                              ),
                            ));
                          },
                        ),
                        // ▲▲▲ ここまで ▲▲▲
                        
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
                          widget.post.weight != null
                              ? '${widget.post.weight} g'
                              : null,
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
                          widget.post.airTemperature != null
                              ? '${widget.post.airTemperature} ℃'
                              : null,
                        ),
                        _buildInfoRow(
                          Icons.waves_outlined,
                          '水温',
                          widget.post.waterTemperature != null
                              ? '${widget.post.waterTemperature} ℃'
                              : null,
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
                                  style: const TextStyle(height: 1.5),
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
                    child: _buildSectionTitle('コメント', key: _commentSectionKey),
                  ),
                  _buildCommentList(),
                  if (isMyPost)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('この投稿を編集する'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blue,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditPostPage(post: widget.post),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('この投稿を削除する'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.red.shade600,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _onDeletePressed,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildCommentInputField(),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: Colors.grey.shade800)),
          const Spacer(),
          Text(
            (value != null && value.isNotEmpty) ? value : '情報なし',
            style: (value != null && value.isNotEmpty)
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                : TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
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