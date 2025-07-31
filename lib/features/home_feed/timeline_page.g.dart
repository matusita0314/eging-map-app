// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$followingFeedNotifierHash() =>
    r'dde671f03e46d61f95de81d4ef6c43988dbb3777';

/// See also [FollowingFeedNotifier].
@ProviderFor(FollowingFeedNotifier)
final followingFeedNotifierProvider =
    AsyncNotifierProvider<FollowingFeedNotifier, List<Post>>.internal(
      FollowingFeedNotifier.new,
      name: r'followingFeedNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$followingFeedNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FollowingFeedNotifier = AsyncNotifier<List<Post>>;
String _$todayFeedNotifierHash() => r'd281b47089f8bf270005b56d3e3c06cead3f2034';

/// See also [TodayFeedNotifier].
@ProviderFor(TodayFeedNotifier)
final todayFeedNotifierProvider =
    AsyncNotifierProvider<TodayFeedNotifier, List<Post>>.internal(
      TodayFeedNotifier.new,
      name: r'todayFeedNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$todayFeedNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TodayFeedNotifier = AsyncNotifier<List<Post>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
