import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'talk_page.dart';
import '../account/account.dart';
import '../../widgets/common_app_bar.dart';

// メインのタブ切り替えページ
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: const Text('トーク'),
        // bottomにTabBarを渡せる
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ともだち'),
            Tab(text: 'トーク'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_FriendsList(), _TalksList()],
      ),
    );
  }
}

// --- 「トーク」タブの中身 ---
class _TalksList extends StatelessWidget {
  const _TalksList();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('ログインが必要です。'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('userIds', arrayContains: currentUser.uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだトークがありません。'));
        }
        final chatDocs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatRoomData = chatDocs[index].data() as Map<String, dynamic>;
            return _ChatRoomTile(
              chatRoomId: chatDocs[index].id,
              chatRoomData: chatRoomData,
              currentUserId: currentUser.uid,
            );
          },
        );
      },
    );
  }
}

// （変更なし）トークルームのタイル
class _ChatRoomTile extends StatefulWidget {
  final String chatRoomId;
  final Map<String, dynamic> chatRoomData;
  final String currentUserId;

  const _ChatRoomTile({
    required this.chatRoomId,
    required this.chatRoomData,
    required this.currentUserId,
  });

  @override
  State<_ChatRoomTile> createState() => _ChatRoomTileState();
}

class _ChatRoomTileState extends State<_ChatRoomTile> {
  DocumentSnapshot? _otherUserDoc;

  @override
  void initState() {
    super.initState();
    _fetchOtherUserData();
  }

  void _fetchOtherUserData() {
    final List<String> userIds = List<String>.from(
      widget.chatRoomData['userIds'] ?? [],
    );
    final otherUserId = userIds.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get()
          .then((doc) {
            if (mounted) setState(() => _otherUserDoc = doc);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_otherUserDoc == null) return const ListTile(title: Text('読み込み中...'));

    final otherUserData = _otherUserDoc!.data() as Map<String, dynamic>;
    final lastMessage =
        widget.chatRoomData['lastMessage'] as String? ?? 'まだメッセージはありません';
    final timestamp = widget.chatRoomData['lastMessageAt'] as Timestamp?;
    final lastMessageTime = timestamp != null
        ? DateFormat('HH:mm').format(timestamp.toDate())
        : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            (otherUserData['photoUrl'] as String?).toString().isNotEmpty
            ? NetworkImage(otherUserData['photoUrl'])
            : null,
        child: (otherUserData['photoUrl'] as String?).toString().isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        otherUserData['displayName'] ?? '名無しさん',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        lastMessageTime,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TalkPage(
              chatRoomId: widget.chatRoomId,
              otherUserName: otherUserData['displayName'] ?? '名無しさん',
              otherUserPhotoUrl: otherUserData['photoUrl'] ?? '',
            ),
          ),
        );
      },
    );
  }
}

class _FriendsList extends StatefulWidget {
  const _FriendsList({Key? key}) : super(key: key);

  @override
  State<_FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<_FriendsList> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  // Future<List<QueryDocumentSnapshot>>? は null許容でなくても良い
  late Future<List<QueryDocumentSnapshot>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _fetchFriends();
  }

  // クエリを最適化して、フォロー中のユーザー情報を取得する
  Future<List<QueryDocumentSnapshot>> _fetchFriends() async {
    // 1. まず自分がフォローしている人のIDリストを取得
    final followingSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('following')
        .get();

    final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

    if (followingIds.isEmpty) {
      return []; // フォロー中の人がいなければ空のリストを返す
    }

    // 2. IDリストを使って、ユーザー情報を一度のクエリでまとめて取得 (whereIn)
    //    ※ whereInは一度に30個までのIDしか指定できないため、必要なら分割処理が必要
    final friendsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: followingIds)
        .get();

    return friendsSnapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // エラーハンドリングを追加
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('フォロー中のユーザーがいません。'));
        }
        final friendsDocs = snapshot.data!;
        return ListView.builder(
          itemCount: friendsDocs.length,
          itemBuilder: (context, index) {
            final userData = friendsDocs[index].data() as Map<String, dynamic>;
            // photoUrlが存在しない場合のハンドリングを安全に
            final photoUrl = userData['photoUrl'] as String?;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(userData['displayName'] ?? '名無しさん'),
              onTap: () {
                // プロフィールページへ遷移
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MyPage(userId: friendsDocs[index].id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
