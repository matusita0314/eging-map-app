import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/user_provider.dart';

// 表示するリストの種類（フォロワーかフォロー中か）
enum FollowListType { followers, following }

class FollowerListPage extends StatelessWidget {
  final String userId;
  final FollowListType listType;

  const FollowerListPage({
    super.key,
    required this.userId,
    required this.listType,
  });

  @override
  Widget build(BuildContext context) {
    final title = listType == FollowListType.followers ? 'フォロワー' : 'フォロー中';
    final collectionPath = listType == FollowListType.followers ? 'followers' : 'following';

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF13547a),
              Color(0xFF80d0c7),
            ],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // フローティング風AppBar
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF13547a),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // アイコンボタンのサイズ分のスペース
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ];
            },
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection(collectionPath)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('$titleがいません。'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final followDoc = snapshot.data!.docs[index];
                    // 各ドキュメントID（ユーザーID）を使って、ユーザー情報を取得
                    return _UserTile(userId: followDoc.id);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ユーザー情報を取得して表示するタイルウィジェット
class _UserTile extends ConsumerWidget {
  final String userId;
  const _UserTile({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FutureBuilderの代わりにuserProviderをwatchする
    final userAsyncValue = ref.watch(userProvider(userId));

    return userAsyncValue.when(
      loading: () => const ListTile(title: Text('読み込み中...')),
      error: (err, stack) => const ListTile(title: Text('ユーザー情報の取得に失敗')),
      data: (user) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF13547a),
              ),
            ),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => MyPage(userId: userId), // MyPageではなくAccountを使用
              ));
            },
          ),
        );
      },
    );
  }
}