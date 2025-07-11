// lib/pages/tournament_page.dart (エントリーチェック機能追加版)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tournament_dashboard.dart';
import 'tournament_terms_page.dart';

class TournamentPage extends StatefulWidget {
  const TournamentPage({super.key});

  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> {
  final String _currentTournamentId = '2025-07'; // 仮の大会ID
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // エントリーチェック中かどうかの状態
  bool _isCheckingEntry = false;

  @override
  Widget build(BuildContext context) {
    return _buildLandingPage();
  }

  // LPを構築するウィジェット
  Widget _buildLandingPage() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '最強エギンガー決定戦',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 10, color: Colors.blueAccent)],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_currentTournamentId 大会開催中！',
              style: const TextStyle(fontSize: 20, color: Colors.blueAccent),
            ),
            const SizedBox(height: 40),
            // 「ENTRY !!」ボタン
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 10,
              ),
              onPressed: _isCheckingEntry
                  ? null
                  : () async {
                      // チェック中はボタンを無効化
                      setState(() {
                        _isCheckingEntry = true;
                      });

                      try {
                        // エントリー済みか確認
                        final entryDoc = await FirebaseFirestore.instance
                            .collection('tournaments')
                            .doc(_currentTournamentId)
                            .collection('entries')
                            .doc(_currentUser.uid)
                            .get();

                        if (mounted) {
                          if (entryDoc.exists) {
                            // エントリー済みの場合
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('すでにエントリー済みです。')),
                            );
                          } else {
                            // まだエントリーしていない場合
                            Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (context) => TournamentTermsPage(
                                  tournamentId: _currentTournamentId,
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラーが発生しました: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isCheckingEntry = false;
                          });
                        }
                      }
                    },
              child: _isCheckingEntry
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : const Text(
                      'ENTRY !!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            // 「エントリー済みの方はこちら」ボタン
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TournamentDashboardPage(
                      tournamentId: _currentTournamentId,
                    ),
                  ),
                );
              },
              child: const Text(
                'エントリー済みの方はこちら >',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
