// lib/map_page.dart (完全版・最終版)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'common_app_bar.dart';
import 'post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_detail_page.dart';
import 'add_post_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controller = Completer();
  // GoogleMapController? _mapController;
  static const LatLng _initialPosition = LatLng(35.681236, 139.767125); // 東京駅
  LatLng? _currentPosition;
  bool _isLoading = true;

  // 新しいピン関連の変数
  Marker? _tappedMarker;
  BitmapDescriptor? _squidIcon;

  // フィルター用の状態変数
  double _minSquidSize = 0;
  double _dateRangeInDays = 7.0;

  @override
  void initState() {
    super.initState();
    _loadCustomIcon();
    _getCurrentLocation();
  }

  Future<void> _loadCustomIcon() async {
    // squid_icon.pngがアセットに存在することを確認してください
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/squid_icon.png',
      );
      if (mounted) {
        setState(() {
          _squidIcon = icon;
        });
      }
    } catch (e) {
      print('カスタムアイコンの読み込みに失敗しました: $e');
    }
  }

  Query _buildFilteredQuery() {
    final startDate = DateTime.now().subtract(
      Duration(days: _dateRangeInDays.round()),
    );
    Query query = FirebaseFirestore.instance
        .collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: startDate);

    if (_minSquidSize > 0) {
      query = query.where('squidSize', isGreaterThanOrEqualTo: _minSquidSize);
    }
    return query;
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _animateToPosition(_currentPosition!);
      }
    } catch (e) {
      print('位置情報の取得中にエラーが発生しました: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _animateToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 14.0),
      ),
    );
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _tappedMarker = Marker(
        markerId: const MarkerId('tapped_location'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    });
  }

  void _onAddPostButtonPressed() {
    if (_tappedMarker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マップをタップして投稿する場所を選択してください。')),
      );
      return;
    }

    // ★★★ 新しい投稿ページに画面遷移 ★★★
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddPostPage(location: _tappedMarker!.position),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'マップ'),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPostButtonPressed,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _buildFilteredQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('エラー: ${snapshot.error}'));
              }

              Set<Marker> markers = {};
              if (snapshot.hasData) {
                markers = snapshot.data!.docs.map((doc) {
                  final post = Post.fromFirestore(doc);
                  return Marker(
                    markerId: MarkerId(post.id),
                    position: post.location,
                    icon: _squidIcon ?? BitmapDescriptor.defaultMarker,
                    infoWindow: InfoWindow(
                      title: 'イカ ${post.squidSize} cm',
                      snippet: 'ヒットエギ: ${post.egiName}',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PostDetailPage(post: post),
                          ),
                        );
                      },
                    ),
                  );
                }).toSet();
              }

              if (_tappedMarker != null) {
                markers.add(_tappedMarker!);
              }

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition ?? _initialPosition,
                  zoom: 12.0,
                ),
                onMapCreated: (GoogleMapController controller) {
                  if (!_controller.isCompleted) {
                    _controller.complete(controller);
                  }
                },
                onTap: _onMapTapped,
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              );
            },
          ),
          _buildFilterChips(),
          _buildDateRangeSlider(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Positioned(
      top: 10,
      left: 10,
      child: ActionChip(
        avatar: const Icon(Icons.straighten, size: 16),
        label: Text(
          _minSquidSize > 0 ? '${_minSquidSize.round()} cm以上' : 'サイズ',
        ),
        onPressed: _showSizeFilterSheet,
        elevation: 4,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildDateRangeSlider() {
    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: GestureDetector(
        onHorizontalDragStart: (_) {},
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('表示期間: 過去 ${_dateRangeInDays.round()} 日間'),
                Slider(
                  value: _dateRangeInDays,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${_dateRangeInDays.round()}日',
                  onChanged: (double value) =>
                      setState(() => _dateRangeInDays = value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSizeFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'イカの最小サイズ: ${_minSquidSize.round()} cm',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Slider(
                    value: _minSquidSize,
                    min: 0,
                    max: 50,
                    divisions: 10,
                    label: '${_minSquidSize.round()} cm',
                    onChanged: (double value) {
                      setModalState(() {
                        _minSquidSize = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('リセット'),
                        onPressed: () {
                          setState(() => _minSquidSize = 0);
                          Navigator.pop(context);
                        },
                      ),
                      ElevatedButton(
                        child: const Text('適用'),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
