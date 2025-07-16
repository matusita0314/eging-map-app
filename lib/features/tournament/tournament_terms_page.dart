import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentTermsPage extends StatefulWidget {
  final String tournamentId;
  const TournamentTermsPage({super.key, required this.tournamentId});

  @override
  State<TournamentTermsPage> createState() => _TournamentTermsPageState();
}

class _TournamentTermsPageState extends State<TournamentTermsPage> {
  bool _isRegistering = false;
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // エントリー処理
  Future<void> _registerEntry() async {
    setState(() { _isRegistering = true; });

    try {
      // tournaments/{大会ID}/entries/{ユーザーID} にドキュメントを作成
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('entries')
          .doc(_currentUser.uid)
          .set({
            'entryDate': Timestamp.now(),
            'userName': _currentUser.displayName ?? '名無しさん',
            'userPhotoUrl': _currentUser.photoURL ?? '',
          });
      
      if (mounted) {
        // 成功したら、このページを閉じる
        Navigator.of(context).pop(true); // trueを返して成功を伝える
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エントリーに失敗しました: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isRegistering = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('大会利用規約')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('利用規約', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              'この大会に参加することにより、あなたは以下の規約に同意したものとみなされます。\n\n1. ルールを守って楽しく釣りをしましょう。\n2. 釣果のサイズや重さの偽装など、不正行為は禁止です。\n3. 運営の判断が最終決定となります。\n\n（ここに詳細な利用規約が 入ります）... ' * 10,
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isRegistering ? null : _registerEntry,
          child: _isRegistering
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
              : const Text('同意してエントリーする', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}