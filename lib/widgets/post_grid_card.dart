// lib/widgets/post_grid_card.dart (フォローボタンのスタイルを修正)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/likes_provider.dart';
import '../providers/saves_provider.dart';
import '../providers/following_provider.dart';
import '../providers/post_provider.dart';

import '../models/post_model.dart';
import '../features/account/account.dart';
import '../features/post/post_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostGridCard extends ConsumerWidget {
  final Post post;
  final int? rank;

  const PostGridCard({super.key, required this.post, this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isMyPost = currentUser.uid == post.userId;

    final postAsyncValue = ref.watch(postStreamProvider(post.id));

    if (postAsyncValue is! AsyncData<Post>) {
      return Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(color: Colors.grey.shade200),
      );
    }

    final realTimePost = postAsyncValue.value!;
    final isLiked =
        ref.watch(likedPostsNotifierProvider).value?.contains(post.id) ?? false;
    final isSaved =
        ref.watch(savedPostsNotifierProvider).value?.contains(post.id) ?? false;
    final isFollowing =
        ref.watch(followingNotifierProvider).value?.contains(post.userId) ??
        false;
    final thumbnailUrl = realTimePost.thumbnailUrls.isNotEmpty
        ? realTimePost.thumbnailUrls.first
        : (realTimePost.imageUrls.isNotEmpty ? realTimePost.imageUrls.first : '');


    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => PostDetailPage(post: realTimePost)),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.grey),
                    )
                  else
                    Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withOpacity(0.3),
                      shape: const CircleBorder(),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved
                              ? Colors.lightBlueAccent
                              : Colors.white,
                        ),
                        onPressed: () => ref
                            .read(savedPostsNotifierProvider.notifier)
                            .handleSave(post.id),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MyPage(userId: post.userId),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: (post.userPhotoUrl != null && post.userPhotoUrl!.isNotEmpty)
          ? NetworkImage(post.userPhotoUrl!)
          : null,
      child: (post.userPhotoUrl == null || post.userPhotoUrl!.isEmpty)
          ? const Icon(Icons.person, size: 12)
          : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              post.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isMyPost)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: ElevatedButton(
                        onPressed: () {
                          ref
                              .read(followingNotifierProvider.notifier)
                              .handleFollow(post.userId);
                        },
                        // ▼▼▼【スタイル修正】ご指定の通りに背景色と文字色を変更 ▼▼▼
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.white
                              : Colors.blue,
                          foregroundColor: isFollowing
                              ? Colors.blue
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: Colors.blue.withOpacity(0.5),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 30),
                        ),
                        child: Text(
                          isFollowing ? 'フォロー中' : '+ フォロー',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
  '${realTimePost.squidType} ${realTimePost.squidSize} cm',
  style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
  ),
  overflow: TextOverflow.ellipsis,
),
                  const SizedBox(height: 2),
                  Text(
                    'ヒットエギ: ${realTimePost.egiName}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildActionButton(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        isLiked ? Colors.red : Colors.grey,
                        realTimePost.likeCount,
                        () {
                          ref
                              .read(likedPostsNotifierProvider.notifier)
                              .handleLike(post.id);
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        Icons.chat_bubble_outline,
                        Colors.grey,
                        realTimePost.commentCount,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(
                                post: realTimePost,
                                scrollToComments: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    int? count,
    VoidCallback onPressed,
  ) {
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: color, size: 20),
          onPressed: onPressed,
        ),
        const SizedBox(width: 2),
        if (count != null)
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }
}
