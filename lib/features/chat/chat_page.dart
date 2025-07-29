import 'package:flutter/material.dart';
import '../../widgets/common_app_bar.dart';
import 'tabs/friends_tab_view.dart';
import 'tabs/talks_tab_view.dart';
import 'tabs/user_search_tab_view.dart';
import 'create_group_page.dart';

class ChatPage extends StatefulWidget {
  final int initialIndex;
  const ChatPage({super.key, this.initialIndex = 1});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
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
    return Scaffold(
      appBar: CommonAppBar(
        title: const Text('チャット'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateGroupPage(),
                ),
              );
            },
            tooltip: '新しいグループを作成',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ともだち'),
            Tab(text: 'トーク'),
            Tab(text: '友達を見つける'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [FriendsTabView(), TalksTabView(), UserSearchTabView()],
      ),
    );
  }
}
