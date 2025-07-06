import 'dart:typed_data'; // Uint8Listを使うために必要
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class AddPostForm extends StatefulWidget {
  // 緯度経度を受け取るための変数を定義
  final LatLng location;

  // コンストラクタで緯度経度を必須項目として受け取る
  const AddPostForm({super.key, required this.location});

  @override
  State<AddPostForm> createState() => _AddPostFormState();
}

class _AddPostFormState extends State<AddPostForm> {
  // 各TextFormFieldを管理するためのコントローラー
  final _squidSizeController = TextEditingController();
  final _egiTypeController = TextEditingController();

  // 選択された画像を保持するための変数
  Uint8List? _imageData;

  // ImagePickerのインスタンス
  final _picker = ImagePicker();
  // アップロード中の状態を管理
  bool _isUploading = false;

  // 画像を選択するためのメソッド
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        // 選択した画像のデータをセットして、画面を更新するだけ
        setState(() {
          _imageData = bytes;
        });
      }
    } catch (e) {
      print('画像選択中にエラーが発生しました: $e');
    }
  }

  // ★★★ ここからが新しい保存処理メソッド ★★★
  Future<void> _submitPost() async {
    // 入力チェック
    if (_imageData == null || _squidSizeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写真とイカのサイズは必須です。')));
      return;
    }

    // ログイン中のユーザー情報を取得
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿するにはログインが必要です。')));
      return;
    }

    setState(() {
      _isUploading = true; // アップロード開始（ボタンを無効化＆ローディング表示）
    });

    try {
      // 1. Firebase Storageに画像をアップロード
      final storageRef = FirebaseStorage.instance.ref();
      // ファイル名をユニークにするために現在時刻のミリ秒を使用
      final imageFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageRef = storageRef.child('posts/${user.uid}/$imageFileName');
      // Uint8Listデータをアップロード
      await imageRef.putData(_imageData!);
      // アップロードした画像のURLを取得
      final imageUrl = await imageRef.getDownloadURL();

      // 2. Firestoreに投稿データを保存
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userName': user.displayName ?? '名無しさん',
        'userPhotoUrl': user.photoURL ?? '',
        'squidSize': double.tryParse(_squidSizeController.text) ?? 0.0,
        'egiType': _egiTypeController.text,
        'imageUrl': imageUrl,
        'location': GeoPoint(
          widget.location.latitude,
          widget.location.longitude,
        ),
        'createdAt': Timestamp.now(),
        'likeCount': 0,
        'commentCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿が完了しました。')));
        Navigator.of(context).pop(); // 投稿後、ダイアログを閉じる
      }
    } catch (e) {
      print('投稿エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      // 成功・失敗に関わらず、アップロード状態を解除
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _squidSizeController.dispose();
    _egiTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '釣果の投稿',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _imageData != null
                  ? Image.memory(_imageData!, fit: BoxFit.cover)
                  : const Center(child: Text('写真が選択されていません')),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('写真をアップロード'),
              onPressed: _pickImage,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _squidSizeController,
              decoration: const InputDecoration(
                labelText: 'イカのサイズ (cm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _egiTypeController,
              decoration: const InputDecoration(
                labelText: 'ヒットエギ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            // ★★★ 投稿ボタンの部分を修正 ★★★
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              // アップロード中はボタンを押せないようにし、処理を_submitPostに変更
              onPressed: _isUploading ? null : _submitPost,
              // アップロード中はローディング表示、そうでなければテキスト表示
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('投稿する'),
            ),
          ],
        ),
      ),
    );
  }
}
