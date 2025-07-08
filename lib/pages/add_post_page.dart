// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';

class AddPostPage extends StatefulWidget {
  final LatLng location;

  const AddPostPage({super.key, required this.location});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _formKey = GlobalKey<FormState>();
  // File? _image;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  String? _selectedWeather;
  double _airTemperature = 15.0;
  double _waterTemperature = 15.0;

  // 各フォームフィールドのコントローラー
  // final _weatherController = TextEditingController();
  final _egiNameController = TextEditingController();
  final _squidSizeController = TextEditingController();
  final _weightController = TextEditingController();
  final _tackleRodController = TextEditingController();
  final _tackleReelController = TextEditingController();
  final _tackleLineController = TextEditingController();
  final _egiMakerController = TextEditingController();
  final _captionController = TextEditingController();

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submitPost() async {
    // フォームのバリデーションを実行
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedWeather == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('天気を選択してください。')));
      return;
    }
    // 画像が選択されているかチェック
    if (_imageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写真を選択してください。')));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // 1. 画像をFirebase Storageにアップロード
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'posts/${user.uid}/$fileName',
      );
      await ref.putData(_imageBytes!);
      final imageUrl = await ref.getDownloadURL();

      // 2. Firestoreに投稿データを保存
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userName': user.displayName ?? '名無しさん',
        'userPhotoUrl': user.photoURL ?? '',
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
        'location': GeoPoint(
          widget.location.latitude,
          widget.location.longitude,
        ),

        // 新しいフィールドのデータ
        'weather': _selectedWeather,
        'squidSize': double.tryParse(_squidSizeController.text) ?? 0.0,
        'weight': double.tryParse(_weightController.text),
        'egiName': _egiNameController.text,
        'egiMaker': _egiMakerController.text,
        'tackleRod': _tackleRodController.text,
        'tackleReel': _tackleReelController.text,
        'tackleLine': _tackleLineController.text,
        'airTemperature': _airTemperature,
        'waterTemperature': _waterTemperature,
        'caption': _captionController.text,
        'likeCount': 0,
        'commentCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿が完了しました！')));
        // 投稿完了後、マップページに戻る
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('投稿エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // _weatherController.dispose();
    _egiNameController.dispose();
    _squidSizeController.dispose();
    _weightController.dispose();
    _tackleRodController.dispose();
    _tackleReelController.dispose();
    _tackleLineController.dispose();
    _egiMakerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('釣果を投稿')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 画像プレビュー＆選択ボタン
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade200,
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '写真をタップして選択',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              // 各種フォームフィールド
              _buildSectionTitle('基本情報'),
              TextFormField(
                controller: _egiNameController,
                decoration: const InputDecoration(
                  labelText: 'エギ・ルアー名',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) => value!.isEmpty ? '必須項目です' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _squidSizeController,
                decoration: const InputDecoration(
                  labelText: 'サイズ (cm)',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? '必須項目です' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedWeather,
                decoration: const InputDecoration(
                  labelText: '天気',
                  prefixIcon: Icon(Icons.wb_sunny_outlined),
                  border: OutlineInputBorder(),
                ),
                hint: const Text('天気を選択'),
                items: ['晴れ', '快晴', '曇り', '雨']
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (String? newValue) =>
                    setState(() => _selectedWeather = newValue),
                validator: (value) => value == null ? '必須項目です' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('詳細情報（任意）'),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: '重さ (g)',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                      '気温: ${_airTemperature.toStringAsFixed(1)} ℃',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Slider(
                    value: _airTemperature,
                    min: -10,
                    max: 40,
                    divisions: 100,
                    label: _airTemperature.toStringAsFixed(1),
                    onChanged: (double value) =>
                        setState(() => _airTemperature = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                      '水温: ${_waterTemperature.toStringAsFixed(1)} ℃',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Slider(
                    value: _waterTemperature,
                    min: 0,
                    max: 35,
                    divisions: 70,
                    label: _waterTemperature.toStringAsFixed(1),
                    onChanged: (double value) =>
                        setState(() => _waterTemperature = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _egiMakerController,
                decoration: const InputDecoration(
                  labelText: 'エギ・ルアーメーカー',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tackleRodController,
                decoration: const InputDecoration(
                  labelText: 'ロッド',
                  prefixIcon: Icon(Icons.sports_esports_outlined), // 仮
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tackleReelController,
                decoration: const InputDecoration(
                  labelText: 'リール',
                  prefixIcon: Icon(Icons.catching_pokemon_outlined), // 仮
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tackleLineController,
                decoration: const InputDecoration(
                  labelText: 'ライン',
                  prefixIcon: Icon(Icons.timeline_outlined), // 仮
                ),
              ),
              const SizedBox(height: 16),
              TextFormField( // ▼ 追記
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: '一言コメント（任意）',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
                maxLength: 100, // 100文字制限
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50), // 高さを50に設定
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // 角を少し丸くする
            ),
            backgroundColor: Colors.blue, // ボタンの色
            foregroundColor: Colors.white, // テキストの色
          ),
          // アップロード中はボタンを無効化し、ローディング表示
          onPressed: _isUploading ? null : _submitPost,
          child: _isUploading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  '投稿する',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  // セクションのタイトル用ウィジェット
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }
}
