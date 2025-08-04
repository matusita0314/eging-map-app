// lib/features/tournament/tournament_post_detail_page.dart (全面改修後)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account.dart';
import '../../models/comment_model.dart';
import '../../providers/liked_tournament_posts_provider.dart'; 


class TournamentPostDetailPage extends ConsumerStatefulWidget { 
  final String tournamentId;
  final String postId;
  final bool scrollToComments;

  const TournamentPostDetailPage({
    super.key,
    required this.tournamentId,
    required this.postId,
    this.scrollToComments = false,
  });

  @override
  ConsumerState<TournamentPostDetailPage> createState() => _TournamentPostDetailPageState();
}

class _TournamentPostDetailPageState extends ConsumerState<TournamentPostDetailPage> {
  final _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final FocusNode _commentFocusNode = FocusNode();

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
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投稿詳細')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId)
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('投稿が見つかりませんでした。'));
          }

          final postData = snapshot.data!.data() as Map<String, dynamic>;
          final dynamic imageUrlsData = postData['imageUrls'] ?? postData['imageUrl'];
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAuthorInfo(context, postData),
                      if (imageUrlsData.isNotEmpty)
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: PageView.builder(
                            itemCount: imageUrlsData.length,
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: imageUrlsData[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // --- いいねボタン ---
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('tournaments').doc(widget.tournamentId)
                                  .collection('posts').doc(widget.postId)
                                  .collection('likes').doc(_currentUser.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final isLiked = snapshot.hasData && snapshot.data!.exists;
                                return Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey),
                                      onPressed: () => ref.read(likedTournamentPostsNotifierProvider.notifier).handleLike(widget.tournamentId, widget.postId),
                                    ),
                                    Text('${postData['likeCount'] ?? 0}'),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            // --- コメントボタン ---
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                                  onPressed: () {
                                    // ステップ2で作成したFocusNodeを使って入力欄にフォーカスを当てる
                                    _commentFocusNode.requestFocus();
                                  },
                                ),
                                Text('${postData['commentCount'] ?? 0}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (postData['judgedSize'] != null)
                              Text(
                                '判定サイズ: ${postData['judgedSize']} cm',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 32, 158, 78)),
                              ),
                            Text(
                              '投稿日時: ${DateFormat('yyyy.MM.dd HH:mm').format((postData['createdAt'] as Timestamp).toDate())}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            _buildSectionTitle('釣果情報'),
                            _buildInfoRow(Icons.waves, 'イカの種類', postData['squidType']),
                            _buildInfoRow(Icons.label_outline, 'エギ・ルアー名', postData['egiName']),
                            _buildInfoRow(Icons.business_outlined, 'メーカー', postData['egiMaker']),
                            _buildInfoRow(Icons.scale_outlined, '重さ', postData['weight'] != null ? '${postData['weight']} g' : null),

                            _buildSectionTitle('気象情報'),
                            _buildInfoRow(Icons.wb_sunny_outlined, '天気', postData['weather']),
                            _buildInfoRow(Icons.thermostat_outlined, '気温', postData['airTemperature'] != null ? '${postData['airTemperature']} ℃' : null),
                            _buildInfoRow(Icons.waves_outlined, '水温', postData['waterTemperature'] != null ? '${postData['waterTemperature']} ℃' : null),
                            
                            _buildSectionTitle('タックル情報'),
                             _buildInfoRow(Icons.sports_esports_outlined, 'ロッド', postData['tackleRod']),
                            _buildInfoRow(Icons.catching_pokemon_outlined, 'リール', postData['tackleReel']),
                            _buildInfoRow(Icons.timeline_outlined, 'ライン', postData['tackleLine']),

                            if (postData['comment'] != null && postData['comment'].isNotEmpty) ...[
                               _buildSectionTitle('投稿者コメント'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Text('💬', style: TextStyle(fontSize: 24)),
                                title: Text(postData['comment'], style: const TextStyle(height: 1.5)),
                              ),
                            ],

                            const Divider(height: 32),
                            _buildSectionTitle('コメント (${postData['commentCount'] ?? 0})'),
                            _buildCommentList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildCommentInputField(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthorInfo(BuildContext context, Map<String, dynamic> postData) {
     return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => MyPage(userId: postData['userId']),
      )),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: (postData['userPhotoUrl'] != null && postData['userPhotoUrl'].isNotEmpty)
                  ? CachedNetworkImageProvider(postData['userPhotoUrl'])
                  : null,
              child: (postData['userPhotoUrl'] == null || postData['userPhotoUrl'].isEmpty) ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 8),
            Text(postData['userName'], style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments').doc(widget.tournamentId)
          .collection('posts').doc(widget.postId)
          .collection('comments').orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('最初のコメントを投稿しよう！', style: TextStyle(color: Colors.grey))));
        
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final comment = Comment.fromFirestore(snapshot.data!.docs[index]);
            return ListTile(
              leading: CircleAvatar(backgroundImage: comment.userPhotoUrl.isNotEmpty ? NetworkImage(comment.userPhotoUrl) : null, child: comment.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null),
              title: Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(comment.text),
              trailing: Text(DateFormat('MM/dd HH:mm').format(comment.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
  controller: _commentController,
  focusNode: _commentFocusNode,
  decoration: const InputDecoration(hintText: 'コメントを追加...', border: InputBorder.none),
),

            ),
            IconButton(icon: const Icon(Icons.send_rounded, color: Colors.blue), onPressed: _postComment),
          ],
        ),
      ),
    );
  }
}