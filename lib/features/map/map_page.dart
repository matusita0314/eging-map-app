import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../post/add_post_page.dart';
import '../../widgets/post_bottom_sheet.dart';
import '../post/post_detail_page.dart';
import '../../widgets/squid_loading_indicator.dart';

class MapPage extends StatefulWidget {
  final LatLng? initialFocusLocation;
  final String? focusedPostId;
  const MapPage({super.key, this.initialFocusLocation, this.focusedPostId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  static const LatLng _initialPosition = LatLng(35.681236, 139.767125);
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _iconsLoaded = false;
  
  BitmapDescriptor? _squidIcon;
  BitmapDescriptor? _tappedSquidIcon;
  Set<Marker> _markers = {};
  Marker? _tappedMarker; 

  final Map<String, Post> _postsCache = {};
  StreamSubscription<QuerySnapshot>? _postsSubscription;

  Post? _selectedPost;
  bool _isDarkMap = false;
  bool _didRunInitialSetup = false;
  double _minSquidSize = 0;
  double _dateRangeInDays = 7.0;
  MapType _currentMapType = MapType.normal;
  Timer? _filterDebounceTimer;
  String? _lastQueryHash;
  bool _isUpdating = false;
  final Duration _updateThrottle = const Duration(milliseconds: 5000);

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
    print("--- MapPage initState ---");

    if (widget.initialFocusLocation != null) {
      _currentPosition = widget.initialFocusLocation;
      _isLoading = false; 
    } else {
      _getCurrentLocation();
    }

    if (widget.focusedPostId != null) {
      FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.focusedPostId)
          .get()
          .then((doc) {
        if (doc.exists) {
          final post = Post.fromFirestore(doc);
          // 取得した投稿をキャッシュに直接追加する
          _postsCache[post.id] = post;
          if (_iconsLoaded) {
            _updateMarkersFromCache();
          }
        }
      });
    }
    _initializePostsStream(); // 通常のストリームも開始
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRunInitialSetup) {
      _loadCustomIcons();
      _didRunInitialSetup = true;
    }
  }
    
  @override
  void dispose() {
    _postsSubscription?.cancel();
    _filterDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomIcons() async {
    try {
      final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      String squidAssetPath;
      String tappedSquidAssetPath;

      if (devicePixelRatio >= 3.0) {
        squidAssetPath = 'assets/images/squid_144.png';
        tappedSquidAssetPath = 'assets/images/squid_red_144.png';
      } else if (devicePixelRatio >= 2.0) {
        squidAssetPath = 'assets/images/squid_96.png';
        tappedSquidAssetPath = 'assets/images/squid_red_96.png';
      } else {
        squidAssetPath = 'assets/images/squid_48.png';
        tappedSquidAssetPath = 'assets/images/squid_red_48.png';
      }

      final normalIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: const Size(48, 48), devicePixelRatio: devicePixelRatio),
        squidAssetPath,
      );
      final tappedIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: const Size(56, 56), devicePixelRatio: devicePixelRatio),
        tappedSquidAssetPath,
      );

      if (mounted) {
        setState(() {
          _squidIcon = normalIcon;
          _tappedSquidIcon = tappedIcon;
          _iconsLoaded = true;
        });
        _rebuildAllMarkers();
      }
    } catch (e) {
      print("[_loadCustomIcons] アイコン読み込みでエラーが発生: $e");
    }
  }

  void _initializePostsStream() {
    final queryHash = '${_minSquidSize}_$_dateRangeInDays';
    if (_lastQueryHash == queryHash) return;
    _lastQueryHash = queryHash;
    _postsSubscription?.cancel();

    final startDate = DateTime.now().subtract(Duration(days: _dateRangeInDays.round()));
    Query query = FirebaseFirestore.instance.collection('posts').where('createdAt', isGreaterThanOrEqualTo: startDate);
    if (_minSquidSize > 0) {
      query = query.where('squidSize', isGreaterThanOrEqualTo: _minSquidSize);
    }
    _postsSubscription = query.snapshots().listen(_handlePostsSnapshot);
  }

  // 🔥 スナップショット処理を最適化
  void _handlePostsSnapshot(QuerySnapshot snapshot) {
    if (!mounted ) return;
    if (!_iconsLoaded || _isUpdating) return;
    _isUpdating = true;
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
    _postsCache.addAll(changedPosts);
    deletedPostIds.forEach(_postsCache.remove);
    _updateMarkersFromCache();
    Future.delayed(_updateThrottle, () { _isUpdating = false; });
  }

  // 🔥 キャッシュからマーカーを効率的に更新
  void _updateMarkersFromCache() {
    if (!mounted) return;

    final newMarkers = <Marker>{};
    for (final post in _postsCache.values) {
      newMarkers.add(_createMarkerFromPost(post));
    }
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
    final bool isFocused = post.id == widget.focusedPostId;

    return Marker(
      markerId: MarkerId(post.id),
      position: post.location,
      icon: isFocused 
          ? (_tappedSquidIcon ?? BitmapDescriptor.defaultMarker) 
          : (_squidIcon ?? BitmapDescriptor.defaultMarker),
      zIndex: isFocused ? 1.0 : 0.0,
      onTap: () {
        setState(() {
          _selectedPost = post;
        });
      },
    );
  }

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
      // 新規投稿用のマーカー以外の状態は変更しない
      _markers.removeWhere((m) => m.markerId.value == 'tapped_location');
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
  }

  @override
  Widget build(BuildContext context) {

    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _onAddPostButtonPressed,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const SquidLoadingIndicator()
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? _initialPosition,
              zoom: 12.0,
            ),
            onMapCreated: _onMapCreated,
            onTap: _onMapTapped,
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            mapType: _currentMapType,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          if (canPop)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
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
                    // 戻るボタン
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF13547a)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // タイトル
                    const Expanded(
                      child: Text(
                        '釣果ポイント',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF13547a),
                        ),
                      ),
                    ),
                    // 右側のスペース（戻るボタンとのバランスをとるため）
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          
          _buildFilterChips(),
          _buildDateRangeSlider(),
          _buildMapTypeButton(),
          
          if (_selectedPost != null)
            // ウィジェットを画面外にドラッグして閉じる操作を検知
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // 最小サイズ(0.15)より小さくなったら閉じる
                if (notification.extent <= 0.15) {
                  setState(() {
                    _selectedPost = null;
                  });
                }
                return true;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.35, // 初期表示の高さ (35%)
                minChildSize: 0.15,      // 最小の高さ (15%)
                maxChildSize: 0.8,       // 最大の高さ (80%)
                builder: (context, scrollController) {
                  return PostBottomSheet(
                    post: _selectedPost!,
                    scrollController: scrollController, // 必須：中のリストと連携させる
                    onNavigateToDetail: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PostDetailPage(post: _selectedPost!),
                      ));
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapTypeButton() {
    return Positioned(
      bottom: 120,
      right: 10,
      child: Container(  // Containerを追加
      width: 60,      // 希望のサイズに調整
      height: 60,     // 希望のサイズに調整
      child: FloatingActionButton(
        heroTag: null,
        mini: true,
        onPressed: _showMapTypeDialog,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        tooltip: '表示設定',
        child: Icon(
          _currentMapType == MapType.satellite ? Icons.map : Icons.satellite,
          size: 35,  // アイコンサイズも調整
        ),
      ),
    ),
    );
  }

  Widget _buildFilterChips() {
  return Positioned(
    bottom: 200,
    right: 10,
    child: Container(
      width: 60,  // サイズを指定
      height: 60, // 幅と高さを同じに
      child: FloatingActionButton(
        heroTag: null,
        elevation: 6,
        backgroundColor: Colors.white,
        mini: true,
        onPressed: _showSizeFilterSheet,
        child: const Icon(
          Icons.straighten,
          size: 35,  // アイコンサイズを調整
          color: Colors.black54,
        ),
      ),
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