import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/discover_filter_provider.dart';
import '../../../models/sort_by.dart';
import '../timeline_page.dart';

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});
  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  static const Map<String, List<String>> regions = {
    '北海道': ['北海道'],
    '東北': ['青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'],
    '関東': ['茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県'],
    '中部': ['新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県', '静岡県', '愛知県'],
    '近畿': ['三重県', '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県'],
    '中国': ['鳥取県', '島根県', '岡山県', '広島県', '山口県'],
    '四国': ['徳島県', '香川県', '愛媛県', '高知県'],
    '九州・沖縄': ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県'],
  };
  
  // UIで使う定数
  static const List<String> squidTypes = ['アオリイカ', 'コウイカ', 'ヤリイカ', 'スルメイカ', 'ヒイカ', 'モンゴウイカ'];
  static const List<String> weatherOptions = ['快晴', '晴れ', '曇り', '雨'];
  static const List<String> timeOfDayOptions = ['朝', '昼', '夜'];
  static const List<String> sizeRanges = ['0-20', '20-35', '35-50', '50以上'];

  String? _selectedRegion;
  List<String> _currentPrefectures = [];

  @override
  void initState() {
    super.initState();
    final initialPrefecture = ref.read(discoverFilterNotifierProvider).prefecture;
    if (initialPrefecture != null) {
      for (var region in regions.entries) {
        if (region.value.contains(initialPrefecture)) {
          _selectedRegion = region.key;
          _currentPrefectures = region.value;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(discoverFilterNotifierProvider);
    final filterNotifier = ref.read(discoverFilterNotifierProvider.notifier);
    final hitCountAsync = ref.watch(discoverHitCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('絞り込み検索'),
        leading: const CloseButton(),
        actions: [ TextButton(onPressed: () { filterNotifier.resetFilters(); setState(() { _selectedRegion = null; _currentPrefectures = []; }); }, child: const Text('リセット')) ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('並び替え'),
          Wrap(spacing: 8.0, children: SortBy.values.map((sort) => ChoiceChip(label: Text(sort.displayName), selected: filterState.sortBy == sort, onSelected: (s) { if(s) filterNotifier.updateSortBy(sort); })).toList()),
          _buildSectionTitle('期間'),
          Wrap(spacing: 8.0, children: [ ChoiceChip(label: const Text('一週間'), selected: filterState.periodDays == 7, onSelected: (s) => filterNotifier.setPeriod(s ? 7 : null)), ChoiceChip(label: const Text('一か月'), selected: filterState.periodDays == 30, onSelected: (s) => filterNotifier.setPeriod(s ? 30 : null)), ChoiceChip(label: const Text('一年'), selected: filterState.periodDays == 365, onSelected: (s) => filterNotifier.setPeriod(s ? 365 : null)), ChoiceChip(label: const Text('すべて'), selected: filterState.periodDays == null, onSelected: (s) { if (s) filterNotifier.setPeriod(null); }) ]),
          _buildSectionTitle('地域'),
          DropdownButtonFormField<String>(value: _selectedRegion, hint: const Text('地方を選択'), isExpanded: true, items: regions.keys.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => setState(() { _selectedRegion = v; _currentPrefectures = (v != null) ? regions[v]! : []; filterNotifier.setPrefecture(null); })),
          const SizedBox(height: 16),
          if (_selectedRegion != null) DropdownButtonFormField<String>(value: filterState.prefecture, hint: const Text('都道府県を選択'), isExpanded: true, items: _currentPrefectures.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => filterNotifier.setPrefecture(v)),
          _buildSectionTitle('イカの種類'),
          Wrap(spacing: 8.0, children: squidTypes.map((type) => FilterChip(label: Text(type), selected: filterState.squidTypes.contains(type), onSelected: (_) => filterNotifier.toggleSquidType(type))).toList()),
          _buildSectionTitle('サイズ (cm)'),
          Wrap(spacing: 8.0, children: sizeRanges.map((range) => FilterChip(label: Text(range), selected: filterState.sizeRanges.contains(range), onSelected: (_) => filterNotifier.toggleSizeRange(range))).toList()),
          _buildSectionTitle('天気'),
          Wrap(spacing: 8.0, children: weatherOptions.map((weather) => FilterChip(label: Text(weather), selected: filterState.weather.contains(weather), onSelected: (_) => filterNotifier.toggleWeather(weather))).toList()),
          _buildSectionTitle('時間帯'),
          Wrap(spacing: 8.0, children: timeOfDayOptions.map((time) => FilterChip(label: Text(time), selected: filterState.timeOfDay.contains(time), onSelected: (_) => filterNotifier.toggleTimeOfDay(time))).toList()),
          // --- 気温・水温のUIは削除 ---
        ],
      ),
      bottomNavigationBar: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.of(context).pop(), child: hitCountAsync.when(data: (c) => Text('$c件 ヒット!!'), loading: () => const CircularProgressIndicator(), error: (e,s) => const Text('エラー')))),
    );
  }
  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(top: 24.0, bottom: 8.0), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)));
}