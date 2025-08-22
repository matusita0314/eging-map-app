// lib/features/chat/chat_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/unread_notifications_provider.dart';
import '../notifications/notification_page.dart';
import 'tabs/friends_tab_view.dart';
import 'tabs/talks_tab_view.dart';
import 'tabs/user_search_tab_view.dart';
import 'create_group_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  final int initialIndex;
  const ChatPage({super.key, this.initialIndex = 1});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotificationCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CreateGroupPage()),
        ),
        backgroundColor: const Color.fromARGB(255, 31, 135, 196),
        child: const Icon(Icons.group_add, color: Colors.white),
        tooltip: '新しいグループを作成',
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFF13547a),
              Color(0xFF80d0c7),
            ],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // フローティング風ヘッダー
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF13547a)),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: '戻る',
                        ),
                        const Text(
                          'チャット',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13547a),
                          ),
                        ),
                        IconButton(
                          icon: Badge(
                            label: Text('$unreadNotificationCount'),
                            isLabelVisible: unreadNotificationCount > 0,
                            child: const Icon(Icons.notifications_outlined, color: Color(0xFF13547a)),
                          ),
                          tooltip: 'お知らせ',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const NotificationPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                // ピン留めされるタブバー
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: Container(
                      height: 55,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF13547a).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(35),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.all(4),
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF13547a),
                          tabs: const [
                            Tab(text: 'ともだち'),
                            Tab(text: 'トーク'),
                            Tab(text: 'みつける'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 1)),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: const [
                FriendsTabView(),
                TalksTabView(),
                UserSearchTabView()
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// TimelinePageから持ってきたStickyTabBar用のDelegateクラス
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});

  // timeline_page.dartに合わせて高さを70.0に設定
  @override
  double get minExtent => 55.0;
  @override
  double get maxExtent => 55.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Containerの高さをmaxExtentと一致させ、Centerでchildを中央に配置する
    return Container(
      height: maxExtent,
      color: Colors.transparent, // 背景のグラデーションが見えるように透明に
      child: Center(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
