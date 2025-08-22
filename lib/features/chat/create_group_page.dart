import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'talk_page.dart';
import '../../providers/following_provider.dart';
import '../../providers/user_provider.dart';

final selectedUsersProvider = StateProvider<Set<String>>((ref) => {});

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});
  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    final selectedUsers = ref.read(selectedUsersProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('グループ名を入力してください。')));
      return;
    }
    if (selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('メンバーを1人以上選択してください。')));
      return;
    }

    try {
      final members = [currentUser!.uid, ...selectedUsers];
      final unreadCountMap = {for (var memberId in members) memberId: 0};

      final newRoomRef = await FirebaseFirestore.instance.collection('chat_rooms').add({
        'type': 'group',
        'groupName': groupName,
        'groupPhotoUrl': '', 
        'userIds': members,
        'admins': [currentUser.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'グループが作成されました',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': unreadCountMap,
      });

      if (mounted) {
        // 現在のページを閉じてから新しいトークページに遷移
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TalkPage(
              chatRoomId: newRoomRef.id,
              chatTitle: groupName,
              isGroupChat: true,
            ),
          ),
        );
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        label: const Text(
          'グループを作成',
          style: TextStyle(
          color: Color.fromARGB(255, 0, 0, 0),          
          fontSize: 16,                 
          fontWeight: FontWeight.bold,          
          ),
        ),
        icon: const Icon(Icons.check),
        backgroundColor: const Color.fromARGB(255, 142, 255, 157),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF13547a), Color(0xFF80d0c7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildGroupNameInput(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('メンバーを選択', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _buildUserList(),
            ],
          ),
        ),
      ),
    );
  }

  // フローティングヘッダー
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF13547a)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              '新しいグループを作成',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13547a)),
            ),
          ),
          const SizedBox(width: 48), // 中央寄せのためのダミースペース
        ],
      ),
    );
  }

  // グループ名入力フィールド
  Widget _buildGroupNameInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(
            hintText: 'グループ名',
            prefixIcon: Icon(Icons.group, color: Color(0xFF13547a)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // メンバー一覧リスト
  Widget _buildUserList() {
    final followingAsync = ref.watch(followingNotifierProvider);
    return Expanded(
      child: followingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) => Center(child: Text('エラー: $err', style: const TextStyle(color: Colors.white))),
        data: (followingIds) {
          if (followingIds.isEmpty) {
            return const Center(child: Text('招待できる友達がいません。', style: TextStyle(color: Colors.white, fontSize: 16)));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // FABと重ならないように調整
            itemCount: followingIds.length,
            itemBuilder: (context, index) {
              final userId = followingIds.toList()[index];
              return _UserSelectionTile(userId: userId);
            },
          );
        },
      ),
    );
  }
}

class _UserSelectionTile extends ConsumerWidget {
  final String userId;
  const _UserSelectionTile({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(userId));
    final selectedUsers = ref.watch(selectedUsersProvider);
    final isSelected = selectedUsers.contains(userId);

    // ユーザー情報をトグルする関数
    void toggleSelection() {
      ref.read(selectedUsersProvider.notifier).update((state) {
        final newSet = Set<String>.from(state);
        if (isSelected) {
          newSet.remove(userId);
        } else {
          newSet.add(userId);
        }
        return newSet;
      });
    }

    return userAsync.when(
      loading: () => const SizedBox(height: 68), // 高さを合わせるためのSizedBox
      error: (err, stack) => const SizedBox.shrink(),
      data: (user) {
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
            trailing: Checkbox(
              value: isSelected,
              onChanged: (value) => toggleSelection(),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onTap: toggleSelection,
          ),
        );
      },
    );
  }
}