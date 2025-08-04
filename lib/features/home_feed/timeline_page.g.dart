// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$followingFeedNotifierHash() =>
    r'7b6c332de724c01a48a23bc650010c0d9f27d184';

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
String _$todayFeedNotifierHash() => r'1c029b38629d77e23d4818d81bb9f0f6d50ada16';

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
