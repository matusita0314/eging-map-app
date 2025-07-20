import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../post/add_post_page.dart';
import '../../widgets/post_preview_sheet.dart';
// import 'package:geofire_common/geofire_common.dart';

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
  bool _isDarkMap = false;
  bool _didRunInitialSetup = false;

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
    _getCurrentLocation();
    _initializePostsStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRunInitialSetup) {
      _loadCustomIcon();
      _didRunInitialSetup = true;
    }
  }
    
  @override
  void dispose() {
    _postsSubscription?.cancel();
    _filterDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomIcon() async {
    try {

      // デバイスの画面密度を取得
      final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

      // 密度に応じて適切な画像を選択
      String assetPath;
      if (devicePixelRatio >= 3.0) {
        assetPath = 'assets/images/squid_144.png'; // 3x密度
      } else if (devicePixelRatio >= 2.0) {
        assetPath = 'assets/images/squid_96.png'; // 2x密度
      } else {
        assetPath = 'assets/images/squid_48.png'; // 1x密度
      }

      _squidIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(
          size: const Size(48, 48),
          devicePixelRatio: devicePixelRatio,
        ),
        assetPath,
      );

      if (mounted) {
        _rebuildAllMarkers();
      }
    } catch (e) {
      // フォールバック
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

  Future<void> _toggleMapStyle() async {
    // 現在の状態を反転させる
    final newIsDark = !_isDarkMap;
    // スタイルを適用する文字列を決定（ダークモードOFFならnull）
    final style = newIsDark ? _darkMapStyle : null;

    try {
      final controller = await _controller.future;
      // setMapStyleに文字列またはnullを渡す
      await controller.setMapStyle(style);
      // 成功したら状態を更新
      if (mounted) {
        setState(() {
          _isDarkMap = newIsDark;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('マップスタイルの適用に失敗しました。')));
    }
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
        // ダイアログ内の状態を管理するためにStatefulBuilderを使用
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('表示設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  const Text(
                    '地図タイプ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildMapTypeOption(MapType.normal, '通常', Icons.map),
                  _buildMapTypeOption(MapType.satellite, '衛星', Icons.satellite),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('ダークモード'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: _isDarkMap,
                    onChanged: (newValue) {
                      // スタイルを切り替えてからダイアログを閉じる
                      _toggleMapStyle().then((_) {
                        // ダイアログ内のスイッチ表示を即時更新
                        setDialogState(() {});
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
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

    // try {
    //   await controller.setMapStyle(_darkMapStyle);
    // } catch (e) {
    //   print('マップスタイルの適用に失敗しました: $e');
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        // ▼▼▼【変更】Textウィジェットで囲む ▼▼▼
        title: const Text('マップ'),
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
