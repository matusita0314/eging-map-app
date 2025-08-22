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
      if (mounted) setState(() => _isLoading = false);
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
      extendBodyBehindAppBar: true,
      body: Container(
        // 背景グラデーション
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : _userDoc == null
                  ? const Center(child: Text('ユーザー情報が取得できませんでした。', style: TextStyle(color: Colors.white)))
                  : NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          // フローティング風AppBar
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  Expanded(
                                    child: Text(
                                      widget.challenge.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF13547a),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 48), // IconButtonのスペースを確保して中央揃え
                                ],
                              ),
                            ),
                          ),
                        ];
                      },
                      body: _buildProgressView(),
                    ),
        ),
      ),
    );
  }

  Widget _buildProgressView() {
    final userData = _userDoc!.data() as Map<String, dynamic>;
    final challengeData = widget.challenge;

    num currentValue = 0;
    num threshold = 0;
    String unit = '';

    switch (challengeData.type) {
      case 'totalCatches':
        currentValue = userData['totalCatches'] ?? 0;
        threshold = challengeData.threshold;
        unit = '杯';
        break;
      case 'maxSize':
        currentValue = userData['maxSize'] ?? 0;
        threshold = challengeData.threshold;
        unit = 'cm';
        break;
    }

    final double progress = (threshold > 0)
        ? (currentValue / threshold).clamp(0.0, 1.0)
        : 0.0;
    final num remaining = (threshold - currentValue).clamp(0, threshold);

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // 全体を中央揃えに
              children: [
                // 詳細文章は左寄せのままにする
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    challengeData.description,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold, // 太字に変更
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '現在の状況',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  '$currentValue $unit / $threshold $unit',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF13547a),
                  ),
                ),
                const SizedBox(height: 24),
                // 虹色のプログレスバー
                RainbowLinearProgressIndicator(progress: progress),
                const SizedBox(height: 24),
                Text(
                  progress >= 1.0
                      ? '🎉 ミッション達成！🎉'
                      : 'あと ${remaining.toStringAsFixed(0)} $unit で達成',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: progress >= 1.0 ? Colors.green.shade600 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// 虹色のプログレスバーを描画するカスタムWidget
class RainbowLinearProgressIndicator extends StatelessWidget {
  final double progress;

  const RainbowLinearProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FractionallySizedBox(
          widthFactor: progress,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.indigo,
                  Colors.purple,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}