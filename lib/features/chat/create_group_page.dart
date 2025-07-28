import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'talk_page.dart';
import '../../providers/following_provider.dart';

// 選択されたユーザーIDを管理するためのProvider
final selectedUsersProvider = StateProvider<Set<String>>((ref) => {});

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});
  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _groupNameController = TextEditingController();

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
      // 自分のIDもメンバーに含める
      final members = [currentUser!.uid, ...selectedUsers];
      // 未読数カウント用のマップを初期化
      final unreadCountMap = {for (var memberId in members) memberId: 0};

      // Firestoreに新しいチャットルームを作成
      final newRoomRef = await FirebaseFirestore.instance.collection('chat_rooms').add({
        'type': 'group',
        'groupName': groupName,
        'groupPhotoUrl': '', // グループ画像機能は後で実装
        'userIds': members,
        'admins': [currentUser.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'グループが作成されました',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': unreadCountMap,
      });

      // 作成が成功したら、そのグループのトークページに遷移
      if (mounted) {
        Navigator.of(context).pop(); // 作成ページを閉じる
        Navigator.of(context).pushReplacement(
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final followingAsync = ref.watch(followingNotifierProvider);
    final selectedUsers = ref.watch(selectedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('新しいグループを作成')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'グループ名',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('メンバーを選択', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: followingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('エラー: $err')),
              data: (followingIds) {
                if (followingIds.isEmpty) {
                  return const Center(child: Text('招待できる友達がいません。'));
                }
                return ListView.builder(
                  itemCount: followingIds.length,
                  itemBuilder: (context, index) {
                    final userId = followingIds.toList()[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final isSelected = selectedUsers.contains(userId);
                        return CheckboxListTile(
                          secondary: CircleAvatar(
                            backgroundImage: (userData['photoUrl'] as String?).toString().isNotEmpty
                                ? NetworkImage(userData['photoUrl'])
                                : null,
                          ),
                          title: Text(userData['displayName'] ?? '名無しさん'),
                          value: isSelected,
                          onChanged: (bool? value) {
                            ref.read(selectedUsersProvider.notifier).update((state) {
                              final newSet = Set<String>.from(state);
                              if (value == true) {
                                newSet.add(userId);
                              } else {
                                newSet.remove(userId);
                              }
                              return newSet;
                            });
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        label: const Text('作成'),
        icon: const Icon(Icons.check),
      ),
    );
  }
}