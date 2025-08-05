// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$postStreamHash() => r'75ca4a3c443334daf39418ae9ca873138af672d1';

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

/// See also [postStream].
@ProviderFor(postStream)
const postStreamProvider = PostStreamFamily();

/// See also [postStream].
class PostStreamFamily extends Family<AsyncValue<Post>> {
  /// See also [postStream].
  const PostStreamFamily();

  /// See also [postStream].
  PostStreamProvider call(String postId) {
    return PostStreamProvider(postId);
  }

  @override
  PostStreamProvider getProviderOverride(
    covariant PostStreamProvider provider,
  ) {
    return call(provider.postId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'postStreamProvider';
}

/// See also [postStream].
class PostStreamProvider extends AutoDisposeStreamProvider<Post> {
  /// See also [postStream].
  PostStreamProvider(String postId)
    : this._internal(
        (ref) => postStream(ref as PostStreamRef, postId),
        from: postStreamProvider,
        name: r'postStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$postStreamHash,
        dependencies: PostStreamFamily._dependencies,
        allTransitiveDependencies: PostStreamFamily._allTransitiveDependencies,
        postId: postId,
      );

  PostStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.postId,
  }) : super.internal();

  final String postId;

  @override
  Override overrideWith(Stream<Post> Function(PostStreamRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: PostStreamProvider._internal(
        (ref) => create(ref as PostStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        postId: postId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Post> createElement() {
    return _PostStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PostStreamProvider && other.postId == postId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, postId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PostStreamRef on AutoDisposeStreamProviderRef<Post> {
  /// The parameter `postId` of this provider.
  String get postId;
}

class _PostStreamProviderElement extends AutoDisposeStreamProviderElement<Post>
    with PostStreamRef {
  _PostStreamProviderElement(super.provider);

  @override
  String get postId => (origin as PostStreamProvider).postId;
}

String _$userPostsHash() => r'3ec5beb6383bc3dbd7096157326b33ba752be595';

/// See also [userPosts].
@ProviderFor(userPosts)
const userPostsProvider = UserPostsFamily();

/// See also [userPosts].
class UserPostsFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [userPosts].
  const UserPostsFamily();

  /// See also [userPosts].
  UserPostsProvider call({required String userId, required SortBy sortBy}) {
    return UserPostsProvider(userId: userId, sortBy: sortBy);
  }

  @override
  UserPostsProvider getProviderOverride(covariant UserPostsProvider provider) {
    return call(userId: provider.userId, sortBy: provider.sortBy);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userPostsProvider';
}

/// See also [userPosts].
class UserPostsProvider extends StreamProvider<List<Post>> {
  /// See also [userPosts].
  UserPostsProvider({required String userId, required SortBy sortBy})
    : this._internal(
        (ref) => userPosts(ref as UserPostsRef, userId: userId, sortBy: sortBy),
        from: userPostsProvider,
        name: r'userPostsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userPostsHash,
        dependencies: UserPostsFamily._dependencies,
        allTransitiveDependencies: UserPostsFamily._allTransitiveDependencies,
        userId: userId,
        sortBy: sortBy,
      );

  UserPostsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
    required this.sortBy,
  }) : super.internal();

  final String userId;
  final SortBy sortBy;

  @override
  Override overrideWith(
    Stream<List<Post>> Function(UserPostsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserPostsProvider._internal(
        (ref) => create(ref as UserPostsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
        sortBy: sortBy,
      ),
    );
  }

  @override
  StreamProviderElement<List<Post>> createElement() {
    return _UserPostsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserPostsProvider &&
        other.userId == userId &&
        other.sortBy == sortBy;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);
    hash = _SystemHash.combine(hash, sortBy.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserPostsRef on StreamProviderRef<List<Post>> {
  /// The parameter `userId` of this provider.
  String get userId;

  /// The parameter `sortBy` of this provider.
  SortBy get sortBy;
}

class _UserPostsProviderElement extends StreamProviderElement<List<Post>>
    with UserPostsRef {
  _UserPostsProviderElement(super.provider);

  @override
  String get userId => (origin as UserPostsProvider).userId;
  @override
  SortBy get sortBy => (origin as UserPostsProvider).sortBy;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
