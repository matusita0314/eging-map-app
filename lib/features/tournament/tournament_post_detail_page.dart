import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'edit_tournament_post_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tournament_model.dart';
import '../account/account.dart';
import '../../models/comment_model.dart';
import '../../providers/liked_tournament_posts_provider.dart';

class TournamentPostDetailPage extends ConsumerStatefulWidget {
  final Tournament tournament;
  final String tournamentId;
  final String postId;
  final bool scrollToComments;

  const TournamentPostDetailPage({
    super.key,
    required this.tournament,
    required this.tournamentId,
    required this.postId,
    this.scrollToComments = false,
  });

  @override
  ConsumerState<TournamentPostDetailPage> createState() =>
      _TournamentPostDetailPageState();
}

class _TournamentPostDetailPageState
    extends ConsumerState<TournamentPostDetailPage> {
  final _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final FocusNode _commentFocusNode = FocusNode();
  final _pageController = PageController();
  final _commentSectionKey = GlobalKey(); // ★ コメントセクションへのスクロール用

  @override
  void initState() {
    super.initState();
    // ★ コメントへスクロールするロジック
    if (widget.scrollToComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToComments();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
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
      // ★ スクロール後にフォーカスを当てる
      FocusScope.of(context).requestFocus(_commentFocusNode);
    }
  }

  Future<void> _onDeletePressed(Map<String, dynamic> postData) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿の削除'),
        content: const Text('この投稿を本当に削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final imageUrls =
          (postData['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
      for (final url in imageUrls) {
        if (url.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(url).delete();
        }
      }

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('posts')
          .doc(widget.postId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿を削除しました。')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('削除中にエラーが発生しました: $e')));
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final postRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('posts')
        .doc(widget.postId);
    final commentRef = postRef.collection('comments');
    await commentRef.add({
      'text': text,
      'userId': _currentUser.uid,
      'userName': _currentUser.displayName ?? '名無しさん',
      'userPhotoUrl': _currentUser.photoURL ?? '',
      'createdAt': Timestamp.now(),
    });
    await postRef.update({'commentCount': FieldValue.increment(1)});
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId)
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('投稿が見つかりませんでした。'));
          }
          final postData = snapshot.data!.data() as Map<String, dynamic>;
          final isMyPost = postData['userId'] == _currentUser.uid;

          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF13547a), Color(0xFF80d0c7)],
                  ),
                ),
              ),
              // ★ メインコンテンツ
              SafeArea(
                bottom: false, // 下のSafeAreaは入力欄側で考慮
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    // ★ フローティングAppBar
                    return [
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
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(children: [
                            IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).pop()),
                            Expanded(
                              child: Text('投稿詳細',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF13547a))),
                            ),
                            const SizedBox(width: 48)
                          ]),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ];
                  },
                  // ★ メインのスクロール部分
                  body: CustomScrollView(
                    slivers: [
                      _buildContentCard(postData),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      _buildCommentSection(postData),
                      if (isMyPost) _buildEditAndDeleteButtons(postData),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)), // 入力欄とのスペース
                    ],
                  ),
                ),
              ),
              // ★ 画面下部に固定されるコメント入力欄
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildCommentInputField(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ★ post_detail_page.dart からコピーしてきたコメント入力ウィジェット
  Widget _buildCommentInputField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
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
                  focusNode: _commentFocusNode, // ★ FocusNodeを適用
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'コメントを追加...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                    color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                  onPressed: _postComment,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ★ コンテンツをカードにまとめる
  Widget _buildContentCard(Map<String, dynamic> postData) {
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
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAuthorInfo(context, postData),
            const SizedBox(height: 16),
            _buildPostImages(postData),
            const Divider(),
            _buildActionButtons(postData),
            const Divider(),
            const SizedBox(height: 8),
            // ★ 大会種類によってUIを切り替えるロジックはここに集約
            _buildDynamicContent(postData),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  // ★ コメントセクションをカードにまとめる
  Widget _buildCommentSection(Map<String, dynamic> postData) {
    return SliverToBoxAdapter(
       key: _commentSectionKey, // ★ スクロール用のキー
       child: Container(
         margin: const EdgeInsets.symmetric(horizontal: 8),
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: Colors.white.withOpacity(0.98),
           borderRadius: BorderRadius.circular(20),
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            _buildSectionTitle('コメント (${postData['commentCount'] ?? 0})'),
            const Divider(height: 24),
            _buildCommentList(),
           ],
         ),
       ),
    );
  }

  Widget _buildEditAndDeleteButtons(Map<String, dynamic> postData) {
     return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                 // DocumentSnapshotを渡すために、StreamBuilderの外から参照する必要がある
                 // ここでは仮でFirestoreから再取得するが、上位のStreamBuilderから渡すのが望ましい
                 FirebaseFirestore.instance
                    .collection('tournaments').doc(widget.tournamentId)
                    .collection('posts').doc(widget.postId).get().then((postSnapshot) {
                      if (postSnapshot.exists) {
                         Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => EditTournamentPostPage(
                            tournament: widget.tournament,
                            post: postSnapshot,
                          ),
                        ));
                      }
                 });
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
              onPressed: () => _onDeletePressed(postData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicContent(Map<String, dynamic> postData) {
    final metric = widget.tournament.rule.metric;
    if (metric == 'SIZE' || metric == 'COUNT') {
      return _buildMainTournamentDetail(postData);
    } else if (metric == 'LIKE_COUNT') {
      if (widget.tournament.name.contains("料理")) {
        return _buildCookingContestDetail(postData);
      } else if (widget.tournament.name.contains("タックル")) {
        return _buildTackleContestDetail(postData);
      }
    }
    return const Center(child: Text('投稿タイプを判別できませんでした。'));
  }

  Widget _buildMainTournamentDetail(Map<String, dynamic> postData) {
    final metric = widget.tournament.rule.metric;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metric == 'SIZE' && postData['judgedSize'] != null)
          Text('判定サイズ: ${postData['judgedSize']} cm',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
        if (metric == 'COUNT' && postData['judgedCount'] != null)
          Text('判定匹数: ${postData['judgedCount']} 匹',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green)),
        _buildSectionTitle('釣果情報'),
        _buildInfoRow(Icons.waves, 'イカの種類', postData['squidType']),
        _buildInfoRow(Icons.label_outline, 'エギ・ルアー名', postData['egiName']),
        _buildInfoRow(Icons.wb_sunny_outlined, '天気', postData['weather']),
        _buildInfoRow(Icons.thermostat_outlined, '気温',
            postData['airTemperature'] != null ? '${postData['airTemperature']} ℃' : null),
        _buildInfoRow(Icons.waves_outlined, '水温',
            postData['waterTemperature'] != null ? '${postData['waterTemperature']} ℃' : null),
        _buildSectionTitle('タックル情報'),
        _buildInfoRow(
            Icons.sports_esports_outlined, 'ロッド', postData['tackleRod']),
        _buildInfoRow(
            Icons.catching_pokemon_outlined, 'リール', postData['tackleReel']),
        _buildInfoRow(Icons.timeline_outlined, 'ライン', postData['tackleLine']),
      ],
    );
  }

  Widget _buildCookingContestDetail(Map<String, dynamic> postData) {
    final ingredients =
        (postData['ingredients'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('材料'),
        if (ingredients.isEmpty)
          const Text('材料情報がありません。')
        else
          for (var item in ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Text("・${item['name']}",style: TextStyle(fontWeight:FontWeight.bold)),
                  const SizedBox(width: 16.0), 
                  Text(item['quantity']),
                ],
              ),
            ),
        _buildSectionTitle('調理工程'),
        Text(postData['process'] ?? '記載なし', style: const TextStyle(height: 1.5)),
        _buildSectionTitle('感想'),
        Text(postData['impression'] ?? '記載なし',
            style: const TextStyle(height: 1.5)),
      ],
    );
  }

  Widget _buildTackleContestDetail(Map<String, dynamic> postData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('使用タックル'),
        _buildInfoRow(
            Icons.sports_esports_outlined, 'ロッド', postData['tackleRod']),
        _buildInfoRow(
            Icons.catching_pokemon_outlined, 'リール', postData['tackleReel']),
        _buildInfoRow(Icons.label_outline, 'ルアー', postData['lure']),
        _buildInfoRow(Icons.timeline_outlined, 'ライン', postData['tackleLine']),
        _buildSectionTitle('アピールポイント'),
        Text(postData['appealPoint'] ?? '記載なし',
            style: const TextStyle(height: 1.5)),
      ],
    );
  }

  Widget _buildAuthorInfo(
      BuildContext context, Map<String, dynamic> postData) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => MyPage(userId: postData['userId']))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: (postData['userPhotoUrl'] != null &&
                      postData['userPhotoUrl'].isNotEmpty)
                  ? CachedNetworkImageProvider(postData['userPhotoUrl'])
                  : null,
              child: (postData['userPhotoUrl'] == null ||
                      postData['userPhotoUrl'].isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(postData['userName'],
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImages(Map<String, dynamic> postData) {
    final imageUrls =
        (postData['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: PageView.builder(
            controller: _pageController,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrls[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              );
            },
          ),
        ),
        if (imageUrls.length > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: imageUrls.length,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> postData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // いいねボタン
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tournaments')
                .doc(widget.tournamentId)
                .collection('posts')
                .doc(widget.postId)
                .collection('likes')
                .doc(_currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final isLiked = snapshot.hasData && snapshot.data!.exists;
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey),
                    onPressed: () => ref
                        .read(likedTournamentPostsNotifierProvider.notifier)
                        .handleLike(widget.tournamentId, widget.postId),
                  ),
                  Text('${postData['likeCount'] ?? 0}'),
                ],
              );
            },
          ),
          const SizedBox(width: 70),
          // コメントボタン
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                onPressed: _scrollToComments,
              ),
              Text('${postData['commentCount'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey)),
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
          Expanded(
            child: Text(
              (value != null && value.isNotEmpty) ? value : '情報なし',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('最初のコメントを投稿しよう！',
                      style: TextStyle(color: Colors.grey))));
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
                      : null),
              title: Text(comment.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(comment.text),
              trailing: Text(DateFormat('MM/dd HH:mm').format(comment.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            );
          },
        );
      },
    );
  }
}