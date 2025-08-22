import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/likes_provider.dart';
import '../../providers/post_provider.dart';
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

class _PostDetailView extends ConsumerStatefulWidget {
  final Post post;
  final bool scrollToComments;
  const _PostDetailView({required this.post, required this.scrollToComments});

  @override
  ConsumerState<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends ConsumerState<_PostDetailView> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final _commentController = TextEditingController();
  final _commentSectionKey = GlobalKey();
  String? _address;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
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
      debugPrint("住所の取得に失敗しました: $e");
    }
  }

  Future<void> _handleLike() async {
    ref.read(likedPostsNotifierProvider.notifier).handleLike(widget.post.id);
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
      // 画像とサムネイルを削除
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

      // 投稿ドキュメントを削除
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿を削除しました。')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('削除中にエラーが発生しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

 // メインのbuildメソッドも以下のように修正してください：

@override
Widget build(BuildContext context) {
  final postAsyncValue = ref.watch(postStreamProvider(widget.post.id));

  return Scaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: Colors.transparent,
    body: Stack( // Columnの代わりにStackを使用
      children: [
        // 背景のグラデーション
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xFF13547a),
                Color(0xFF80d0c7),
              ],
            ),
          ),
        ),
        // メインコンテンツ
        Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      // フローティング風AppBar
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              Expanded(
                                child: Text(
                                  '${widget.post.userName}の投稿',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF13547a),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ];
                  },
                  body: postAsyncValue.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )),
                    error: (err, stack) => Center(
                        child: Text('エラー: $err',
                            style: const TextStyle(color: Colors.white))),
                    data: (realTimePost) => CustomScrollView(
                      slivers: [
                        _buildTopContentCard(realTimePost),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 16)),
                        _buildBottomContentCard(),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 16)),
                        _buildCommentSection(), 
                        _buildEditAndDeleteButtons(),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 80)), // コメント入力分のスペースを確保
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // コメント入力フィールドを画面下部に固定
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildCommentInputField(),
        ),
      ],
    ),
  );
}

Widget _buildCommentInputField() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white, // 白い背景
          borderRadius: BorderRadius.circular(30), // 丸い形
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, -4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'コメントを追加...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  hintStyle: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _postComment,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildHeaderInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green.shade700),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
        ),
      ],
    );
  }


  Widget _buildTopContentCard(Post realTimePost) {
    final isLiked = ref
            .watch(likedPostsNotifierProvider)
            .value
            ?.contains(widget.post.id) ??
        false;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAuthorInfo(),
            const SizedBox(height: 16),
            _buildImagePager(),
            if (widget.post.imageUrls.length > 1) ...[
              const SizedBox(height: 8),
              _buildPageIndicator(),
            ],
            _buildMainInfo(),
            const Divider(),
            _buildActionBar(realTimePost, isLiked),
          ],
        ),
      ),
    );
  }


  Widget _buildBottomContentCard() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8), // 幅を広げる
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('釣果情報'),
            _buildInfoRow(
                Icons.label_outline, 'エギ・ルアー名', widget.post.egiName),
            _buildInfoRow(Icons.business_outlined, 'メーカー', widget.post.egiMaker),
            _buildInfoRow(Icons.scale_outlined, '重さ',
                widget.post.weight != null ? '${widget.post.weight} g' : null),
            _buildSectionTitle('気象情報'),
            _buildInfoRow(Icons.wb_sunny_outlined, '天気', widget.post.weather),
            _buildInfoRow(
                Icons.thermostat_outlined,
                '気温',
                widget.post.airTemperature != null
                    ? '${widget.post.airTemperature} ℃'
                    : null),
            _buildInfoRow(
                Icons.waves_outlined,
                '水温',
                widget.post.waterTemperature != null
                    ? '${widget.post.waterTemperature} ℃'
                    : null),
            _buildSectionTitle('タックル情報'),
            _buildInfoRow(
                Icons.sports_esports_outlined, 'ロッド', widget.post.tackleRod),
            _buildInfoRow(
                Icons.catching_pokemon_outlined, 'リール', widget.post.tackleReel),
            _buildInfoRow(
                Icons.timeline_outlined, 'ライン', widget.post.tackleLine),
            if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
              _buildCaption(),
          ],
        ),
      ),
    );
  }

  // 投稿者情報のWidget
  Widget _buildAuthorInfo() {
    return Row(
      children: [
        // ユーザーアイコンと名前（変更なし）
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MyPage(userId: widget.post.userId),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: (widget.post.userPhotoUrl != null &&
                        widget.post.userPhotoUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(widget.post.userPhotoUrl!)
                    : null,
                child: (widget.post.userPhotoUrl == null ||
                        widget.post.userPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                widget.post.userName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        const Spacer(), // 左と右の要素を離す
        // 位置情報と日時を右側に表示
        if (_address != null) ...[
          _buildHeaderInfo(Icons.location_on, _address!),
          const SizedBox(width: 8),
        ],
        _buildHeaderInfo(Icons.schedule,
            DateFormat('yyyy年M月d日').format(widget.post.createdAt)),
      ],
    );
  }


  // 画像ページャーのWidget
  Widget _buildImagePager() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.post.imageUrls.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: widget.post.imageUrls[index],
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditAndDeleteButtons() {
    final isMyPost = widget.post.userId == _currentUser.uid;
    if (!isMyPost) {
      // 自分の投稿でなければ何も表示しない
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 編集ボタン
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
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => EditPostPage(post: widget.post),
                ));
              },
            ),
            const SizedBox(height: 16),
            // 削除ボタン
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
    );
  }

  // ページインジケーターのWidget
  Widget _buildPageIndicator() {
    return Center(
      child: SmoothPageIndicator(
        controller: _pageController,
        count: widget.post.imageUrls.length,
        effect: WormEffect(
          dotHeight: 8,
          dotWidth: 8,
          activeDotColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  // アクションバー（いいね、コメント）のWidget
  Widget _buildActionBar(Post realTimePost, bool isLiked) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : Colors.grey,
          ),
          onPressed: _handleLike,
        ),
        Text('${realTimePost.likeCount}'),
        const SizedBox(width: 70),
        const Icon(Icons.chat_bubble_outline, color: Colors.grey),
        const SizedBox(width: 4),
        Text('${realTimePost.commentCount}'),
      ],
    );
  }

    Widget _buildMainInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Text(
          "🦑 ${widget.post.squidType} ${widget.post.squidSize} cm",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,color: Color(0xFF13547a)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('地図上で見る'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        const SizedBox(height: 8),
      ],
    );
  }
  
  Widget _buildCaption() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ひとこと'),
        ListTile(
          contentPadding: EdgeInsets.zero,
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
    );
  }

  // コメントセクションのWidget
  Widget _buildCommentSection() {
    return SliverToBoxAdapter(
      child: Container(
        key: _commentSectionKey,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'コメント',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const Divider(height: 24),
            _buildCommentList(),
          ],
        ),
      ),
    );
  }

  // セクションタイトルのWidget
  Widget _buildSectionTitle(String title) {
    return Padding(
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

  // 詳細情報行のWidget
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

  // コメントリストのWidget
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
}