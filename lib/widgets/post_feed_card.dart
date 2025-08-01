import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../features/account/account.dart';
import '../features/post/post_detail_page.dart';
import '../models/post_model.dart';
import '../providers/following_provider.dart';
import '../providers/likes_provider.dart';
import '../providers/saves_provider.dart';
import '../providers/post_provider.dart'; // post_providerをインポート

class PostFeedCard extends ConsumerWidget {
  final Post post;
  const PostFeedCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ▼▼▼【修正】postStreamProviderを監視してリアルタイムの投稿データを取得 ▼▼▼
    final postAsyncValue = ref.watch(postStreamProvider(post.id));

    // データがまだ読み込めていない場合は、シンプルなコンテナを表示
    if (postAsyncValue is! AsyncData<Post>) {
      return Card(
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          color: Colors.grey.shade200,
        ),
      );
    }

    // リアルタイムの投稿データを取得
    final realTimePost = postAsyncValue.value!;

    final pageController = PageController(viewportFraction: 0.95);
    final screenHeight = MediaQuery.of(context).size.height;

    final isLiked = ref.watch(likedPostsNotifierProvider).value?.contains(realTimePost.id) ?? false;
    final isSaved = ref.watch(savedPostsNotifierProvider).value?.contains(realTimePost.id) ?? false;
    final isFollowing = ref.watch(followingNotifierProvider).value?.contains(realTimePost.userId) ?? false;
    final isMyPost = realTimePost.userId == FirebaseAuth.instance.currentUser?.uid;

    if (realTimePost.imageUrls.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => PostDetailPage(post: realTimePost))),
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: screenHeight * 0.65, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => MyPage(userId: realTimePost.userId))),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: realTimePost.userPhotoUrl != null && realTimePost.userPhotoUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(realTimePost.userPhotoUrl!)
                                : null,
                            child: realTimePost.userPhotoUrl == null || realTimePost.userPhotoUrl!.isEmpty
                                ? const Icon(Icons.person, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(realTimePost.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _buildHeaderInfo(Icons.location_on, realTimePost.region ?? '不明'),
                    const SizedBox(width: 20),
                    _buildHeaderInfo(Icons.schedule, DateFormat('yyyy年M月d日').format(realTimePost.createdAt)),
                  ],
                ),
              ),
              
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  itemCount: realTimePost.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 6.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: realTimePost.imageUrls[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.red.shade900,
                            child: const Center(child: Text('画像エラー', style: TextStyle(color: Colors.white))),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (realTimePost.imageUrls.length > 1)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: SmoothPageIndicator(
                      controller: pageController,
                      count: realTimePost.imageUrls.length,
                      effect: ScrollingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotColor: Theme.of(context).primaryColor,
                        dotColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("🦑 ${realTimePost.squidType ?? '釣果'}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (!isMyPost)
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(followingNotifierProvider.notifier)
                                  .handleFollow(realTimePost.userId);
                            },
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
                                horizontal: 12,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 30),
                            ),
                            child: Text(
                              isFollowing ? 'フォロー中' : '+ フォロー',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildDetailInfo(Icons.straighten, '${realTimePost.squidSize} cm'),
                        _buildDetailInfo(Icons.wb_sunny_outlined, realTimePost.weather),
                        _buildDetailInfo(Icons.access_time, realTimePost.timeOfDay ?? '不明'),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey.shade700),
                        onPressed: () => ref.read(likedPostsNotifierProvider.notifier).handleLike(realTimePost.id),
                      ),
                      // ▼▼▼【修正】リアルタイムのいいね数を表示 ▼▼▼
                      Text('${realTimePost.likeCount}'),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.grey.shade700),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => PostDetailPage(post: realTimePost, scrollToComments: true))),
                      ),
                      // ▼▼▼【修正】リアルタイムのコメント数を表示 ▼▼▼
                      Text('${realTimePost.commentCount}'),
                    ],
                  ),
                  IconButton(
                    icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: isSaved ? Theme.of(context).primaryColor : Colors.grey.shade700),
                    onPressed: () => ref.read(savedPostsNotifierProvider.notifier).handleSave(realTimePost.id),
                  ),
                ],
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
        Icon(icon, size: 17, color: const Color.fromARGB(255, 45, 210, 48)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Color.fromARGB(255, 49, 49, 49), fontSize: 15)),
      ],
    );
  }

  Widget _buildDetailInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 15.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color.fromARGB(255, 71, 157, 255)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: Colors.grey.shade800, fontSize: 17, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}