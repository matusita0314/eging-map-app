import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/post_model.dart';
import '../../models/sort_by.dart';
import '../../providers/chat_provider.dart';
import '../../providers/discover_filter_provider.dart';
import '../../providers/following_provider.dart';
import '../../providers/unread_notifications_provider.dart';
import '../../providers/discover_feed_provider.dart';
import '../../widgets/post_feed_card.dart';
import '../chat/chat_page.dart';
import '../notifications/notification_page.dart';
import 'widgets/filter_sheet.dart';

part 'timeline_page.g.dart';

final followingSortByProvider = StateProvider<SortBy>((ref) => SortBy.createdAt);
final todaySortByProvider = StateProvider<SortBy>((ref) => SortBy.createdAt);

// 「フォロー中」タブ用のProvider
@Riverpod(keepAlive: true)
class FollowingFeedNotifier extends _$FollowingFeedNotifier {
  DocumentSnapshot? _lastDoc;
  bool _noMorePosts = false;
  static const _limit = 5;

  @override
  Future<List<Post>> build() async {
    _lastDoc = null;
    _noMorePosts = false;
    final followingUsers = await ref.watch(followingNotifierProvider.future);
    if (followingUsers.isEmpty) return [];
    
    final snapshot = await _fetchPosts(followingUsers.toList());
    if (snapshot.docs.length < _limit) _noMorePosts = true;
    if (snapshot.docs.isNotEmpty) _lastDoc = snapshot.docs.last;
    return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  Future<QuerySnapshot> _fetchPosts(List<String> userIds) {
    // 並び替えの状態を監視
    final sortBy = ref.watch(followingSortByProvider);
    Query query = FirebaseFirestore.instance.collection('posts')
        .where('userId', whereIn: userIds)
        // vvv 動的に並び替え vvv
        .orderBy(sortBy.value.replaceFirst('_desc', ''), descending: true)
        .limit(_limit);
    final last = _lastDoc;
    if (last != null) query = query.startAfterDocument(last);
    return query.get();
  }

  Future<void> fetchNextPage() async {
    if (state.isReloading || _noMorePosts) return;
    final followingUsers = await ref.read(followingNotifierProvider.future);
    if (followingUsers.isEmpty) return;
    
    final snapshot = await _fetchPosts(followingUsers.toList());
    if (snapshot.docs.length < _limit) _noMorePosts = true;
    if (snapshot.docs.isNotEmpty) {
      _lastDoc = snapshot.docs.last;
      final newPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      state = AsyncData([...state.value!, ...newPosts]);
    }
  }
}

// 「Today」タブ用のProvider
@Riverpod(keepAlive: true)
class TodayFeedNotifier extends _$TodayFeedNotifier {
  DocumentSnapshot? _lastDoc;
  bool _noMorePosts = false;
  static const _limit = 5;

  @override
  Future<List<Post>> build() async {
    _lastDoc = null;
    _noMorePosts = false;
    final snapshot = await _fetchPosts();
    if (snapshot.docs.length < _limit) _noMorePosts = true;
    if (snapshot.docs.isNotEmpty) _lastDoc = snapshot.docs.last;
    return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  Future<QuerySnapshot> _fetchPosts() {
    // 並び替えの状態を監視
    final sortBy = ref.watch(todaySortByProvider);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    Query query = FirebaseFirestore.instance.collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: startOfToday)
        // vvv 動的に並び替え vvv
        .orderBy(sortBy.value.replaceFirst('_desc', ''), descending: true)
        .limit(_limit);
    final last = _lastDoc;
    if (last != null) query = query.startAfterDocument(last);
    return query.get();
  }

  Future<void> fetchNextPage() async {
    if (state.isReloading || _noMorePosts) return;
    final snapshot = await _fetchPosts();
    if (snapshot.docs.length < _limit) _noMorePosts = true;
    if (snapshot.docs.isNotEmpty) {
      _lastDoc = snapshot.docs.last;
      final newPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      state = AsyncData([...state.value!, ...newPosts]);
    }
  }
}

// --- UI定義 ---
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});
  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF13547a),
              Color(0xFF80d0c7),
            ],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // フローティング風AppBar
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search),
                          tooltip: '友達を見つける',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ChatPage(initialIndex: 2)),
                          ),
                        ),
                        const Expanded(
                          flex: 2,
                          child: SizedBox(
                            width: 140,
                            child: Text(
                              'ホーム',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF13547a),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Badge(
                            label: Text('$unreadChatCount'),
                            isLabelVisible: unreadChatCount > 0,
                            child: const Icon(Icons.chat_outlined),
                          ),
                          tooltip: 'チャット',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ChatPage(initialIndex: 1)),
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
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                // ピン留めされるタブバー
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF13547a).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(35),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.all(4),
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF13547a),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(text: 'みつける'),
                            Tab(text: 'フォロー中'),
                            Tab(text: 'Today'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 1)),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _AlgoliaTimelineFeedView(onFilterPressed: _showFilterSheet),
                _FirestoreTimelineFeedView(
                  provider: followingFeedNotifierProvider,
                  fetchNextPage: (ref) => ref.read(followingFeedNotifierProvider.notifier).fetchNextPage(),
                  sortByProvider: followingSortByProvider,
                ),
                _FirestoreTimelineFeedView(
                  provider: todayFeedNotifierProvider,
                  fetchNextPage: (ref) => ref.read(todayFeedNotifierProvider.notifier).fetchNextPage(),
                  sortByProvider: todaySortByProvider,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 70.0;

  @override
  double get maxExtent => 70.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.transparent,
      child: SizedBox(height: 75.0, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate != this;
  }
}

class _AlgoliaTimelineFeedView extends ConsumerWidget {
  final VoidCallback onFilterPressed;
  const _AlgoliaTimelineFeedView({required this.onFilterPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(discoverFeedNotifierProvider);
    
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('エラー: $err')),
      data: (feedState) {
        if (feedState.posts.isEmpty) {
          return Column(
            children: [
              _FilterHeader(onFilterPressed: onFilterPressed),
              const Expanded(
                child: Center(
                  child: Text(
                    '投稿はまだありません。\n'
                    '釣りに行こう！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels > notification.metrics.maxScrollExtent - 200) {
              ref.read(discoverFeedNotifierProvider.notifier).fetchNextPage();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(discoverFeedNotifierProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8.0),
              itemCount: feedState.posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FilterHeader(onFilterPressed: onFilterPressed);
                }
                final postIndex = index - 1;
                return PostFeedCard(post: feedState.posts[postIndex]);
              },
            ),
          ),
        );
      },
    );
  }
}

class _FilterHeader extends ConsumerWidget {
  final VoidCallback onFilterPressed;
  const _FilterHeader({required this.onFilterPressed});

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'squidType': return Colors.red.shade100;
      case 'sizeRange': return Colors.green.shade100;
      case 'weather': return Colors.orange.shade100;
      case 'timeOfDay': return Colors.purple.shade100;
      default: return Colors.grey.shade200;
    }
  }

  Widget _buildFilterChip(String label, String category, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 16),
        backgroundColor: _getColorForCategory(category),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(discoverFilterNotifierProvider);
    final filterNotifier = ref.read(discoverFilterNotifierProvider.notifier);

    final activeFilters = [
      ...filterState.squidTypes.map((e) => {'label': e, 'category': 'squidType', 'onDeleted': () => filterNotifier.toggleSquidType(e)}),
      ...filterState.sizeRanges.map((e) => {'label': e, 'category': 'sizeRange', 'onDeleted': () => filterNotifier.toggleSizeRange(e)}),
      ...filterState.weather.map((e) => {'label': e, 'category': 'weather', 'onDeleted': () => filterNotifier.toggleWeather(e)}),
      ...filterState.timeOfDay.map((e) => {'label': e, 'category': 'timeOfDay', 'onDeleted': () => filterNotifier.toggleTimeOfDay(e)}),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 230, 230, 230),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Text('🦑', style: TextStyle(fontSize: 25)),
                  onPressed: onFilterPressed,
                ),
                Expanded(
                  child: activeFilters.isEmpty
                      ? GestureDetector(
                          onTap: onFilterPressed,
                          child: const Text(
                            '←タップして検索条件を追加！',
                            style: TextStyle(color: Color.fromARGB(255, 98, 98, 98), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: activeFilters.map((filter) => 
                              _buildFilterChip(
                                filter['label'] as String,
                                filter['category'] as String,
                                filter['onDeleted'] as VoidCallback,
                              )
                            ).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 5),

          Wrap(
            spacing: 6.0,
            alignment: WrapAlignment.center,
            children: SortBy.values.map((sort) {
              return ChoiceChip(
                label: Text(sort.displayName),
                selected: filterState.sortBy == sort,
                onSelected: (isSelected) {
                  if (isSelected) {
                    filterNotifier.updateSortBy(sort);
                  }
                },
              );
            }).toList(),
          ),
          
          const Divider(height: 13,),
        ],
      ),
    );
  }
}

class _SortHeader extends ConsumerWidget {
  final StateProvider<SortBy> sortByProvider;
  const _SortHeader({required this.sortByProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSortBy = ref.watch(sortByProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        alignment: WrapAlignment.center,
        children: SortBy.values.map((sort) {
          return ChoiceChip(
            label: Text(sort.displayName),
            selected: currentSortBy == sort,
            onSelected: (isSelected) {
              if (isSelected) {
                ref.read(sortByProvider.notifier).state = sort;
              }
            },
          );
        }).toList(),
      ),
    );
  }
}

typedef FetchNextPageCallback = void Function(WidgetRef ref);

class _FirestoreTimelineFeedView extends ConsumerWidget {
  final AsyncNotifierProvider<AsyncNotifier<List<Post>>, List<Post>> provider;
  final FetchNextPageCallback fetchNextPage;
  final StateProvider<SortBy> sortByProvider;

  const _FirestoreTimelineFeedView({
    required this.provider, 
    required this.fetchNextPage,
    required this.sortByProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(provider);
    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('エラー: $err')),
      data: (posts) {
        if (posts.isEmpty) {
          return Column(
            children: [
              _SortHeader(sortByProvider: sortByProvider),
              const Expanded(
                child: Center(
                  child: Text(
                    '投稿はまだありません。',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels > notification.metrics.maxScrollExtent - 200) {
              fetchNextPage(ref);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(provider),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8.0),
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SortHeader(sortByProvider: sortByProvider);
                }
                final postIndex = index - 1;
                return PostFeedCard(post: posts[postIndex]);
              },
            ),
          ),
        );
      },
    );
  }
}