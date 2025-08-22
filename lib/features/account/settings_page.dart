import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  bool _likesEnabled = true;
  bool _savesEnabled = true;
  bool _commentsEnabled = true;
  bool _followEnabled = true;
  bool _dmEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (userDoc.exists &&
          userDoc.data()!.containsKey('notificationSettings')) {
        final settings =
            userDoc.data()!['notificationSettings'] as Map<String, dynamic>;
        setState(() {
          _likesEnabled = settings['likes'] ?? true;
          _savesEnabled = settings['saves'] ?? true;
          _commentsEnabled = settings['comments'] ?? true;
          _followEnabled = settings['follow'] ?? true;
          _dmEnabled = settings['dm'] ?? true;
        });
      }
    } catch (e) {
      debugPrint("設定の読み込みに失敗しました: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
            'notificationSettings': {key: value}
          }, SetOptions(merge: true)); // ★ .update() から SetOptions(merge: true) に変更
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('設定の更新に失敗しました: $e')));
      }
    }
  }
  
  // ★★★ UI構造を全面的に刷新 ★★★
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        // ★ 背景グラデーション
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
                // ★ フローティングAppBar
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
                        const Expanded(child: Text('通知設定', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13547a)))),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // ★ 設定項目をカードで囲む
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias, // 角を丸くする
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            title: '「DM」の通知',
                            subtitle: '他のユーザーからダイレクトメッセージを受け取ったときに通知を受け取ります。',
                            value: _dmEnabled,
                            onChanged: (newValue) {
                              setState(() => _dmEnabled = newValue);
                              _updateSetting('dm', newValue);
                            },
                          ),
                          _buildSwitchTile(
                            title: '「フォロー」の通知',
                            subtitle: '他のユーザーにフォローされたときに通知を受け取ります。',
                            value: _followEnabled,
                            onChanged: (newValue) {
                              setState(() => _followEnabled = newValue);
                              _updateSetting('follow', newValue);
                            },
                          ),
                          _buildSwitchTile(
                            title: '「いいね」の通知',
                            subtitle: '自分の投稿に「いいね」されたときに通知を受け取ります。',
                            value: _likesEnabled,
                            onChanged: (newValue) {
                              setState(() => _likesEnabled = newValue);
                              _updateSetting('likes', newValue);
                            },
                          ),
                          _buildSwitchTile(
                            title: '「コメント」の通知',
                            subtitle: '自分の投稿にコメントされたときに通知を受け取ります。',
                            value: _commentsEnabled,
                            onChanged: (newValue) {
                              setState(() => _commentsEnabled = newValue);
                              _updateSetting('comments', newValue);
                            },
                          ),
                          _buildSwitchTile(
                            title: '「保存」の通知',
                            subtitle: '自分の投稿が他のユーザーに保存されたときに通知を受け取ります。',
                            value: _savesEnabled,
                            onChanged: (newValue) {
                              setState(() => _savesEnabled = newValue);
                              _updateSetting('saves', newValue);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0, // ★ 余白を調整
      ),
    );
  }
}