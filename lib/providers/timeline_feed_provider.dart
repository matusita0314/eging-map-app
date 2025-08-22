// import 'dart:async';import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/post_model.dart';

// part 'timeline_feed_provider.g.dart';

// @Riverpod(keepAlive: true)
// class TimelineFeedNotifier extends _$TimelineFeedNotifier {
//   DocumentSnapshot? _lastDoc;
//   bool _noMorePosts = false; // ★★★ これ以上投稿がないことを示すフラグを追加 ★★★
//   static const _limit = 5;

//   @override
//   Future<List<Post>> build() async {
//     final snapshot = await _fetchPosts();
//     if (snapshot.docs.length < _limit) {
//       _noMorePosts = true; // 最初の取得で5件未満なら、それで終わり
//     }
//     if (snapshot.docs.isNotEmpty) {
//       _lastDoc = snapshot.docs.last;
//     }
//     return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
//   }

//   Future<QuerySnapshot> _fetchPosts() {
//     Query query = FirebaseFirestore.instance
//         .collection('posts')
//         .orderBy('createdAt', descending: true)
//         .limit(_limit);

//     final lastDocument = _lastDoc;
//     if (lastDocument != null) {
//       query = query.startAfterDocument(lastDocument);
//     }
//     return query.get();
//   }

//   Future<void> fetchNextPage() async {
//     // ★★★ ローディング中か、すでに全件読み込み済みなら何もしない ★★★
//     if (state.isReloading || _noMorePosts) return;

//     final snapshot = await _fetchPosts();

//     // ★★★ 新しく取得したデータが5件未満なら、もう次はないのでフラグを立てる ★★★
//     if (snapshot.docs.length < _limit) {
//       _noMorePosts = true;
//     }

//     if (snapshot.docs.isNotEmpty) {
//       _lastDoc = snapshot.docs.last;
//       final newPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
//       final currentState = state.value ?? [];
//       state = AsyncData([...currentState, ...newPosts]);
//     }
//   }
// }