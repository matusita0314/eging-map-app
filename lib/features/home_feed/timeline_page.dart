import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import '../../providers/discover_filter_provider.dart';

import '../../models/post_model.dart';
import '../../widgets/post_grid_card.dart';
import '../../providers/following_provider.dart';
import 'widgets/filter_sheet.dart';
import '../../providers/chat_provider.dart';
import '../../providers/unread_notifications_provider.dart';
import '../chat/chat_page.dart';
import '../notifications/notification_page.dart';


part 'timeline_page.g.dart';

@Riverpod(keepAlive: true)
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

@Riverpod(keepAlive: true)
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

@Riverpod(keepAlive: true)
Future<List<Post>> discoverTimeline(DiscoverTimelineRef ref) async {
  final filter = ref.watch(discoverFilterNotifierProvider);
  final squidTypesToSearch = filter.squidTypes.isEmpty ? {null} : filter.squidTypes;
  final sizeRangesToSearch = filter.sizeRanges.isEmpty ? {null} : filter.sizeRanges;
  final weatherToSearch = filter.weather.isEmpty ? {null} : filter.weather;
  final timeOfDayToSearch = filter.timeOfDay.isEmpty ? {null} : filter.timeOfDay;
  final searchCombinations = <({String? squidType, String? sizeRange, String? weather, String? timeOfDay})>[];
  for (final squidType in squidTypesToSearch) {
    for (final sizeRange in sizeRangesToSearch) {
      for (final weather in weatherToSearch) {
        for (final timeOfDay in timeOfDayToSearch) {
          if (squidType == null && sizeRange == null && weather == null && timeOfDay == null && (squidTypesToSearch.length > 1 || sizeRangesToSearch.length > 1 || weatherToSearch.length > 1 || timeOfDayToSearch.length > 1)) {
            continue;
          }
          searchCombinations.add((squidType: squidType, sizeRange: sizeRange, weather: weather, timeOfDay: timeOfDay));
        }
      }
    }
  }
  final searchFutures = searchCombinations.map((combo) {
    final searcher = HitsSearcher(applicationID: 'H43CZ7GND1', apiKey: '7d86d0716d7f8d84984e54f95f7b4dfa', indexName: 'posts_${filter.sortBy.value}');
    final loopFilterState = filter.copyWith(squidTypes: combo.squidType == null ? {} : {combo.squidType!}, sizeRanges: combo.sizeRange == null ? {} : {combo.sizeRange!}, weather: combo.weather == null ? {} : {combo.weather!}, timeOfDay: combo.timeOfDay == null ? {} : {combo.timeOfDay!});
    _applyFiltersToSearcher(searcher, loopFilterState);
    searcher.query('');
    final futureResponse = searcher.responses.first;
    futureResponse.whenComplete(() => searcher.dispose());
    return futureResponse;
  }).toList();
  final responses = await Future.wait(searchFutures);
  final allPosts = { for (var response in responses) for (var hit in response.hits) hit['objectID'] as String: Post.fromAlgolia(hit) }.values.toList();
  allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return allPosts;
}

void _applyFiltersToSearcher(HitsSearcher searcher, DiscoverFilterState filter) {
  final facetFilters = <String>[];
  if (filter.squidTypes.isNotEmpty) { facetFilters.addAll(filter.squidTypes.map((type) => 'squidType:$type')); }
  if (filter.weather.isNotEmpty) { facetFilters.addAll(filter.weather.map((w) => 'weather:$w')); }
  if (filter.timeOfDay.isNotEmpty) { facetFilters.addAll(filter.timeOfDay.map((t) => 'timeOfDay:$t')); }
  if (filter.prefecture != null) { facetFilters.add('region:${filter.prefecture}'); }
  final numericFilters = <String>[];
  if (filter.sizeRanges.isNotEmpty) {
    numericFilters.addAll(filter.sizeRanges.map((r) {
      switch (r) {
        case '0-20': return 'squidSize: 0 TO 20';
        case '20-35': return 'squidSize: 20 TO 35';
        case '35-50': return 'squidSize: 35 TO 50';
        case '50以上': return 'squidSize >= 50';
        default: return '';
      }
    }).where((f) => f.isNotEmpty));
  }
  if (filter.periodDays != null) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final past = now - (filter.periodDays! * 24 * 60 * 60 * 1000);
    numericFilters.add('createdAt: $past TO $now');
  }
  searcher.applyState((state) => state.copyWith(facetFilters: facetFilters, numericFilters: numericFilters, facets: {'squidType', 'weather', 'region', 'timeOfDay'}.toList()));
}

@riverpod
Future<int> discoverHitCount(DiscoverHitCountRef ref) async {
  final posts = await ref.watch(discoverTimelineProvider.future);
  return posts.length;
}

// --- UI定義 ---
// ▼▼▼【修正】StatefulWidget を ConsumerStatefulWidget に変更 ▼▼▼
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});
  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
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
    
    super.build(context);

    final unreadChatCount = ref.watch(unreadChatCountProvider).value ?? 0;
    final unreadNotificationCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        // 左上の友達検索アイコン
        leading: IconButton(
          icon: const Icon(Icons.search),
          tooltip: '友達を見つける',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ChatPage(initialIndex: 2)), // 友達を見つけるタブ
          ),
        ),
        title: const Text('タイムライン'),
        // 右上のチャット・通知アイコン
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$unreadChatCount'),
              isLabelVisible: unreadChatCount > 0,
              child: const Icon(Icons.chat_outlined),
            ),
            tooltip: 'チャット',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ChatPage(initialIndex: 1)), // トークタブ
            ),
          ),
          IconButton(
            icon: Badge(
              label: Text('$unreadNotificationCount'),
              isLabelVisible: unreadNotificationCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'お知らせ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const NotificationPage()),
            ),
          ),
        ],
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

// タイムライン表示用の共通ウィジェット (変更なし)
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