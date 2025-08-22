// lib/features/chat/tabs/friends_tab_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/following_provider.dart';
import '../../account/account.dart';
import '../../../providers/user_provider.dart'; // userProviderをインポート

class FriendsTabView extends ConsumerWidget {
  const FriendsTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsyncValue = ref.watch(followingNotifierProvider);

    return followingAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (err, stack) => Center(child: Text('エラー: $err', style: const TextStyle(color: Colors.white))),
      data: (followingIds) {
        if (followingIds.isEmpty) {
          return const Center(
            child: Text(
              'まだ誰もフォローしていません。\n「友達を見つける」から探してみましょう！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: followingIds.length,
          itemBuilder: (context, index) {
            final userId = followingIds.toList()[index];
            // ▼▼▼ follower_list_page.dartと同じ形式のUserTileに変更 ▼▼▼
            return _UserTile(userId: userId);
          },
        );
      },
    );
  }
}

// ユーザー情報を取得して表示するタイル（follower_list_page.dartのデザインを適用）
class _UserTile extends ConsumerWidget {
  final String userId;
  const _UserTile({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FutureBuilderの代わりにuserProviderをwatchする
    final userAsyncValue = ref.watch(userProvider(userId));

    return userAsyncValue.when(
      loading: () => const ListTile(title: Text('', style: TextStyle(color: Colors.white))),
      error: (err, stack) => const SizedBox.shrink(), // エラー時は非表示
      data: (user) {
        // ▼▼▼ カード形式のUIに変更 ▼▼▼
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(user.photoUrl!)
                  : null,
              child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              user.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF13547a)),
            ),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => MyPage(userId: user.id),
              ));
            },
          ),
        );
      },
    );
  }
}