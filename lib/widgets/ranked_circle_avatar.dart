import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RankedCircleAvatar extends StatelessWidget {
  final String? photoUrl;
  final String rank;
  final double radius;

  const RankedCircleAvatar({
    super.key,
    required this.photoUrl,
    required this.rank,
    required this.radius,
  });

  Color _getRankColor(String rank) {
    switch (rank) {
      case 'amateur':
        return Color.fromARGB(255, 210, 84, 25);
      case 'pro':
        return Color.fromARGB(255, 255, 60, 60);
      case 'beginner':
      default:
        return Color.fromARGB(255, 0, 163, 19);
    }
  }

  @override
  Widget build(BuildContext context) {
    // リングの太さ（半径の差）
    final double ringWidth = radius * 0.1; // 半径の10%をリングの太さにする

    return CircleAvatar(
      radius: radius + ringWidth,
      backgroundColor: _getRankColor(rank),
      child: CircleAvatar(
        radius: radius,
        backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
            ? CachedNetworkImageProvider(photoUrl!)
            : null,
        child: (photoUrl == null || photoUrl!.isEmpty)
            ? Icon(Icons.person, size: radius)
            : null,
      ),
    );
  }
}