import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'discover_filter_provider.g.dart'; // build_runnerで自動生成

// フィルターの状態を保持するクラス
class DiscoverFilterState {
  // 並び替え順（デフォルトは新着順）
  final String sortBy;
  // TODO: ここに他のフィルター条件（地域、サイズなど）を追加していく

  DiscoverFilterState({
    this.sortBy = 'createdAt_desc', // Algoliaのインデックス名と合わせる
  });

  DiscoverFilterState copyWith({
    String? sortBy,
  }) {
    return DiscoverFilterState(
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

// フィルターの状態を操作・管理するNotifier
@Riverpod(keepAlive: true)
class DiscoverFilterNotifier extends _$DiscoverFilterNotifier {
  @override
  DiscoverFilterState build() {
    // 初期状態
    return DiscoverFilterState();
  }

  // 並び替え順を更新するメソッド
  void updateSortBy(String newSortBy) {
    state = state.copyWith(sortBy: newSortBy);
  }

  // TODO: 他のフィルターを更新するメソッドもここに追加していく
}