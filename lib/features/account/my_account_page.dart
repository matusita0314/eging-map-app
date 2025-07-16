// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// import '../../core/auth_wrapper.dart';
// import 'edit_profile_page.dart';
// import 'profile_core_view.dart'; // 共通パーツをインポート

// /// ログインユーザー自身のアカウントページ
// class MyAccountPage extends StatefulWidget {
//   const MyAccountPage({super.key});

//   @override
//   State<MyAccountPage> createState() => _MyAccountPageState();
// }

// class _MyAccountPageState extends State<MyAccountPage> {
//   final _currentUser = FirebaseAuth.instance.currentUser!;

//   Future<void> _logout() async {
//     await FirebaseAuth.instance.signOut();
//     if (mounted) {
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (context) => const AuthWrapper()),
//         (route) => false,
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         // 自分のページなので戻るボタンは不要
//         leading: const SizedBox.shrink(),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout, color: Colors.black87),
//             tooltip: 'ログアウト',
//             onPressed: _logout,
//           ),
//         ],
//       ),
//       body: ProfileCoreView(
//         userId: _currentUser.uid,
//         actionButtonsBuilder: (userDoc) {
//           // 編集ボタンを構築して共通ビューに渡す
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//             child: ElevatedButton.icon(
//               icon: const Icon(Icons.edit),
//               label: const Text('プロフィールを編集'),
//               onPressed: () => Navigator.of(context).push(
//                 MaterialPageRoute(builder: (context) => const EditProfilePage()),
//               ),
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