// lib/providers/discover_feed_provider.dart

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import '../models/post_model.dart';
import 'discover_filter_provider.dart';
import '../models/sort_by.dart';

part 'discover_feed_provider.g.dart';

class DiscoverFeedState {
  final List<Post> posts;
  final int hitCount;
  final bool noMorePosts;

  DiscoverFeedState({
    this.posts = const [],
    this.hitCount = 0,
    this.noMorePosts = false,
  });

  DiscoverFeedState copyWith({
    List<Post>? posts,
    int? hitCount,
    bool? noMorePosts,
  }) {
    return DiscoverFeedState(
      posts: posts ?? this.posts,
      hitCount: hitCount ?? this.hitCount,
      noMorePosts: noMorePosts ?? this.noMorePosts,
    );
  }
}

typedef SearchCombination = ({
  String? squidType,
  String? sizeRange,
  String? weather,
  String? timeOfDay
});


@Riverpod(keepAlive: true)
class DiscoverFeedNotifier extends _$DiscoverFeedNotifier {
  final Map<SearchCombination, HitsSearcher> _searchers = {};
  final _limit = 3;
  final Map<SearchCombination, bool> _hasMorePageMap = {};
  bool _isFetchingNextPage = false;
  bool get _noMorePostsToFetch => !_hasMorePageMap.containsValue(true);

  @override
  Future<DiscoverFeedState> build() async {
    final filter = ref.watch(discoverFilterNotifierProvider);

    for (final searcher in _searchers.values) {
      searcher.dispose();
    }
    _searchers.clear();
    _hasMorePageMap.clear();

    final searchCombinations = _createSearchCombinations(filter);

    if (searchCombinations.isEmpty) {
      return DiscoverFeedState();
    }

    final searchFutures = searchCombinations.map((combo) {
      final searcher = _createSearcher(filter.sortBy.value);
      _searchers[combo] = searcher;
      _applyFiltersToSearcher(searcher, filter, combo, 0);
      return searcher.responses.first;
    }).toList();

    final responses = await Future.wait(searchFutures);

    for (var i = 0; i < responses.length; i++) {
      final response = responses[i];
      final combo = searchCombinations[i];
      _hasMorePageMap[combo] = response.page < response.nbPages - 1;
    }

    final allPosts = <String, Post>{};
    for (final response in responses) {
      for (final hit in response.hits) {
        final post = Post.fromAlgolia(hit);
        allPosts[post.id] = post;
      }
    }
    final postsFromAlgolia = allPosts.values.toList();

    postsFromAlgolia.sort((a, b) {
      switch (filter.sortBy) {
        case SortBy.likeCount:
          return b.likeCount.compareTo(a.likeCount);
        case SortBy.squidSize:
          return b.squidSize.compareTo(a.squidSize);
        case SortBy.createdAt:
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    
    final totalHits = responses.fold<int>(0, (sum, res) => sum + res.nbHits);

    return DiscoverFeedState(
      posts: postsFromAlgolia,
      hitCount: totalHits,
      noMorePosts: _noMorePostsToFetch,
    );
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isReloading || _isFetchingNextPage || _noMorePostsToFetch) {
      return;
    }
    
    try {
      _isFetchingNextPage = true; // 読み込み開始

      final currentState = state.value;
      if (currentState == null) return;

      final filter = ref.read(discoverFilterNotifierProvider);

      final List<Future<SearchResponse>> nextFutures = [];
      final List<SearchCombination> activeCombos = [];

      _searchers.forEach((combo, searcher) {
        if (_hasMorePageMap[combo] == true) {
          searcher.applyState((s) => s.copyWith(page: (s.page ?? 0) + 1));
          nextFutures.add(searcher.responses.first);
          activeCombos.add(combo);
        }
      });

      if (nextFutures.isEmpty) {
        state = AsyncData(currentState.copyWith(noMorePosts: true));
        return;
      }
      
      final newResponses = await Future.wait(nextFutures);
      final allPosts = { for (var p in currentState.posts) p.id: p };

      for (var i = 0; i < newResponses.length; i++) {
        final response = newResponses[i];
        final combo = activeCombos[i];
        for (final hit in response.hits) {
          final post = Post.fromAlgolia(hit);
          allPosts[post.id] = post;
        }
        _hasMorePageMap[combo] = response.page < response.nbPages - 1;
      }

      final updatedPosts = allPosts.values.toList();

      updatedPosts.sort((a, b) {
        switch (filter.sortBy) {
          case SortBy.likeCount:
            return b.likeCount.compareTo(a.likeCount);
          case SortBy.squidSize:
            return b.squidSize.compareTo(a.squidSize);
          case SortBy.createdAt:
          default:
            return b.createdAt.compareTo(a.createdAt);
        }
      });

      state = AsyncData(DiscoverFeedState(
          posts: updatedPosts,
          hitCount: currentState.hitCount,
          noMorePosts: _noMorePostsToFetch,
      ));
    } finally {
      _isFetchingNextPage = false; // 処理が完了したら必ずフラグを降ろす
    }
  }


  List<SearchCombination> _createSearchCombinations(DiscoverFilterState filter) {
    final squidTypesToSearch = filter.squidTypes.isEmpty ? {null} : filter.squidTypes;
    final sizeRangesToSearch = filter.sizeRanges.isEmpty ? {null} : filter.sizeRanges;
    final weatherToSearch = filter.weather.isEmpty ? {null} : filter.weather;
    final timeOfDayToSearch = filter.timeOfDay.isEmpty ? {null} : filter.timeOfDay;

    final combinations = <SearchCombination>[];
    for (final squidType in squidTypesToSearch) {
      for (final sizeRange in sizeRangesToSearch) {
        for (final weather in weatherToSearch) {
          for (final timeOfDay in timeOfDayToSearch) {
            if (squidType == null && sizeRange == null && weather == null && timeOfDay == null &&
                (squidTypesToSearch.length > 1 || sizeRangesToSearch.length > 1 || weatherToSearch.length > 1 || timeOfDayToSearch.length > 1)) {
              continue;
            }
            combinations.add((squidType: squidType, sizeRange: sizeRange, weather: weather, timeOfDay: timeOfDay));
          }
        }
      }
    }
    return combinations;
  }
  
  void _applyFiltersToSearcher(HitsSearcher searcher, DiscoverFilterState baseFilter, SearchCombination combo, int page) {
    final numericFilters = <String>[];
    if (baseFilter.periodDays != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final past = now - (baseFilter.periodDays! * 24 * 60 * 60 * 1000);
      numericFilters.add('createdAt >= $past');
    }
    if (combo.sizeRange != null) {
      switch (combo.sizeRange) {
        case '0-20':  numericFilters.addAll(['squidSize >= 0', 'squidSize <= 20']); break;
        case '20-35': numericFilters.addAll(['squidSize > 20', 'squidSize <= 35']); break;
        case '35-50': numericFilters.addAll(['squidSize > 35', 'squidSize <= 50']); break;
        case '50以上': numericFilters.add('squidSize > 50'); break;
      }
    }

    final facetFilters = <String>[];
    if (baseFilter.prefecture != null) {
      facetFilters.add('region:${baseFilter.prefecture}');
    }
    if (combo.squidType != null) {
      facetFilters.add('squidType:${combo.squidType}');
    }
    if (combo.weather != null) {
      facetFilters.add('weather:${combo.weather}');
    }
    if (combo.timeOfDay != null) {
      facetFilters.add('timeOfDay:${combo.timeOfDay}');
    }

    searcher.applyState((state) => state.copyWith(
      page: page,
      hitsPerPage: _limit,
      numericFilters: numericFilters,
      facetFilters: facetFilters,
    ));
  }

  HitsSearcher _createSearcher(String sortByValue) {
    final indexName = sortByValue.startsWith('posts_') ? sortByValue : 'posts_$sortByValue';

    return HitsSearcher(
      applicationID: 'H43CZ7GND1',
      apiKey: '7d86d0716d7f8d84984e54f95f7b4dfa',
      indexName: indexName,
    );
  }

  @override
  void dispose() {
    for (final searcher in _searchers.values) {
      searcher.dispose();
    }
  }
}