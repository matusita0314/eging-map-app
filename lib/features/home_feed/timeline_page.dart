import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import '../../providers/discover_filter_provider.dart';

import '../../models/post_model.dart';
import '../../widgets/post_grid_card.dart';
import '../../widgets/common_app_bar.dart';
import '../../providers/following_provider.dart';
import 'widgets/filter_sheet.dart';

part 'timeline_page.g.dart';

// 「フォロー中」タブ用のProvider
@riverpod
Stream<List<Post>> followingTimeline(FollowingTimelineRef ref) {
  final followingUsersState = ref.watch(followingNotifierProvider);
  if (followingUsersState.value == null || followingUsersState.value!.isEmpty) {
    return Stream.value([]);
  }
  final followingUserIds = followingUsersState.value!.toList();
  return FirebaseFirestore.instance
      .collection('posts')
      .where('userId', whereIn: followingUserIds)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
      );
}

// 「Today」タブ用のProvider
@riverpod
Stream<List<Post>> todayTimeline(TodayTimelineRef ref) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  return FirebaseFirestore.instance
      .collection('posts')
      .where('createdAt', isGreaterThanOrEqualTo: startOfToday)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
      );
}

@riverpod
Future<List<Post>> discoverTimeline(DiscoverTimelineRef ref) async {
  final filter = ref.watch(discoverFilterNotifierProvider);

  // OR検索が必要なフィルター値を抜き出す (何もなければ {null} を入れて1回だけループさせる)
  final squidTypesToSearch = filter.squidTypes.isEmpty
      ? {null}
      : filter.squidTypes;
  final sizeRangesToSearch = filter.sizeRanges.isEmpty
      ? {null}
      : filter.sizeRanges;
  final weatherToSearch = filter.weather.isEmpty
      ? {null}
      : filter.weather; // ◀◀◀ 追加
  final timeOfDayToSearch = filter.timeOfDay.isEmpty
      ? {null}
      : filter.timeOfDay; // ◀◀◀ 追加

  // OR検索条件の全組み合わせを作成
  final searchCombinations =
      <
        ({
          String? squidType,
          String? sizeRange,
          String? weather, // ◀◀◀ 追加
          String? timeOfDay, // ◀◀◀ 追加
        })
      >[];

  // ▼▼▼ 4重ループに拡張 ▼▼▼
  for (final squidType in squidTypesToSearch) {
    for (final sizeRange in sizeRangesToSearch) {
      for (final weather in weatherToSearch) {
        for (final timeOfDay in timeOfDayToSearch) {
          // 全てがnullの組み合わせは、何もフィルターが選択されていない時以外はスキップ
          if (squidType == null &&
              sizeRange == null &&
              weather == null &&
              timeOfDay == null &&
              (squidTypesToSearch.length > 1 ||
                  sizeRangesToSearch.length > 1 ||
                  weatherToSearch.length > 1 ||
                  timeOfDayToSearch.length > 1)) {
            continue;
          }
          searchCombinations.add((
            squidType: squidType,
            sizeRange: sizeRange,
            weather: weather,
            timeOfDay: timeOfDay,
          ));
        }
      }
    }
  }
  
  final searchFutures = searchCombinations.map((combo) {
    final searcher = HitsSearcher(
      applicationID: 'H43CZ7GND1',
      apiKey: '7d86d0716d7f8d84984e54f95f7b4dfa',
      indexName: 'posts_${filter.sortBy.value}',
    );

    // ▼▼▼ loopFilterState の作成部分を修正 ▼▼▼
    final loopFilterState = filter.copyWith(
      squidTypes: combo.squidType == null ? {} : {combo.squidType!},
      sizeRanges: combo.sizeRange == null ? {} : {combo.sizeRange!},
      weather: combo.weather == null ? {} : {combo.weather!},
      timeOfDay: combo.timeOfDay == null ? {} : {combo.timeOfDay!},
    );
    // ▲▲▲ ここまで修正 ▲▲▲

    _applyFiltersToSearcher(searcher, loopFilterState);
    searcher.query('');

    final futureResponse = searcher.responses.first;
    futureResponse.whenComplete(() => searcher.dispose());
    return futureResponse;
  }).toList();

  // すべての検索が完了するのを待つ
  final responses = await Future.wait(searchFutures);

  // 全ての検索結果(hits)を一つのリストにまとめ、重複を削除する
  final allPosts = {
    for (var response in responses)
      for (var hit in response.hits)
        hit['objectID'] as String: Post.fromAlgolia(hit),
  }.values.toList();

  // 最終的な結果を並び替える
  allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return allPosts;
}

void _applyFiltersToSearcher(
  HitsSearcher searcher,
  DiscoverFilterState filter,
) {
  // facetFiltersは単純なAND条件として構築
  final facetFilters = <String>[];
  if (filter.squidTypes.isNotEmpty) {
    facetFilters.addAll(filter.squidTypes.map((type) => 'squidType:$type'));
  }
  if (filter.weather.isNotEmpty) {
    facetFilters.addAll(filter.weather.map((w) => 'weather:$w'));
  }
  if (filter.timeOfDay.isNotEmpty) {
    facetFilters.addAll(filter.timeOfDay.map((t) => 'timeOfDay:$t'));
  }
  if (filter.prefecture != null) {
    facetFilters.add('region:${filter.prefecture}');
  }

  // numericFiltersも単純なAND条件として構築
  final numericFilters = <String>[];
  if (filter.sizeRanges.isNotEmpty) {
    numericFilters.addAll(
      filter.sizeRanges
          .map((r) {
            switch (r) {
              case '0-20':
                return 'squidSize: 0 TO 20';
              case '20-35':
                return 'squidSize: 20 TO 35';
              case '35-50':
                return 'squidSize: 35 TO 50';
              case '50以上':
                return 'squidSize >= 50';
              default:
                return '';
            }
          })
          .where((f) => f.isNotEmpty),
    );
  }

  if (filter.periodDays != null) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final past = now - (filter.periodDays! * 24 * 60 * 60 * 1000);
    numericFilters.add('createdAt: $past TO $now');
  }

  // Algoliaに設定を適用 (disjunctiveFacetsはもう使いません)
  searcher.applyState(
    (state) => state.copyWith(
      facetFilters: facetFilters,
      numericFilters: numericFilters,
      facets: {'squidType', 'weather', 'region', 'timeOfDay'}.toList(),
    ),
  );
}

@riverpod
Future<int> discoverHitCount(DiscoverHitCountRef ref) async {
  // discoverTimelineの結果を再利用する
  final posts = await ref.watch(discoverTimelineProvider.future);
  return posts.length;
}

// --- UI定義 (変更なし) ---
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: const FilterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: const Text('タイムライン'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'みつける'),
            Tab(text: 'フォロー中'),
            Tab(text: 'Today'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterSheet,
        child: const Icon(Icons.filter_list),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TimelineView(provider: discoverTimelineProvider),
          _TimelineView(provider: followingTimelineProvider),
          _TimelineView(provider: todayTimelineProvider),
        ],
      ),
    );
  }
}

class _TimelineView extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<Post>>> provider;
  const _TimelineView({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsyncValue = ref.watch(provider);
    return postsAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('エラーが発生しました: $err')),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(child: Text('投稿はまだありません。'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(provider),
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) => PostGridCard(post: posts[index]),
          ),
        );
      },
    );
  }
}
