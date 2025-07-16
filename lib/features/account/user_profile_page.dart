// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// import '../chat/talk_page.dart';
// import 'profile_core_view.dart'; // 共通パーツをインポート

// /// 他のユーザーのプロフィールページ
// class UserProfilePage extends StatefulWidget {
//   final String userId;

//   const UserProfilePage({super.key, required this.userId});

//   @override
//   State<UserProfilePage> createState() => _UserProfilePageState();
// }

// class _UserProfilePageState extends State<UserProfilePage> {
//   Future<void> _startChat(DocumentSnapshot otherUserDoc) async {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser == null) return;
    
//     final myId = currentUser.uid;
//     final otherUserId = otherUserDoc.id;
//     final otherUserData = otherUserDoc.data() as Map<String, dynamic>;

//     final userIds = [myId, otherUserId]..sort();
//     final chatRoomId = userIds.join('_');

//     final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId);
//     final docSnapshot = await chatRoomRef.get();

//     if (!docSnapshot.exists) {
//       await chatRoomRef.set({'userIds': userIds, 'createdAt': FieldValue.serverTimestamp()});
//     }

//     if (mounted) {
//       Navigator.of(context).push(MaterialPageRoute(
//         builder: (context) => TalkPage(
//           chatRoomId: chatRoomId,
//           otherUserName: otherUserData['displayName'] ?? '名無しさん',
//           otherUserPhotoUrl: otherUserData['photoUrl'] ?? '',
//         ),
//       ));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         // 戻るボタン
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//       ),
//       body: ProfileCoreView(
//         userId: widget.userId,
//         actionButtonsBuilder: (userDoc) {
//           // チャットボタンを構築して共通ビューに渡す
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//             child: ElevatedButton.icon(
//               icon: const Icon(Icons.chat_bubble_outline),
//               label: const Text('チャット'),
//               onPressed: () => _startChat(userDoc),
//               style: ElevatedButton.styleFrom(
//                 minimumSize: const Size(double.infinity, 40), // 横幅いっぱい
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }