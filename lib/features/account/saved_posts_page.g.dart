// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_posts_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$savedPostsHash() => r'7ca355dc0fc17d076b9b6758f20a5eb189baf737';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [savedPosts].
@ProviderFor(savedPosts)
const savedPostsProvider = SavedPostsFamily();

/// See also [savedPosts].
class SavedPostsFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [savedPosts].
  const SavedPostsFamily();

  /// See also [savedPosts].
  SavedPostsProvider call(String userId) {
    return SavedPostsProvider(userId);
  }

  @override
  SavedPostsProvider getProviderOverride(
    covariant SavedPostsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'savedPostsProvider';
}

/// See also [savedPosts].
class SavedPostsProvider extends AutoDisposeStreamProvider<List<Post>> {
  /// See also [savedPosts].
  SavedPostsProvider(String userId)
    : this._internal(
        (ref) => savedPosts(ref as SavedPostsRef, userId),
        from: savedPostsProvider,
        name: r'savedPostsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$savedPostsHash,
        dependencies: SavedPostsFamily._dependencies,
        allTransitiveDependencies: SavedPostsFamily._allTransitiveDependencies,
        userId: userId,
      );

  SavedPostsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    Stream<List<Post>> Function(SavedPostsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SavedPostsProvider._internal(
        (ref) => create(ref as SavedPostsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Post>> createElement() {
    return _SavedPostsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedPostsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SavedPostsRef on AutoDisposeStreamProviderRef<List<Post>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _SavedPostsProviderElement
    extends AutoDisposeStreamProviderElement<List<Post>>
    with SavedPostsRef {
  _SavedPostsProviderElement(super.provider);

  @override
  String get userId => (origin as SavedPostsProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
