import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'common_app_bar.dart';
import 'add_post_form.dart';
import 'post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_detail_sheet.dart';

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
  Marker? _tappedMarker;

  // ボトムシートが表示されているかを管理する変数
  bool _isSheetVisible = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _showPostDetailSheet(Post post) {
    setState(() {
      _isSheetVisible = true;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PostDetailSheet(post: post);
      },
    ).whenComplete(() {
      setState(() {
        _isSheetVisible = false;
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    // ... (この中身は変更なし)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      print('位置情報の取得中にエラーが発生しました: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _tappedMarker = Marker(
        markerId: const MarkerId('tapped_location'),
        position: location,
        infoWindow: InfoWindow(title: '釣果を投稿する ＋', onTap: _showAddPostDialog),
      );
    });
  }

  void _showAddPostDialog() {
    if (_tappedMarker == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地図をタップして場所を選択してください。')));
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: AddPostForm(location: _tappedMarker!.position),
          contentPadding: const EdgeInsets.all(16.0),
          backgroundColor: Colors.white,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'マップ'),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPostDialog,
        child: const Icon(Icons.add),
      ),
      // ▼▼▼ bodyをStackウィジェットに変更 ▼▼▼
      body: Stack(
        children: [
          // 1. 背景のマップ
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('posts').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('エラー: ${snapshot.error}'));
              }

              Set<Marker> firestoreMarkers = {};
              if (snapshot.hasData) {
                firestoreMarkers = snapshot.data!.docs.map((doc) {
                  final post = Post.fromFirestore(doc);
                  return Marker(
                    markerId: MarkerId(post.id),
                    position: post.location,
                    onTap: () => _showPostDetailSheet(post),
                  );
                }).toSet();
              }

              final Set<Marker> allMarkers = {...firestoreMarkers};
              if (_tappedMarker != null) {
                allMarkers.add(_tappedMarker!);
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
                markers: allMarkers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              );
            },
          ),

          // ▼▼▼ 2. マップの上に重ねる透明なバリア ▼▼▼
          Visibility(
            // _isSheetVisibleがtrueの時だけ表示する
            visible: _isSheetVisible,
            // AbsorbPointerでイベントを吸収する
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent, // 透明だが、イベントは吸収する
              ),
            ),
          ),
        ],
      ),
    );
  }
}
