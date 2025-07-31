// lib/models/post_model.dart (初期状態)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final List<String> imageUrls;
  final List<String> thumbnailUrls;
  final DateTime createdAt;
  final LatLng location;
  final String weather;
  final double? airTemperature;
  final double? waterTemperature;
  final String? caption;
  final double squidSize;
  final double? weight;
  final String egiName;
  final String? egiMaker;
  final String? tackleRod;
  final String? tackleReel;
  final String? tackleLine;
  final int likeCount;
  final int commentCount;
  final String? squidType;
  final String? region;
  final String? timeOfDay;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.imageUrls,
    required this.thumbnailUrls,
    required this.createdAt,
    required this.location,
    required this.weather,
    this.airTemperature,
    this.waterTemperature,
    this.caption,
    required this.squidSize,
    this.weight,
    required this.egiName,
    this.egiMaker,
    this.tackleRod,
    this.tackleReel,
    this.tackleLine,
    required this.likeCount,
    required this.commentCount,
    this.squidType,
    this.region, 
    this.timeOfDay,

  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint point = data['location'] ?? const GeoPoint(0, 0);
    Timestamp timestamp = data['createdAt'] ?? Timestamp.now();

    final imageUrlsData = data['imageUrls'] ?? [];
    final thumbnailUrlsData = data['thumbnailUrls'] ?? [];

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '名無しさん',
      userPhotoUrl: data['userPhotoUrl'],
      imageUrls: List<String>.from(imageUrlsData),
      thumbnailUrls: List<String>.from(thumbnailUrlsData),
      createdAt: timestamp.toDate(),
      location: LatLng(point.latitude, point.longitude),
      weather: data['weather'] ?? '',
      airTemperature: (data['airTemperature'])?.toDouble(),
      waterTemperature: (data['waterTemperature'])?.toDouble(),
      caption: data['caption'],
      squidSize: (data['squidSize'] ?? 0.0).toDouble(),
      weight: (data['weight'])?.toDouble(),
      egiName: data['egiName'] ?? (data['egiType'] ?? ''),
      egiMaker: data['egiMaker'],
      tackleRod: data['tackleRod'],
      tackleReel: data['tackleReel'],
      tackleLine: data['tackleLine'],
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      squidType: data['squidType'],
      region: data['region'],
      timeOfDay: data['timeOfDay'], 
    );
  }

  factory Post.fromAlgolia(Map<String, dynamic> data) {
  
    final geo = data['_geoloc'] as Map<String, dynamic>?;
    final location = (geo != null)
        ? LatLng(geo['lat'], geo['lng'])
        : const LatLng(0, 0);
    final imageUrlsData = data['imageUrls'] ?? [];
    final thumbnailUrlsData = data['thumbnailUrls'] ?? [];

    return Post(
      id: data['objectID'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '名無しさん',
      userPhotoUrl: data['userPhotoUrl'],
      imageUrls: List<String>.from(imageUrlsData),
      thumbnailUrls: List<String>.from(thumbnailUrlsData),
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] ?? 0),
      location: location,
      weather: data['weather'] ?? '',
      airTemperature: (data['airTemperature'])?.toDouble(),
      waterTemperature: (data['waterTemperature'])?.toDouble(),
      caption: data['caption'],
      squidSize: (data['squidSize'] ?? 0.0).toDouble(),
      weight: (data['weight'])?.toDouble(),
      egiName: data['egiName'] ?? '',
      egiMaker: data['egiMaker'],
      tackleRod: data['tackleRod'],
      tackleReel: data['tackleReel'],
      tackleLine: data['tackleLine'],
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      squidType: data['squidType'],
      region: data['region'],
      timeOfDay: data['timeOfDay'], 
    );
  }
}
