// mission_detail_page.dart (修正版)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/challenge_model.dart';

class MissionDetailPage extends StatefulWidget {
  final Challenge challenge;
  const MissionDetailPage({super.key, required this.challenge});

  @override
  State<MissionDetailPage> createState() => _MissionDetailPageState();
}

class _MissionDetailPageState extends State<MissionDetailPage> {
  DocumentSnapshot? _userDoc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() {
        _userDoc = doc;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.challenge.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userDoc == null
          ? const Center(child: Text('ユーザー情報が取得できませんでした。'))
          : _buildProgressView(),
    );
  }

  Widget _buildProgressView() {
    final userData = _userDoc!.data() as Map<String, dynamic>;
    final challengeData = widget.challenge;

    num currentValue = 0;
    num threshold = 0;
    String unit = '';

    // ▼▼▼ switch文の中を修正 ▼▼▼
    switch (challengeData.type) {
      case 'totalCatches':
        currentValue = userData['totalCatches'] ?? 0;
        threshold = challengeData.threshold; // as dynamic が不要に
        unit = '杯';
        break;
      case 'maxSize':
        currentValue = userData['maxSize'] ?? 0;
        threshold = challengeData.threshold; // as dynamic が不要に
        unit = 'cm';
        break;
    }
    // ▲▲▲ ここまで修正 ▲▲▲

    final double progress = (threshold > 0)
        ? (currentValue / threshold).clamp(0.0, 1.0)
        : 0.0;
    final num remaining = (threshold - currentValue).clamp(0, threshold);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(challengeData.description, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 40),
          Text(
            '現在の状況: $currentValue $unit / $threshold $unit',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              progress >= 1.0
                  ? '🎉 達成！🎉'
                  : 'あと ${remaining.toStringAsFixed(0)} $unit で達成',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: progress >= 1.0 ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
