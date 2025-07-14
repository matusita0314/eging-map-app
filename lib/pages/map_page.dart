import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/common_app_bar.dart';
import '../models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_post_page.dart';
import '../widgets/post_preview_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  static const LatLng _initialPosition = LatLng(35.681236, 139.767125);
  LatLng? _currentPosition;
  bool _isLoading = true;

  // マーカー関連
  Marker? _tappedMarker;
  BitmapDescriptor? _squidIcon;
  Set<Marker> _markers = {};

  // フィルター用の状態変数
  double _minSquidSize = 0;
  double _dateRangeInDays = 7.0;
  MapType _currentMapType = MapType.normal;

  // 🔥 パフォーマンス改善：Stream、デバウンス、効率化
  StreamSubscription<QuerySnapshot>? _postsSubscription;
  final Map<String, Post> _postsCache = {};
  Timer? _filterDebounceTimer;
  String? _lastQueryHash;

  // 🔥 フレームレート制御
  bool _isUpdating = false;
  final Duration _updateThrottle = const Duration(milliseconds: 100);

  final String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#263c3f"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#6b9a76"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#38414e"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#212a37"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9ca5b3"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#1f2835"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#f3d19c"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#2f3948"
        }
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#17263c"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#515c6d"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#17263c"
        }
      ]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadCustomIcon();
    _getCurrentLocation();
    _initializePostsStream();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _filterDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomIcon() async {
    try {
      // ★★★ 目標とするアイコンの横幅（ピクセル単位）★★★
      // この数値を変更することで、アイコンの大きさを自由に調整できます。
      // 例：80, 100, 120 など
      const int targetWidth = 130;

      // 1. アセットから画像の元データをバイトとして読み込む
      final ByteData byteData = await rootBundle.load(
        'assets/images/squid.png',
      );
      final Uint8List bytes = byteData.buffer.asUint8List();

      // 2. バイトデータを画像オブジェクトに変換
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth, // リサイズ品質向上のためのヒント
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      // 3. 新しいキャンバスを用意し、指定したサイズで画像を描画
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..filterQuality = FilterQuality.high;

      // 元画像の縦横比を維持して描画先のサイズを計算
      final double aspectRatio = originalImage.width / originalImage.height;
      final int targetHeight = (targetWidth / aspectRatio).round();

      // 指定したサイズでキャンバスに描画
      canvas.drawImageRect(
        originalImage,
        Rect.fromLTRB(
          0,
          0,
          originalImage.width.toDouble(),
          originalImage.height.toDouble(),
        ),
        Rect.fromLTRB(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        paint,
      );

      // 4. 再描画した画像をバイトデータに変換
      final ui.Image resizedImage = await pictureRecorder
          .endRecording()
          .toImage(targetWidth, targetHeight);
      final ByteData? resizedByteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List resizedBytes = resizedByteData!.buffer.asUint8List();

      // 5. リサイズ後のバイトデータからマーカーアイコンを生成
      if (mounted) {
        _squidIcon = BitmapDescriptor.fromBytes(resizedBytes);
        _rebuildAllMarkers(); // 既存マーカーも更新
      }
    } catch (e) {
      print('カスタムアイコンのリサイズと読み込みに失敗しました: $e');
      if (mounted) {
        _squidIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        );
        _rebuildAllMarkers();
      }
    }
  }

  // 🔥 クエリハッシュを生成してストリーム再作成を最小化
  String _generateQueryHash() {
    return '${_minSquidSize}_${_dateRangeInDays}';
  }

  void _initializePostsStream() {
    final queryHash = _generateQueryHash();
    if (_lastQueryHash == queryHash) return;

    _lastQueryHash = queryHash;
    _postsSubscription?.cancel();

    final startDate = DateTime.now().subtract(
      Duration(days: _dateRangeInDays.round()),
    );

    Query query = FirebaseFirestore.instance
        .collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: startDate);

    if (_minSquidSize > 0) {
      query = query.where('squidSize', isGreaterThanOrEqualTo: _minSquidSize);
    }

    _postsSubscription = query.snapshots().listen(
      _handlePostsSnapshot,
      onError: (error) {
        print('Posts stream error: $error');
      },
    );
  }

  // 🔥 スナップショット処理を最適化
  void _handlePostsSnapshot(QuerySnapshot snapshot) {
    if (!mounted || _isUpdating) return;

    _isUpdating = true;

    // 🔥 変更のみを処理
    final changedPosts = <String, Post>{};
    final deletedPostIds = <String>{};

    for (final change in snapshot.docChanges) {
      final post = Post.fromFirestore(change.doc);

      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          changedPosts[post.id] = post;
          break;
        case DocumentChangeType.removed:
          deletedPostIds.add(post.id);
          break;
      }
    }

    // キャッシュ更新
    _postsCache.addAll(changedPosts);
    for (final id in deletedPostIds) {
      _postsCache.remove(id);
    }

    // マーカー更新
    _updateMarkersFromCache();

    // 🔥 フレームレート制御
    Future.delayed(_updateThrottle, () {
      _isUpdating = false;
    });
  }

  // 🔥 キャッシュからマーカーを効率的に更新
  void _updateMarkersFromCache() {
    if (!mounted) return;

    final newMarkers = <Marker>{};

    for (final post in _postsCache.values) {
      newMarkers.add(_createMarkerFromPost(post));
    }

    // タップされたマーカーを追加
    if (_tappedMarker != null) {
      newMarkers.add(_tappedMarker!);
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  Marker _createMarkerFromPost(Post post) {
    return Marker(
      markerId: MarkerId(post.id),
      position: post.location,
      icon: _squidIcon ?? BitmapDescriptor.defaultMarker,
      onTap: () => _showPostPreview(post),
    );
  }

  void _showPostPreview(Post post) {
    // 既存のタップマーカーを削除
    if (_tappedMarker != null) {
      setState(() {
        _tappedMarker = null;
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PostPreviewSheet(post: post),
    );
  }

  // 🔥 全マーカーを再構築（アイコン変更時のみ）
  void _rebuildAllMarkers() {
    if (!mounted) return;
    _updateMarkersFromCache();
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
      _markers.removeWhere(
        (m) => m.markerId == const MarkerId('tapped_location'),
      );
      _tappedMarker = Marker(
        markerId: const MarkerId('tapped_location'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
      _markers.add(_tappedMarker!);
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

  // 🔥 デバウンス付きフィルター更新
  void _updateFilterWithDebounce() {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _initializePostsStream();
    });
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _showMapTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('地図タイプを選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapTypeOption(MapType.normal, '通常', Icons.map),
              _buildMapTypeOption(MapType.satellite, '衛星', Icons.satellite),
              _buildMapTypeOption(MapType.terrain, '地形', Icons.terrain),
              _buildMapTypeOption(MapType.hybrid, 'ハイブリッド', Icons.layers),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapTypeOption(MapType type, String title, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: _currentMapType == type
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        setState(() {
          _currentMapType = type;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    if (!_controller.isCompleted) {
      _controller.complete(controller);
    }

    try {
      await controller.setMapStyle(_darkMapStyle);
    } catch (e) {
      print('マップスタイルの適用に失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'マップ',
        actions: [
          IconButton(
            icon: Icon(
              _currentMapType == MapType.satellite
                  ? Icons.satellite
                  : Icons.map,
            ),
            onPressed: _showMapTypeDialog,
            tooltip: '地図タイプを変更',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPostButtonPressed,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition ?? _initialPosition,
                    zoom: 12.0,
                  ),
                  onMapCreated: _onMapCreated,
                  onTap: _onMapTapped,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: _currentMapType,
                  trafficEnabled: false,
                  buildingsEnabled: false,
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                ),
          _buildFilterChips(),
          _buildDateRangeSlider(),
          _buildMapTypeButton(),
        ],
      ),
    );
  }

  Widget _buildMapTypeButton() {
    return Positioned(
      top: 10,
      right: 10,
      child: FloatingActionButton(
        mini: true,
        onPressed: _toggleMapType,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        child: Icon(
          _currentMapType == MapType.satellite ? Icons.map : Icons.satellite,
        ),
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
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                  _updateFilterWithDebounce();
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
                          _updateFilterWithDebounce();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('適用'),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                          _updateFilterWithDebounce();
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
