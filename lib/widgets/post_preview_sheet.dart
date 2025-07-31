import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../features/post/post_detail_page.dart'; // 投稿詳細ページ

class PostPreviewSheet extends StatelessWidget {
  final Post post;

  const PostPreviewSheet({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () {
        // シート全体をタップしても詳細ページに飛ぶようにする
        Navigator.of(context).pop(); // まずシートを閉じる
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailPage(post: post),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // コンテンツの高さに合わせる
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 投稿画像
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                post.imageUrls.first,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                // 画像読み込み中にインジケーターを表示
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                // エラー時にアイコンを表示
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 40);
                },
              ),
            ),
            const SizedBox(height: 16),
            // エギ名とサイズ
            Text(
              post.egiName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${post.squidSize} cm',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            // 詳細を見るボタン
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // まずシートを閉じる
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PostDetailPage(post: post),
                  ),
                );
              },
              child: const Text('詳細を見る'),
            ),
          ],
        ),
      ),
    );
  }
}