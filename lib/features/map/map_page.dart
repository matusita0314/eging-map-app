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

enum DateRangeOption { oneWeek, oneMonth, threeMonths, oneYear, allTime }

class MapPage extends StatefulWidget {
  final LatLng? initialFocusLocation;
  final String? focusedPostId;
  // ▼▼▼ AppBarを表示するかどうかを外部から受け取るためのプロパティを追加 ▼▼▼
  final bool showAppBarAsOverlay;

  const MapPage({
    super.key,
    this.initialFocusLocation,
    this.focusedPostId,
    this.showAppBarAsOverlay = false, // デフォルトは非表示
  });

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
  
  DateRangeOption _selectedDateRange = DateRangeOption.oneWeek;
  
  MapType _currentMapType = MapType.normal;
  Timer? _filterDebounceTimer;
  String? _lastQueryHash;
  // bool _isUpdating = false;
  // final Duration _updateThrottle = const Duration(milliseconds: 5000);

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
          _postsCache[post.id] = post;
          if (_iconsLoaded) {
            _updateMarkersFromCache();
          }
        }
      });
    }
    _initializePostsStream();
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

  void _initializePostsStream() {
    if (mounted) {
      setState(() {
        _postsCache.clear();
        _markers.clear();
        if (_tappedMarker != null) {
          _markers.add(_tappedMarker!);
        }
      });
    }
    final queryHash = '${_minSquidSize}_${_selectedDateRange.name}';
    if (_lastQueryHash == queryHash) return;
    _lastQueryHash = queryHash;
    _postsSubscription?.cancel();

    final startDate = _getStartDateForOption(_selectedDateRange);

    Query query = FirebaseFirestore.instance.collection('posts');
    
    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
    }
    if (_minSquidSize > 0) {
      query = query.where('squidSize', isGreaterThanOrEqualTo: _minSquidSize);
    }
    _postsSubscription = query.snapshots().listen(_handlePostsSnapshot);
  }

  DateTime? _getStartDateForOption(DateRangeOption option) {
    final now = DateTime.now();
    switch (option) {
      case DateRangeOption.oneWeek: return now.subtract(const Duration(days: 7));
      case DateRangeOption.oneMonth: return now.subtract(const Duration(days: 30));
      case DateRangeOption.threeMonths: return now.subtract(const Duration(days: 90));
      case DateRangeOption.oneYear: return now.subtract(const Duration(days: 365));
      case DateRangeOption.allTime: return null;
    }
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

void _handlePostsSnapshot(QuerySnapshot snapshot) {
  if (!mounted) return;

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
}

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
      onTap: () => setState(() => _selectedPost = post),
    );
  }

  void _rebuildAllMarkers() {
    if (!mounted) return;
    _updateMarkersFromCache();
  }

  Future<void> _toggleMapStyle() async {
    final newIsDark = !_isDarkMap;
    final style = newIsDark ? _darkMapStyle : null;

    try {
      final controller = await _controller.future;
      await controller.setMapStyle(style);
      if (mounted) {
        setState(() => _isDarkMap = newIsDark);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('マップスタイルの適用に失敗しました。')));
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
        setState(() => _isLoading = false);
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

  void _updateFilterWithDebounce() {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _initializePostsStream();
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    if (!_controller.isCompleted) {
      _controller.complete(controller);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _onAddPostButtonPressed,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
                
                if (widget.showAppBarAsOverlay)
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
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF13547a)),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
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
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                  ),

                _buildFilterButtonsOverlay(),

                if (_selectedPost != null)
                  NotificationListener<DraggableScrollableNotification>(
                    onNotification: (notification) {
                      if (notification.extent <= 0.15) {
                        setState(() => _selectedPost = null);
                      }
                      return true;
                    },
                    child: DraggableScrollableSheet(
                      initialChildSize: 0.35,
                      minChildSize: 0.15,
                      maxChildSize: 0.8,
                      builder: (context, scrollController) {
                        return PostBottomSheet(
                          post: _selectedPost!,
                          scrollController: scrollController,
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

  Widget _buildFilterButtonsOverlay() {
  return Positioned(
    bottom: 28,
    left: 0,  // 画面の左端から
    right: 80, // 画面の右端まで領域を確保
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center, // 子要素であるボタン群を中央に配置
      children: [
        _buildFilterButton(
          icon: Icons.date_range_outlined,
          label: _getLabelForDateOption(_selectedDateRange),
          onPressed: _showDateRangeSheet,
        ),
        _buildFilterButton(
          icon: Icons.straighten_outlined,
          label: 'サイズ',
          onPressed: _showSizeFilterSheet,
        ),
        _buildFilterButton(
          icon: _currentMapType == MapType.satellite
              ? Icons.map_outlined
              : Icons.satellite_alt_outlined,
          // labelを渡さないことでアイコンのみのボタンになる
          onPressed: _showMapTypeDialog,
        ),
      ],
    ),
  );
}

  Widget _buildFilterButton({
    required IconData icon,
    String? label,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: const Color(0xFF13547a)),
                if (label != null && label.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF13547a),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDateRangeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              const Text('表示期間', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8.0,
                children: DateRangeOption.values.map((option) {
                  final isSelected = _selectedDateRange == option;
                  return ChoiceChip(
                    label: Text(_getLabelForDateOption(option)),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedDateRange = option);
                      Navigator.pop(context);
                      _updateFilterWithDebounce();
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: const Color(0xFF13547a),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _getLabelForDateOption(DateRangeOption option) {
    switch (option) {
      case DateRangeOption.oneWeek: return '1週間';
      case DateRangeOption.oneMonth: return '1ヶ月';
      case DateRangeOption.threeMonths: return '3ヶ月';
      case DateRangeOption.oneYear: return '1年';
      case DateRangeOption.allTime: return 'すべて';
    }
  }

  void _showSizeFilterSheet() {
    double tempMinSize = _minSquidSize;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '最小サイズ: ${tempMinSize.round()} cm',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF13547a),
                      inactiveTrackColor: const Color(0xFF80d0c7).withOpacity(0.5),
                      thumbColor: const Color(0xFF13547a),
                      overlayColor: const Color(0xFF13547a).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: tempMinSize,
                      min: 0,
                      max: 70,
                      divisions: 14,
                      label: '${tempMinSize.round()} cm',
                      onChanged: (double value) => setModalState(() => tempMinSize = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton(
                        child: const Text('リセット'),
                        onPressed: () {
                          setState(() => _minSquidSize = 0);
                          Navigator.pop(context);
                          _updateFilterWithDebounce();
                        },
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13547a), foregroundColor: Colors.white),
                        child: const Text('適用する'),
                        onPressed: () {
                          setState(() => _minSquidSize = tempMinSize);
                          Navigator.pop(context);
                          _updateFilterWithDebounce();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMapTypeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('表示設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ToggleButtons(
                    isSelected: [_currentMapType == MapType.normal, _currentMapType == MapType.satellite],
                    onPressed: (int index) {
                      setModalState(() {
                        setState(() => _currentMapType = index == 0 ? MapType.normal : MapType.satellite);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: Colors.white,
                    fillColor: const Color(0xFF13547a),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Row(children: [Icon(Icons.map_outlined), SizedBox(width: 8), Text('通常')])),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Row(children: [Icon(Icons.satellite_alt_outlined), SizedBox(width: 8), Text('衛星')])),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: const Text('ダークモード'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: _isDarkMap,
                    onChanged: (newValue) => _toggleMapStyle().then((_) => setModalState(() {})),
                    activeColor: const Color(0xFF13547a),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
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
      trailing: _currentMapType == type ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        setState(() => _currentMapType = type);
        Navigator.of(context).pop();
      },
    );
  }
}