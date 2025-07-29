import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/following_provider.dart';
import '../../account/account.dart';

class FriendsTabView extends ConsumerWidget {
  const FriendsTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // フォロー中のユーザーIDリストをリアルタイムで監視
    final followingAsyncValue = ref.watch(followingNotifierProvider);

    return followingAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('エラー: $err')),
      data: (followingIds) {
        if (followingIds.isEmpty) {
          return const Center(
            child: Text('まだ誰もフォローしていません。\n「友達を見つける」から探してみましょう！', textAlign: TextAlign.center),
          );
        }
        // フォロー中のユーザー情報を取得してリスト表示
        return ListView.builder(
          itemCount: followingIds.length,
          itemBuilder: (context, index) {
            final userId = followingIds.toList()[index];
            return _UserTile(userId: userId);
          },
        );
      },
    );
  }
}

// ユーザー情報を取得して表示するタイル
class _UserTile extends StatelessWidget {
  final String userId;
  const _UserTile({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          // 読み込み中はサイズの決まったコンテナを表示してガタツキを防ぐ
          return const ListTile(title: Text('')); 
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final userName = userData['displayName'] ?? '名無しさん';
        final userPhotoUrl = userData['photoUrl'] ?? '';

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: userPhotoUrl.isNotEmpty ? CachedNetworkImageProvider(userPhotoUrl) : null,
            child: userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(userName),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => MyPage(userId: userId),
            ));
          },
        );
      },
    );
  }
}