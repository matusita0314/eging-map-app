import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../providers/discover_filter_provider.dart';
import 'package:algoliasearch/algoliasearch.dart';

import '../../models/post_model.dart';
import '../../widgets/post_grid_card.dart';
import '../../widgets/common_app_bar.dart';
import '../../providers/following_provider.dart';

part 'timeline_page.g.dart';

@riverpod
Stream<List<Post>> followingTimeline(FollowingTimelineRef ref) {
  final followingUsersState = ref.watch(followingNotifierProvider);

  if (followingUsersState.value == null || followingUsersState.value!.isEmpty) {
    return Stream.value([]);
  }

  final followingUserIds = followingUsersState.value!.toList();
  final stream = FirebaseFirestore.instance
      .collection('posts')
      .where('userId', whereIn: followingUserIds)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  return stream.map(
    (snapshot) => snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
  );
}

@riverpod
Future<List<Post>> discoverTimeline(DiscoverTimelineRef ref) async {
  // フィルターの状態を監視
  final filter = ref.watch(discoverFilterNotifierProvider);

  // ▼▼▼【修正版】algoliasearch v1.34.1の正しい書き方 ▼▼▼
  // Algoliaクライアントを初期化
  // ★★★ 重要 ★★★
  // ここには必ず「Search-Only API Key」を使用してください。
  final algolia = Algolia.init(
    applicationId: 'H43CZ7GND1', // AlgoliaのApplication ID
    apiKey: '7d86d0716d7f8d84984e54f95f7b4dfa', // AlgoliaのSearch-Only API Key
  );

  final AlgoliaIndexReference index = algolia.instance.index(filter.sortBy);

  // 検索クエリを構築
  final AlgoliaQuery query = index.query('');
  // TODO: ここにフィルター条件を追加していく
  // .facetFilter('weather:晴れ')
  // .facetFilter('squidSize > 30');

  // Algoliaに検索をリクエスト
  final AlgoliaQuerySnapshot snap = await query.getObjects();

  // Algoliaの検索結果からPostオブジェクトのリストを作成
  final posts = snap.hits.map((hit) => Post.fromAlgolia(hit.data)).toList();
  return posts;
  // ▲▲▲【ここまで修正】▲▲▲
}

@riverpod
Stream<List<Post>> todayTimeline(TodayTimelineRef ref) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final stream = FirebaseFirestore.instance
      .collection('posts')
      .where('createdAt', isGreaterThanOrEqualTo: startOfToday)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots();
  return stream.map(
    (snapshot) => snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
  );
}

// --- ▼▼▼ ここからUI定義 ▼▼▼ ---

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});
  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // タブの数を3つに変更
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('タイムライン'),
        // AppBarの下にTabBarを配置
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'みつける'),
            Tab(text: 'フォロー中'),
            Tab(text: 'Today'),
          ],
        ),
      ),
      // TabBarViewでタブの切り替えをハンドリング
      body: TabBarView(
        controller: _tabController,
        children: [
          // 各タブに対応するProviderを指定した汎用Viewを配置
          _TimelineView(provider: discoverTimelineProvider),
          _TimelineView(provider: followingTimelineProvider),
          _TimelineView(provider: todayTimelineProvider),
        ],
      ),
    );
  }
}

// Providerから受け取った投稿リストを表示する汎用ウィジェット
class _TimelineView extends ConsumerWidget {
  // どのProviderを使うかを引数で受け取れるようにする
  final AutoDisposeStreamProvider<List<Post>> provider;
  const _TimelineView({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 引数で渡されたProviderを監視(watch)する
    final postsAsyncValue = ref.watch(provider);

    // Providerの状態に応じてUIを切り替える
    return postsAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('エラーが発生しました: $err')),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(child: Text('投稿はまだありません。'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            // 下に引っ張って更新する機能
            ref.invalidate(provider);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return PostGridCard(post: posts[index]);
            },
          ),
        );
      },
    );
  }
}
