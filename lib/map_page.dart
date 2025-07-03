import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'common_app_bar.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // マップを操作するためのコントローラー
  final Completer<GoogleMapController> _controller = Completer();
  // 現在地を保持するための変数（初期値は東京駅）
  static const LatLng _initialPosition = LatLng(35.681236, 139.767125);
  // 現在地を更新するための変数
  LatLng? _currentPosition;
  // ローディング状態を管理
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 画面が作成された時に、現在地を取得する処理を呼び出す
    _getCurrentLocation();
  }

  // 現在地を取得するメソッド
  Future<void> _getCurrentLocation() async {
    try {
      // 1. 位置情報サービスが有効かチェック
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // エラー処理
        setState(() => _isLoading = false);
        return;
      }

      // 2. 位置情報へのアクセス許可をチェック
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 許可をリクエスト
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // エラー処理
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 永久に拒否されている場合のエラー処理
        setState(() => _isLoading = false);
        return;
      }

      // 3. 現在地を取得
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. 取得した位置情報をStateにセットし、画面を再描画
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 共通のAppBarを呼び出し
      appBar: CommonAppBar(title: 'マップ'),
      // ローディング中か、データ取得後かで表示を切り替え
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              // マップの初期表示位置（現在地が取れなかった場合は東京駅）
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? _initialPosition,
                zoom: 14.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
              },
              myLocationEnabled: true, // 現在地レイヤー（青い点）を有効にする
              myLocationButtonEnabled: true, // 現在地ボタンを有効にする
            ),
    );
  }
}
