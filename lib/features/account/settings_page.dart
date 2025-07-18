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

  // 各通知設定の状態を保持する変数
  bool _likesEnabled = true;
  bool _savesEnabled = true;
  bool _commentsEnabled = true;
  bool _followEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Firestoreから現在の通知設定を読み込む
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
        });
      }
    } catch (e) {
      print("設定の読み込みに失敗しました: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 通知設定を更新する
  Future<void> _updateSetting(String key, bool value) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'notificationSettings.$key': value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('設定の更新に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
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
    );
  }

  // SwitchListTileを構築するヘルパーメソッド
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
    );
  }
}
