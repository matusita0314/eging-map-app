import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/following_provider.dart';
import '../../account/account.dart';

// 検索結果のユーザー情報を表すモデル
class SearchedUser {
  final String id;
  final String displayName;
  final String photoUrl;

  SearchedUser.fromAlgolia(Map<String, dynamic> hit)
    : id = hit['objectID'],
      displayName = hit['displayName'] ?? '名無しさん',
      photoUrl = hit['photoUrl'] ?? '';
}

// 検索結果を保持するProvider
final searchResultsProvider = StateProvider<List<SearchedUser>>((ref) => []);

class UserSearchTabView extends ConsumerStatefulWidget {
  const UserSearchTabView({super.key});

  @override
  ConsumerState<UserSearchTabView> createState() => _UserSearchTabViewState();
}

class _UserSearchTabViewState extends ConsumerState<UserSearchTabView> {
  final _searchController = TextEditingController();
  late final HitsSearcher _searcher;
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _searcher = HitsSearcher(
      applicationID: 'H43CZ7GND1',
      apiKey: '7d86d0716d7f8d84984e54f95f7b4dfa',
      indexName: 'users',
    );

    _searcher.responses.listen((response) {
      if (response.query.isEmpty) {
        if (mounted) {
           ref.read(searchResultsProvider.notifier).state = [];
        }
        return;
      }

      final users = response.hits
          .map((hit) => SearchedUser.fromAlgolia(hit))
          .toList();
      
      if (mounted) {
        ref.read(searchResultsProvider.notifier).state = users;
      }
    });

    _searchController.addListener(() {
      final query = _searchController.text;

      if (query.isEmpty) {
        // 検索バーが空なら、結果リストを空にする
        ref.read(searchResultsProvider.notifier).state = [];
      } else {
        _searcher.query(query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final followingState = ref.watch(followingNotifierProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ユーザー名で検索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
          ),
        ),
        Expanded(
          child: followingState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('エラー: $err')),
            data: (followingIds) {
              if (searchResults.isEmpty && _searchController.text.isNotEmpty) {
                return const Center(child: Text('ユーザーが見つかりません。'));
              }
              final displayResults = searchResults
                  .where((user) => user.id != _currentUser.uid)
                  .toList();

              return ListView.builder(
                itemCount: displayResults.length,
                itemBuilder: (context, index) {
                  final user = displayResults[index];
                  final isFollowing = followingIds.contains(user.id);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(user.photoUrl)
                          : null,
                      child: user.photoUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(user.displayName),
                    trailing: ElevatedButton(
                      onPressed: () => ref
                          .read(followingNotifierProvider.notifier)
                          .handleFollow(user.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing
                            ? Colors.white
                            : Colors.blue,
                        foregroundColor: isFollowing
                            ? Colors.blue
                            : Colors.white,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      child: Text(isFollowing ? 'フォロー中' : 'フォロー'),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MyPage(userId: user.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
