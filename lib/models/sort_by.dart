enum SortBy {
  createdAt('createdAt_desc', '新着順'),
  squidSize('squidSize_desc', 'サイズ順'),
  likeCount('likeCount_desc', 'いいね数順');

  const SortBy(this.value, this.displayName);

  final String value;
  final String displayName;

  @override
  String toString() => value;
}
