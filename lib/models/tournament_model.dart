import 'package:cloud_firestore/cloud_firestore.dart';

// TournamentRuleクラスは変更なし
class TournamentRule {
  final String judgingType;
  final String metric;
  final String rankingMetric;
  final String submissionLimit;
  final String postSource;
  final List<String> submissionFields;
  final List<String> timelineSortOptions;
  final int maxImageCount;

  TournamentRule({
    required this.judgingType,
    required this.metric,
    required this.rankingMetric,
    required this.submissionLimit,
    required this.postSource,
    required this.submissionFields,
    required this.timelineSortOptions,
    required this.maxImageCount,
  });

  factory TournamentRule.fromMap(Map<String, dynamic> map) {
    return TournamentRule(
      judgingType: map['judgingType'] ?? 'MANUAL',
      metric: map['metric'] ?? 'SIZE',
      rankingMetric: map['rankingMetric'] ?? 'MAX_VALUE',
      submissionLimit: map['submissionLimit'] ?? 'SINGLE_OVERWRITE',
      postSource: map['postSource'] ?? 'DEDICATED_POST',
      submissionFields: List<String>.from(map['submissionFields'] ?? []),
      timelineSortOptions: List<String>.from(map['timelineSortOptions'] ?? []),
      maxImageCount: map['maxImageCount'] ?? 1,
    );
  }
}

class Tournament {
  final String id;
  final String name;
  final String bannerUrl;
  final DateTime startDate; 
  final DateTime endDate;
  final TournamentRule rule;
  final String? eligibleRank;
  final int participantCount;
  final String? lpType;       
  final String? lpUrl;      
  final int? displayOrder; 
  final String? status;  

  Tournament({
    required this.id,
    required this.name,
    required this.bannerUrl,
    required this.startDate,
    required this.endDate,
    required this.rule,
    this.eligibleRank,
    this.participantCount = 0,
    this.lpType,
    this.lpUrl,
    this.displayOrder,
    this.status, 
  });

  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tournament(
      id: doc.id,
      name: data['name'] ?? '無題の大会',
      bannerUrl: data['bannerUrl'] ?? '',
      startDate: (data['startDate'] as Timestamp? ?? Timestamp.now()).toDate(), 
      endDate: (data['endDate'] as Timestamp).toDate(),
      rule: TournamentRule.fromMap(data['rule'] ?? {}),
      eligibleRank: data['eligibleRank'],
      participantCount: data['participantCount'] ?? 0,
      lpType: data['lpType'],
      lpUrl: data['lpUrl'],
      displayOrder: data['displayOrder'],
      status: data['status'], 
    );
  }
}