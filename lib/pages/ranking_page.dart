// lib/pages/ranking_page.dart (最終版)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../widgets/post_grid_card.dart';
import '../widgets/common_app_bar.dart';

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
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ランキング対象の投稿がありません。'));
          }

          final docs = snapshot.data!.docs;
          final firstPostDoc = docs.first;
          final otherPostDocs = docs.skip(1).toList();

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              // --- 1位のカード ---
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: PostGridCard(
                  post: Post.fromFirestore(firstPostDoc),
                  rank: 1,
                ),
              ),

              // --- 2位以降のグリッド ---
              if (otherPostDocs.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: otherPostDocs.length,
                  itemBuilder: (context, index) {
                    final post = Post.fromFirestore(otherPostDocs[index]);
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
}
