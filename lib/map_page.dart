import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'common_app_bar.dart';
import 'dart:ui';
import 'add_post_form.dart';

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

  // タップされた場所のマーカーを管理する変数
  Marker? _tappedMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // ... （この中身は変更なし）
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

  // マップがタップされたときに呼ばれるメソッド
  void _onMapTapped(LatLng location) {
    setState(() {
      _tappedMarker = Marker(
        markerId: const MarkerId('tapped_location'),
        position: location,
        // InfoWindowにonTapプロパティを追加
        infoWindow: InfoWindow(
          title: 'ここに釣果情報を投稿 +',
          onTap: _showAddPostDialog, // 作成したメソッドを呼び出す
        ),
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
        // map_page.dartのshowDialogの中
      return AlertDialog(
        // タップされたマーカーの位置情報をlocationプロパティに渡す
        content: AddPostForm(location: _tappedMarker!.position),
        contentPadding: EdgeInsets.all(16.0),
        backgroundColor: Colors.white,
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'マップ'),
      // フローティングアクションボタン（右下の＋ボタン）を追加
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _showAddPostDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? _initialPosition,
                zoom: 14.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
              },
              // タップされたときの処理を登録
              onTap: _onMapTapped,
              // 表示するマーカーのセット
              markers: _tappedMarker == null ? {} : {_tappedMarker!},
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}
