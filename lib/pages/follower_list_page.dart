import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/my_page.dart';

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
      appBar: AppBar(title: Text(title)),
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
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final followDoc = snapshot.data!.docs[index];
              // 各ドキュメントID（ユーザーID）を使って、ユーザー情報を取得
              return _UserTile(userId: followDoc.id);
            },
          );
        },
      ),
    );
  }
}

// ユーザー情報を取得して表示するタイルウィジェット
class _UserTile extends StatelessWidget {
  final String userId;

  const _UserTile({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: Text('読み込み中...'));
        }
        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final userName = userData['displayName'] ?? '名無しさん';
        final userPhotoUrl = userData['photoUrl'] ?? '';

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
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