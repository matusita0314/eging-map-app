// lib/features/home_feed/widgets/floating_tab_bar.dart (アンダーライン形式)

import 'package:flutter/material.dart';

// フローティングタブデータクラス
class FloatingTab {
  final IconData icon;
  final String text;

  const FloatingTab({
    required this.icon,
    required this.text,
  });
}

// カスタムフローティングタブバー
class FloatingTabBar extends StatelessWidget {
  final TabController controller;
  final int currentIndex;
  final List<FloatingTab> tabs;

  const FloatingTabBar({
    super.key,
    required this.controller,
    required this.currentIndex,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      // ▼▼▼【変更点①】背景の装飾を少しシンプルに調整 ▼▼▼
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.bottomCenter, // 全体を下揃えに
        children: [
          // --- 1. 背景でスライドする青い「バー」 ---
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / tabs.length;
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                // ▼▼▼【変更点②】バーの位置を計算 ▼▼▼
                left: itemWidth * currentIndex,
                // バーの幅
                width: itemWidth,
                // バーの高さ
                height: 4, 
                child: Container(
                  // ▼▼▼【変更点③】バー自体のデザイン ▼▼▼
                  margin: EdgeInsets.symmetric(horizontal: itemWidth * 0.25), // バーの幅をアイテム幅の50%に
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
          // --- 2. アイコンとテキストの列 ---
          Row(
            children: tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isSelected = index == currentIndex;

              // ▼▼▼【変更点④】選択/非選択時の色とスタイルを調整 ▼▼▼
              final color = isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600];
              final fontWeight = isSelected ? FontWeight.bold : FontWeight.normal;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => controller.animateTo(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          color: color,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.text,
                          style: TextStyle(
                            color: color,
                            fontWeight: fontWeight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}