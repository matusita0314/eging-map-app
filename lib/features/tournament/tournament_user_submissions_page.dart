import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'tournament_post_detail_page.dart';

class TournamentUserSubmissionsPage extends StatelessWidget {
  final String tournamentId;
  final String userId;
  final String userName;

  const TournamentUserSubmissionsPage({
    super.key,
    required this.tournamentId,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${userName}の投稿'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournamentId)
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'approved')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('このユーザーの承認済み投稿はありません。'));
          }
          final posts = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final postData = post.data() as Map<String, dynamic>;

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => TournamentPostDetailPage(
                      tournamentId: tournamentId,
                      postId: post.id,
                    ),
                  ));
                },
                child: _TournamentPostCard(postData: postData), // 以前作成したカードを再利用
              );
            },
          );
        },
      ),
    );
  }
}

// ★ tournament_dashboard.dart からコピーしてきた専用カードウィジェット
class _TournamentPostCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  const _TournamentPostCard({required this.postData});

  @override
  Widget build(BuildContext context) {
    final imageUrl = postData['imageUrl'] as String?;
    final userName = postData['userName'] as String? ?? '名無しさん';
    final judgedSize = postData['judgedSize'] as num?;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 画像表示エリア
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade200,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    )
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          // 情報表示エリア
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (judgedSize != null)
                  Text(
                    '$judgedSize cm',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userName,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}