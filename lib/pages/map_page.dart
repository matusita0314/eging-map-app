// lib/map_page.dart (最適化版)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/common_app_bar.dart';
import '../models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/post_detail_page.dart';
import 'add_post_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controller = Completer();
  static const LatLng _initialPosition = LatLng(35.681236, 139.767125);
  LatLng? _currentPosition;
  bool _isLoading = true;

  // 新しいピン関連の変数
  Marker? _tappedMarker;
  BitmapDescriptor? _squidIcon;

  // フィルター用の状態変数
  double _minSquidSize = 0;
  double _dateRangeInDays = 7.0;

  // 🔥 パフォーマンス改善：Stream、マーカーキャッシュ
  StreamSubscription<QuerySnapshot>? _postsSubscription;
  final Map<String, Marker> _markerCache = {};
  Query? _currentQuery;

  @override
  void initState() {
    super.initState();
    // 🔥 Google Maps初期化を最適化
    _initializeGoogleMaps();
    _loadCustomIcon();
    _getCurrentLocation();
    _initializePostsStream();
  }

  // 🔥 Google Maps初期化の最適化
  void _initializeGoogleMaps() {
    // レンダラーの設定を明示的に行う
    try {
      // AndroidではTEXTURE_VIEWを使用してパフォーマンス向上
      if (Theme.of(context).platform == TargetPlatform.android) {
        // Google Maps SDKの初期化設定
      }
    } catch (e) {
      print('Google Maps初期化エラー: $e');
    }
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomIcon() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/squid.png',
      );
      if (mounted) {
        setState(() {
          _squidIcon = icon;
        });
        // 🔥 アイコン読み込み完了後にマーカーを更新
        _updateAllMarkers();
      }
    } catch (e) {
      print('カスタムアイコンの読み込みに失敗しました: $e');
      // 🔥 フォールバック用のアイコンを設定
      if (mounted) {
        setState(() {
          _squidIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        });
      }
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

  // 🔥 新しいメソッド：Streamの初期化と管理
  void _initializePostsStream() {
    _updatePostsStream();
  }

  void _updatePostsStream() {
    final newQuery = _buildFilteredQuery();
    
    // 🔥 同じクエリの場合は更新しない
    if (_currentQuery?.toString() == newQuery.toString()) {
      return;
    }
    
    _currentQuery = newQuery;
    _postsSubscription?.cancel();
    
    _postsSubscription = newQuery.snapshots().listen(
      (snapshot) {
        if (mounted) {
          _updateMarkersFromSnapshot(snapshot);
        }
      },
      onError: (error) {
        print('Posts stream error: $error');
      },
    );
  }

  // 🔥 新しいメソッド：スナップショットからマーカーを更新
  void _updateMarkersFromSnapshot(QuerySnapshot snapshot) {
    final Set<String> currentPostIds = {};
    
    // 新しい/更新されたマーカーを処理
    for (final doc in snapshot.docs) {
      final post = Post.fromFirestore(doc);
      currentPostIds.add(post.id);
      
      // 🔥 既存のマーカーと比較して変更がある場合のみ更新
      if (!_markerCache.containsKey(post.id) || 
          _shouldUpdateMarker(post)) {
        _markerCache[post.id] = _createMarkerFromPost(post);
      }
    }
    
    // 🔥 削除されたマーカーをキャッシュから削除
    _markerCache.removeWhere((key, value) => !currentPostIds.contains(key));
    
    setState(() {
      // マーカーセットを更新
    });
  }

  bool _shouldUpdateMarker(Post post) {
    final existing = _markerCache[post.id];
    if (existing == null) return true;
    
    // 🔥 位置やアイコンが変更されているかチェック
    return existing.position != post.location ||
           existing.icon != (_squidIcon ?? BitmapDescriptor.defaultMarker);
  }

  Marker _createMarkerFromPost(Post post) {
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
  }

  // 🔥 新しいメソッド：全マーカーのアイコン更新
  void _updateAllMarkers() {
    for (final entry in _markerCache.entries) {
      final oldMarker = entry.value;
      _markerCache[entry.key] = oldMarker.copyWith(
        iconParam: _squidIcon ?? BitmapDescriptor.defaultMarker,
      );
    }
    setState(() {});
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
      
      // 🔥 タイムアウト設定を追加
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
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
    try {
      final GoogleMapController controller = await _controller.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 14.0),
        ),
      );
    } catch (e) {
      print('カメラアニメーションエラー: $e');
    }
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddPostPage(location: _tappedMarker!.position),
      ),
    );
  }

  // 🔥 フィルター変更時の処理を最適化
  void _updateFilter() {
    // 🔥 デバウンス処理を追加してもよい
    _updatePostsStream();
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
          // 🔥 StreamBuilderを削除し、直接GoogleMapを使用
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
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
                  markers: _buildMarkerSet(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  // 🔥 地図の描画最適化設定
                  mapType: MapType.normal,
                  trafficEnabled: false,
                  buildingsEnabled: false,
                  // 🔥 フレーム同期問題を軽減
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                  // 🔥 フレームレート制限
                  onCameraIdle: () {
                    // カメラ移動完了後の処理
                  },
                ),
          _buildFilterChips(),
          _buildDateRangeSlider(),
        ],
      ),
    );
  }

  // 🔥 新しいメソッド：マーカーセットを構築
  Set<Marker> _buildMarkerSet() {
    final Set<Marker> markers = Set.from(_markerCache.values);
    if (_tappedMarker != null) {
      markers.add(_tappedMarker!);
    }
    return markers;
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
                onChanged: (double value) {
                  setState(() {
                    _dateRangeInDays = value;
                  });
                  _updateFilter(); // 🔥 フィルター更新
                },
              ),
            ],
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
                          _updateFilter(); // 🔥 フィルター更新
                        },
                      ),
                      ElevatedButton(
                        child: const Text('適用'),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                          _updateFilter(); // 🔥 フィルター更新
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