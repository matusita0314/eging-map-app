import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tournament_model.dart';

class TournamentSubmissionPage extends StatefulWidget {
  final Tournament tournament;
  const TournamentSubmissionPage({super.key, required this.tournament});

  @override
  State<TournamentSubmissionPage> createState() => _TournamentSubmissionPageState();
}

class _TournamentSubmissionPageState extends State<TournamentSubmissionPage> {  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isUploading = false;
  final _formKey = GlobalKey<FormState>();

  final List<Uint8List> _imageBytesList = [];
  String? _selectedWeather;
  String? _selectedSquidType;
  double _airTemperature = 15.0;
  double _waterTemperature = 15.0;

  final _egiNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _tackleRodController = TextEditingController();
  final _tackleReelController = TextEditingController();
  final _tackleLineController = TextEditingController();
  final _egiMakerController = TextEditingController();
  final _commentController = TextEditingController();
  final _countController = TextEditingController();


  @override
  void dispose() {
    _egiNameController.dispose();
    _weightController.dispose();
    _tackleRodController.dispose();
    _tackleReelController.dispose();
    _tackleLineController.dispose();
    _egiMakerController.dispose();
    _commentController.dispose();
    _countController.dispose();
    super.dispose();
  }

  // カメラでの画像選択を強制
  Future<void> _takePicture() async {
    final maxImages = widget.tournament.rule.maxImageCount;

    if (_imageBytesList.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像は${maxImages}枚までです。')),
      );
      return;
    }
    
    // ImagePickerをカメラモードで起動
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      // 撮影した画像をリストに追加して、画面を更新
      setState(() {
        _imageBytesList.add(bytes);
      });
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytesList.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('写真を1枚以上撮影してください。')));
    return;
  }
    setState(() => _isUploading = true);

    try {
      final List<String> downloadUrls = [];
      // 1. まず全ての画像をStorageにアップロードする
      for (final bytes in _imageBytesList) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${downloadUrls.length}.jpg';
        final ref = FirebaseStorage.instance.ref().child(
          'tournaments/${widget.tournament.id}/${_currentUser.uid}/$fileName',
        );
        await ref.putData(bytes);
        final url = await ref.getDownloadURL();
        downloadUrls.add(url);
      }


      // 2. Firestoreに保存するデータを拡張
      final submissionData = {
        'userId': _currentUser.uid,
        'userName': _currentUser.displayName ?? '名無しさん',
        'userPhotoUrl': _currentUser.photoURL ?? '',
        'createdAt': Timestamp.now(),
        'status': 'pending',
        'judgedSize': null,
        'judgedCount': int.tryParse(_countController.text) ?? 0,
        'imageUrls': downloadUrls,
        'squidType': _selectedSquidType,
        'egiName': _egiNameController.text,
        'weather': _selectedWeather,
        'weight': _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
        'airTemperature': _airTemperature,
        'waterTemperature': _waterTemperature,
        'egiMaker': _egiMakerController.text,
        'tackleRod': _tackleRodController.text,
        'tackleReel': _tackleReelController.text,
        'tackleLine': _tackleLineController.text,
        'comment': _commentController.text,
        'likeCount': 0,
        'commentCount': 0,
      };

      // 3. Firestoreに書き込む
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('posts')
          .add(submissionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('釣果を提出しました！運営の判定をお待ちください。')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('提出エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxImages = widget.tournament.rule.maxImageCount;
    final imageSectionTitle = '必須：釣果の写真 ($maxImages枚まで)';

    return Scaffold(
      appBar: AppBar(title: Text('${widget.tournament.name} へ提出')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(imageSectionTitle),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageBytesList.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _imageBytesList.length) {
                      return _imageBytesList.length < maxImages
                          ? GestureDetector(
                              onTap: _takePicture,
                              child: Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: Colors.grey),
                                    Text('撮影する', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink();
                    }
                    return SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(10),
                                  child: InteractiveViewer( // ピンチ操作でズームできるようにする
                                    child: Image.memory(
                                      _imageBytesList[index],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(_imageBytesList[index], fit: BoxFit.cover, width: 100, height: 100),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -14,
                            right: -6,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.black54, size: 22),
                              onPressed: () => setState(() => _imageBytesList.removeAt(index)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('必須項目'),
              DropdownButtonFormField<String>(
                value: _selectedSquidType,
                decoration: const InputDecoration(labelText: 'イカの種類 *', border: OutlineInputBorder()),
                items: ['アオリイカ', 'コウイカ', 'ヤリイカ', 'スルメイカ', 'ヒイカ', 'モンゴウイカ']
                    .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (String? newValue) => setState(() => _selectedSquidType = newValue),
                validator: (value) => value == null ? '必須項目です' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _egiNameController,
                decoration: const InputDecoration(labelText: 'エギ・ルアー名 *', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? '必須項目です' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedWeather,
                decoration: const InputDecoration(labelText: '天気 *', border: OutlineInputBorder()),
                items: ['晴れ', '快晴', '曇り', '雨']
                    .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (String? newValue) => setState(() => _selectedWeather = newValue),
                validator: (value) => value == null ? '必須項目です' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('任意項目'),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: '重さ (g)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTemperatureSlider('気温', _airTemperature, -10, 40, (v) => setState(() => _airTemperature = v)),
              const SizedBox(height: 16),
              _buildTemperatureSlider('水温', _waterTemperature, 0, 35, (v) => setState(() => _waterTemperature = v)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _egiMakerController,
                decoration: const InputDecoration(labelText: 'エギ・ルアーメーカー', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tackleRodController,
                decoration: const InputDecoration(labelText: 'ロッド', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tackleReelController,
                decoration: const InputDecoration(labelText: 'リール', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tackleLineController,
                decoration: const InputDecoration(labelText: 'ライン', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(labelText: 'ひとこと', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _isUploading ? null : _submitPost,
          child: _isUploading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('提出する'),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildTemperatureSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)} ℃'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 2).toInt(),
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }
}