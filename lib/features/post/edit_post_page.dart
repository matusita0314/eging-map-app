import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post_model.dart';

class EditPostPage extends StatefulWidget {
  final Post post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;

  late List<String> _existingImageUrls;
  final List<Uint8List> _newImageBytes = [];
  final List<String> _deletedImageUrls = [];

  String? _selectedWeather;
  double _airTemperature = 15.0;
  double _waterTemperature = 15.0;
  late final TextEditingController _egiNameController;
  late final TextEditingController _squidSizeController;
  late final TextEditingController _weightController;
  late final TextEditingController _tackleRodController;
  late final TextEditingController _tackleReelController;
  late final TextEditingController _tackleLineController;
  late final TextEditingController _egiMakerController;
  late final TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _existingImageUrls = List<String>.from(widget.post.imageUrls);

    _egiNameController = TextEditingController(text: widget.post.egiName);
    _squidSizeController = TextEditingController(
      text: widget.post.squidSize.toString(),
    );
    _captionController = TextEditingController(text: widget.post.caption);
    _weightController = TextEditingController(
      text: widget.post.weight?.toString() ?? '',
    );
    _egiMakerController = TextEditingController(text: widget.post.egiMaker);
    _tackleRodController = TextEditingController(text: widget.post.tackleRod);
    _tackleReelController = TextEditingController(text: widget.post.tackleReel);
    _tackleLineController = TextEditingController(text: widget.post.tackleLine);
    final weatherOptions = ['晴れ', '快晴', '曇り', '雨'];
    if (weatherOptions.contains(widget.post.weather)) {
      _selectedWeather = widget.post.weather;
    } else {
      _selectedWeather = null;
    }
    _airTemperature = widget.post.airTemperature ?? 15.0;
    _waterTemperature = widget.post.waterTemperature ?? 15.0;
  }

  @override
  void dispose() {
    _egiNameController.dispose();
    _squidSizeController.dispose();
    _captionController.dispose();
    _weightController.dispose();
    _egiMakerController.dispose();
    _tackleRodController.dispose();
    _tackleReelController.dispose();
    _tackleLineController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final totalImages = _existingImageUrls.length + _newImageBytes.length;
    if (totalImages >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画像は3枚までです。')));
      return;
    }

    final pickedFiles = await ImagePicker().pickMultipleMedia();
    if (pickedFiles.isNotEmpty) {
      for (final file in pickedFiles) {
        if (_existingImageUrls.length + _newImageBytes.length < 3) {
          _newImageBytes.add(await file.readAsBytes());
        }
      }
      setState(() {});
    }
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Firestoreに保存する最終的なURLリスト
      final List<String> finalImageUrls = List.from(_existingImageUrls);

      // 1. 削除対象の画像をStorageから削除
      for (final url in _deletedImageUrls) {
        // サムネイルも削除 (Cloud Functionsで生成している場合、それに対応するパスを削除)
        // 例: final thumbRef = FirebaseStorage.instance.refFromURL(url.replaceFirst('/posts/', '/posts/thumbnails/thumb_'));
        // await thumbRef.delete();
        await FirebaseStorage.instance.refFromURL(url).delete();
      }

      // 2. 新しい画像をStorageにアップロードし、URLを取得してリストに追加
      for (final bytes in _newImageBytes) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref('posts/${user.uid}/$fileName');
        await ref.putData(bytes);
        final downloadUrl = await ref.getDownloadURL();
        finalImageUrls.add(downloadUrl);
      }

      // 3. Firestoreのドキュメントを更新
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({
        'imageUrls': finalImageUrls,
        // TODO: 新しい画像に対応するサムネイルを生成・更新するCloud Functionsのロジックが必要
        'squidSize': double.tryParse(_squidSizeController.text) ?? 0.0,
        'caption': _captionController.text,
        'weather': _selectedWeather,
        'weight': _weightController.text.isEmpty
            ? null
            : double.tryParse(_weightController.text),
        'egiName': _egiNameController.text,
        'egiMaker': _egiMakerController.text,
        'tackleRod': _tackleRodController.text,
        'tackleReel': _tackleReelController.text,
        'tackleLine': _tackleLineController.text,
        'airTemperature': _airTemperature,
        'waterTemperature': _waterTemperature,
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿を更新しました。')));
        // 編集ページを閉じて詳細ページに戻る
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景グラデーション
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFF13547a),
                  Color(0xFF80d0c7),
                ],
              ),
            ),
          ),
          // メインコンテンツ
          SafeArea(
            bottom: false,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyAppBarDelegate(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
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
                              icon: const Icon(Icons.arrow_back,
                                  color: Color(0xFF13547a)),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Expanded(
                              child: Text(
                                '投稿を編集',
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
                ];
              },
              body: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('画像 (3枚まで)'),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _existingImageUrls.length +
                                  _newImageBytes.length +
                                  1,
                              itemBuilder: (context, index) {
                                final totalImages =
                                    _existingImageUrls.length +
                                        _newImageBytes.length;
                                if (index == totalImages) {
                                  return totalImages < 3
                                      ? GestureDetector(
                                          onTap: _pickImages,
                                          child: Container(
                                            width: 100,
                                            height: 100,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                                Icons.add_a_photo,
                                                color: Colors.grey),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                }

                                Widget imageWidget;
                                final isExistingImage =
                                    index < _existingImageUrls.length;
                                if (isExistingImage) {
                                  imageWidget = CachedNetworkImage(
                                      imageUrl: _existingImageUrls[index],
                                      fit: BoxFit.cover);
                                } else {
                                  imageWidget = Image.memory(
                                      _newImageBytes[
                                          index - _existingImageUrls.length],
                                      fit: BoxFit.cover);
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
                                              backgroundColor:
                                                  Colors.transparent,
                                              insetPadding:
                                                  const EdgeInsets.all(10),
                                              child: InteractiveViewer(
                                                child: isExistingImage
                                                    ? CachedNetworkImage(
                                                        imageUrl:
                                                            _existingImageUrls[
                                                                index],
                                                        fit: BoxFit.contain)
                                                    : Image.memory(
                                                        _newImageBytes[index -
                                                            _existingImageUrls
                                                                .length],
                                                        fit: BoxFit.contain),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: imageWidget),
                                        ),
                                      ),
                                      Positioned(
                                        top: -14,
                                        right: -12,
                                        child: IconButton(
                                          icon: const Icon(Icons.cancel,
                                              color: Colors.black54,
                                              size: 20),
                                          onPressed: () {
                                            setState(() {
                                              if (index <
                                                  _existingImageUrls.length) {
                                                final removedUrl =
                                                    _existingImageUrls
                                                        .removeAt(index);
                                                _deletedImageUrls
                                                    .add(removedUrl);
                                              } else {
                                                _newImageBytes.removeAt(index -
                                                    _existingImageUrls.length);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text('画像をタップして拡大、×ボタンで削除',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('基本情報'),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _egiNameController,
                            decoration: const InputDecoration(
                              labelText: 'エギ・ルアー名',
                              prefixIcon: Icon(Icons.label_outline),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? '必須項目です' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _squidSizeController,
                            decoration: const InputDecoration(
                              labelText: '胴長 (cm)',
                              prefixIcon: Icon(Icons.straighten_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                value!.isEmpty ? '必須項目です' : null,
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
                            validator: (value) =>
                                value == null ? '必須項目です' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           _buildSectionTitle('詳細情報（任意）'),
                          const SizedBox(height: 16),
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
                              prefixIcon: Icon(Icons.sports_esports_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _tackleReelController,
                            decoration: const InputDecoration(
                              labelText: 'リール',
                              prefixIcon:
                                  Icon(Icons.catching_pokemon_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _tackleLineController,
                            decoration: const InputDecoration(
                              labelText: 'ライン',
                              prefixIcon: Icon(Icons.timeline_outlined),
                            ),
                          ),
                             const SizedBox(height: 16),
                          TextFormField(
                            controller: _captionController,
                            decoration: const InputDecoration(
                              labelText: '一言コメント（任意）',
                              prefixIcon: Icon(Icons.comment_outlined),
                            ),
                            maxLength: 100,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100), // フローティングボタンのための余白
                  ],
                ),
              ),
            ),
          ),
          // フローティング更新ボタン
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildUpdateButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        top: false,
        child: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
              shape: const StadiumBorder(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 8,
            ),
            onPressed: _isUploading ? null : _updatePost,
            child: _isUploading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : const Text('更新する',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
    );
  }
}

class _StickyAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyAppBarDelegate({required this.child});

  @override
  double get minExtent => 70.0;

  @override
  double get maxExtent => 70.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}