import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/discover_filter_provider.dart';
import '../../../providers/discover_feed_provider.dart';

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
  
  static const List<String> squidTypes = ['アオリイカ', 'コウイカ', 'ヤリイカ', 'スルメイカ', 'ヒイカ', 'モンゴウイカ'];
  static const List<String> weatherOptions = ['快晴', '晴れ', '曇り', '雨'];
  static const List<String> timeOfDayOptions = ['朝', '昼', '夜'];
  static const List<String> sizeRanges = ['0-20', '20-35', '35-50', '50以上'];
  static const List<int?> periodOptions = [7, 30, 365, null]; // [null] が 'すべて' に対応
  static const Map<int?, String> periodLabels = {7: '一週間', 30: '一か月', 365: '一年', null: 'すべて'};


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
    final discoverFeedAsync = ref.watch(discoverFeedNotifierProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA), // 明るい背景色
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              // 3つの要素（左の空白、中央のタイトル、右のボタン）を均等に配置
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 【左側】右側のボタンと幅を合わせるための、透明で見えないプレースホルダー
                Opacity(
                  opacity: 0.0,
                  child: IgnorePointer( // タップも無効化
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('リセット'),
                    ),
                  ),
                ),

                // 【中央】タイトル
                const Text(
                  '絞り込み検索',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                // 【右側】実際のリセットボタン
                TextButton(
                  onPressed: () {
                    filterNotifier.resetFilters();
                    setState(() {
                      _selectedRegion = null;
                      _currentPrefectures = [];
                    });
                  },
                  child: const Text('リセット'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionContainer('期間', 
                  Wrap(spacing: 8.0, runSpacing: 8.0, children: periodOptions.map((p) => _buildChoiceChip<int?>(periodLabels[p]!, p, filterState.periodDays, (selected) => filterNotifier.setPeriod(selected))).toList()),
                ),
                _buildSectionContainer('地域', 
                  Column(
                    children: [
                      _buildDropdown(_selectedRegion, '地方を選択', regions.keys.toList(), (v) => setState(() { _selectedRegion = v; _currentPrefectures = (v != null) ? regions[v]! : []; filterNotifier.setPrefecture(null); })),
                      if (_selectedRegion != null) ...[
                        const SizedBox(height: 12),
                        _buildDropdown(filterState.prefecture, '都道府県を選択', _currentPrefectures, (v) => filterNotifier.setPrefecture(v)),
                      ]
                    ],
                  )
                ),
                _buildSectionContainer('イカの種類',
                  Wrap(spacing: 8.0, runSpacing: 8.0, children: squidTypes.map((type) => _buildFilterChip(type, filterState.squidTypes.contains(type), () => filterNotifier.toggleSquidType(type))).toList()),
                ),
                _buildSectionContainer('サイズ',
                  Wrap(spacing: 8.0, runSpacing: 8.0, children: sizeRanges.map((range) => _buildFilterChip(range, filterState.sizeRanges.contains(range), () => filterNotifier.toggleSizeRange(range))).toList()),
                ),
                 _buildSectionContainer('天気',
                  Wrap(spacing: 8.0, runSpacing: 8.0, children: weatherOptions.map((weather) => _buildFilterChip(weather, filterState.weather.contains(weather), () => filterNotifier.toggleWeather(weather))).toList()),
                ),
                _buildSectionContainer('時間帯',
                  Wrap(spacing: 8.0, runSpacing: 8.0, children: timeOfDayOptions.map((time) => _buildFilterChip(time, filterState.timeOfDay.contains(time), () => filterNotifier.toggleTimeOfDay(time))).toList()),
                ),
              ],
            ),
          ),
          // ★ フッターのボタン部分
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,-5))],
            ),
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                // ★ child の中で、通信状態に応じて表示を切り替える
                child: discoverFeedAsync.when(
                  // データ取得成功時
                  data: (feedState) => Text(
                    '${feedState.hitCount}件の投稿に絞り込む',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  // ローディング中
                  loading: () => const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  ),
                  error: (e, s) => const Text(
                    '件数の取得に失敗',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  // ★ フィルターセクションをカード化するヘルパー
  Widget _buildSectionContainer(String title, Widget content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // ★ 複数選択チップのヘルパー
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onPressed) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onPressed(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
      ),
      backgroundColor: Colors.white,
      selectedColor: Colors.blue.withOpacity(0.1),
      labelStyle: TextStyle(color: isSelected ? Colors.blue.shade800 : Colors.black87, fontWeight: FontWeight.w600),
      showCheckmark: false,
    );
  }
  
  // ★ 単一選択チップのヘルパー
  Widget _buildChoiceChip<T>(String label, T value, T? groupValue, ValueChanged<T> onSelected){
     final isSelected = value == groupValue;
     return ChoiceChip(
       label: Text(label),
       selected: isSelected,
       onSelected: (selected) { if(selected) onSelected(value); },
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
      ),
      backgroundColor: Colors.white,
      selectedColor: Colors.blue.withOpacity(0.1),
      labelStyle: TextStyle(color: isSelected ? Colors.blue.shade800 : Colors.black87, fontWeight: FontWeight.w600),
     );
  }
  
  // ★ ドロップダウンのヘルパー
  Widget _buildDropdown(String? value, String hint, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint),
      isExpanded: true,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}