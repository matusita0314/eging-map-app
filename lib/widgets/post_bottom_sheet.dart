import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/post_model.dart';
import '../features/post/post_detail_page.dart';
import '../features/account/account.dart';
import '../providers/likes_provider.dart';
import '../providers/saves_provider.dart';
import '../providers/post_provider.dart';

class PostBottomSheet extends ConsumerStatefulWidget {
  final Post post;
  final ScrollController scrollController;
  final VoidCallback onNavigateToDetail;

  const PostBottomSheet({
    super.key,
    required this.post,
    required this.scrollController,
    required this.onNavigateToDetail,
  });

  @override
  ConsumerState<PostBottomSheet> createState() => _PostBottomSheetState();
}

class _PostBottomSheetState extends ConsumerState<PostBottomSheet> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postAsyncValue = ref.watch(postStreamProvider(widget.post.id));
    final post = postAsyncValue.asData?.value ?? widget.post;

    final isLiked = ref.watch(likedPostsNotifierProvider).value?.contains(post.id) ?? false;
    final isSaved = ref.watch(savedPostsNotifierProvider).value?.contains(post.id) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyPage(userId: post.userId))),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: post.userPhotoUrl != null && post.userPhotoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(post.userPhotoUrl!)
                        : null,
                    child: (post.userPhotoUrl == null || post.userPhotoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (post.imageUrls.isNotEmpty)
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: post.imageUrls.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: CachedNetworkImage(
                            imageUrl: post.imageUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey.shade200),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        ),
                      );
                    },
                  ),
                  if (post.imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: SmoothPageIndicator(
                        controller: _pageController,
                        count: post.imageUrls.length,
                        effect: WormEffect(
                          dotHeight: 8,
                          dotWidth: 8,
                          activeDotColor: Colors.white,
                          dotColor: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🦑${post.squidType} ${post.squidSize} cm',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'ヒットエギ: ${post.egiName}',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoChip(Icons.calendar_today, DateFormat('M月d日').format(post.createdAt)),
                    _buildInfoChip(Icons.wb_sunny_outlined, post.weather),
                    _buildInfoChip(Icons.access_time, post.timeOfDay ?? '不明'),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    IconButton(
                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey),
                      onPressed: () => ref.read(likedPostsNotifierProvider.notifier).handleLike(post.id),
                    ),
                    Text('${post.likeCount}'),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.commentCount}'),
                    const Spacer(),
                    IconButton(
                      iconSize: 28,
                      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: isSaved ? Theme.of(context).primaryColor : Colors.grey),
                      onPressed: () => ref.read(savedPostsNotifierProvider.notifier).handleSave(post.id),
                    ),
                  ],
                ),
                const Divider(height: 24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: widget.onNavigateToDetail,
                  child: const Text('もっと詳しく見る'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.grey.shade600),
      label: Text(text),
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}