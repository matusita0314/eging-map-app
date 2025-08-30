import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/tournament_model.dart';
import 'add_tournament_post_page.dart'; // IngredientControllerを再利用

class EditTournamentPostPage extends StatefulWidget {
  final Tournament tournament;
  final DocumentSnapshot post;

  const EditTournamentPostPage(
      {super.key, required this.tournament, required this.post});

  @override
  State<EditTournamentPostPage> createState() => _EditTournamentPostPageState();
}

class _EditTournamentPostPageState extends State<EditTournamentPostPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isUploading = false;
  final _formKey = GlobalKey<FormState>();

  // 画像管理用の状態変数
  late List<String> _existingImageUrls;
  final List<Uint8List> _newImageBytes = [];
  final List<String> _deletedImageUrls = [];

  // フォームコントローラー
  final List<IngredientController> _ingredientControllers = [];
  final _egiNameController = TextEditingController();
  final _countController = TextEditingController();
  final _processController = TextEditingController();
  final _impressionController = TextEditingController();
  final _tackleRodController = TextEditingController();
  final _tackleReelController = TextEditingController();
  final _tackleLureController = TextEditingController();
  final _tackleLineController = TextEditingController();
  final _appealPointController = TextEditingController();
  final _weightController = TextEditingController();
  final _tackleRodControllerExisting = TextEditingController();
  final _tackleReelControllerExisting = TextEditingController();
  final _tackleLineControllerExisting = TextEditingController();
  final _egiMakerController = TextEditingController();
  final _commentController = TextEditingController();
  double _airTemperature = 15.0;
  double _waterTemperature = 15.0;
  String? _selectedSquidType;
  String? _selectedWeather;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  // 既存の投稿データをフォームにロードする
  void _loadPostData() {
    final postData = widget.post.data() as Map<String, dynamic>;

    _existingImageUrls = List<String>.from(postData['imageUrls'] ?? []);

    // 大会の種類に応じてコントローラーを初期化
    final metric = widget.tournament.rule.metric;
    if (metric == 'SIZE' || metric == 'COUNT') {
      _selectedSquidType = postData['squidType'];
      _egiNameController.text = postData['egiName'] ?? '';
      _selectedWeather = postData['weather'];
      _countController.text = (postData['judgedCount'] ?? '').toString();
      _weightController.text = (postData['weight'] ?? '').toString();
      _tackleRodControllerExisting.text = postData['tackleRod'] ?? '';
      _tackleReelControllerExisting.text = postData['tackleReel'] ?? '';
      _tackleLineControllerExisting.text = postData['tackleLine'] ?? '';
      _egiMakerController.text = postData['egiMaker'] ?? '';
      _commentController.text = postData['comment'] ?? '';
      _airTemperature = (postData['airTemperature'] as num? ?? 15.0).toDouble();
      _waterTemperature =
          (postData['waterTemperature'] as num? ?? 15.0).toDouble();
    } else if (metric == 'LIKE_COUNT') {
      if (widget.tournament.name.contains("料理")) {
        final ingredients = (postData['ingredients'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        if (ingredients.isNotEmpty) {
          for (var item in ingredients) {
            final controller = IngredientController();
            controller.nameController.text = item['name'] ?? '';
            controller.quantityController.text = item['quantity'] ?? '';
            _ingredientControllers.add(controller);
          }
        } else {
          _ingredientControllers.add(IngredientController());
        }
        _processController.text = postData['process'] ?? '';
        _impressionController.text = postData['impression'] ?? '';
      } else if (widget.tournament.name.contains("タックル")) {
        _tackleRodController.text = postData['tackleRod'] ?? '';
        _tackleReelController.text = postData['tackleReel'] ?? '';
        _tackleLureController.text = postData['lure'] ?? '';
        _tackleLineController.text = postData['tackleLine'] ?? '';
        _appealPointController.text = postData['appealPoint'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    // 全てのコントローラーを破棄
    _egiNameController.dispose();
    _countController.dispose();
    _processController.dispose();
    _impressionController.dispose();
    _tackleRodController.dispose();
    _tackleReelController.dispose();
    _tackleLureController.dispose();
    _tackleLineController.dispose();
    _appealPointController.dispose();
    for (var c in _ingredientControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final maxImages = widget.tournament.rule.maxImageCount;
    if (_existingImageUrls.length + _newImageBytes.length >= maxImages) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('画像は$maxImages枚までです。')));
      return;
    }

    final bool useCamera = widget.tournament.rule.metric == 'SIZE' ||
        widget.tournament.rule.metric == 'COUNT';
    final picker = ImagePicker();

    if (useCamera) {
      // カメラを起動
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _newImageBytes.add(bytes));
      }
    } else {
      // ギャラリーを起動
      final pickedFiles = await picker.pickMultipleMedia();
      if (pickedFiles.isNotEmpty) {
        for (final file in pickedFiles) {
          if (_existingImageUrls.length + _newImageBytes.length < maxImages) {
            _newImageBytes.add(await file.readAsBytes());
          }
        }
        setState(() {});
      }
    }
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      final List<String> finalImageUrls = List.from(_existingImageUrls);

      // 1. 削除指定された画像をStorageから削除
      for (final url in _deletedImageUrls) {
        if (url.isNotEmpty)
          await FirebaseStorage.instance.refFromURL(url).delete();
      }

      // 2. 新しい画像をStorageにアップロードしてURLを取得
      for (final bytes in _newImageBytes) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref(
            'tournaments/${widget.tournament.id}/${_currentUser.uid}/$fileName');
        await ref.putData(bytes);
        final downloadUrl = await ref.getDownloadURL();
        finalImageUrls.add(downloadUrl);
      }

      // 3. Firestoreに保存する更新データを準備
      final Map<String, dynamic> updateData = {
        'imageUrls': finalImageUrls,
        'updatedAt': FieldValue.serverTimestamp(), // 更新日時を追加
      };

      // 4. 大会の種類に応じて更新データを追加
      final metric = widget.tournament.rule.metric;
      if (metric == 'SIZE' || metric == 'COUNT') {
        updateData.addAll({
          'squidType': _selectedSquidType,
          'egiName': _egiNameController.text,
          'weather': _selectedWeather,
          'judgedCount': int.tryParse(_countController.text),
          'weight': _weightController.text.isEmpty
              ? null
              : double.tryParse(_weightController.text),
          'tackleRod': _tackleRodControllerExisting.text,
          'tackleReel': _tackleReelControllerExisting.text,
          'tackleLine': _tackleLineControllerExisting.text,
          'egiMaker': _egiMakerController.text,
          'comment': _commentController.text,
          'airTemperature': _airTemperature,
          'waterTemperature': _waterTemperature,
        });
      } else if (metric == 'LIKE_COUNT') {
        if (widget.tournament.name.contains("料理")) {
          updateData['ingredients'] = _ingredientControllers
              .where((c) => c.nameController.text.isNotEmpty)
              .map((c) => {
                    'name': c.nameController.text,
                    'quantity': c.quantityController.text
                  })
              .toList();
          updateData['process'] = _processController.text;
          updateData['impression'] = _impressionController.text;
        } else if (widget.tournament.name.contains("タックル")) {
          updateData.addAll({
            'tackleRod': _tackleRodController.text,
            'tackleReel': _tackleReelController.text,
            'lure': _tackleLureController.text,
            'tackleLine': _tackleLineController.text,
            'appealPoint': _appealPointController.text,
          });
        }
      }

      // 5. Firestoreのドキュメントを更新
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('posts')
          .doc(widget.post.id)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿を更新しました。')));
        Navigator.of(context).pop(); // 編集ページを閉じる
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF13547a), Color(0xFF80d0c7)],
              ),
            ),
          ),
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
                            Expanded(
                              child: Text(
                                '投稿の編集',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF13547a),
                                ),
                                overflow: TextOverflow.ellipsis,
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
                          _buildSectionTitle(
                              '画像 (${widget.tournament.rule.maxImageCount}枚まで)'),
                          const SizedBox(height: 8),
                          _buildImagePicker(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: _buildDynamicForm(),
                    ),
                    const SizedBox(height: 100), // フローティングボタンのための余白
                  ],
                ),
              ),
            ),
          ),
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

  Widget _buildDynamicForm() {
    final metric = widget.tournament.rule.metric;
    if (metric == 'SIZE' || metric == 'COUNT') {
      return _buildMainTournamentForm();
    } else if (metric == 'LIKE_COUNT') {
      if (widget.tournament.name.contains("料理")) {
        return _buildCookingContestForm();
      } else if (widget.tournament.name.contains("タックル")) {
        return _buildTackleContestForm();
      }
    }
    return const Text('この大会用のフォームが定義されていません。');
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

  // 以下、フォーム構築用のヘルパーメソッド
  Widget _buildImagePicker() {
    final maxImages = widget.tournament.rule.maxImageCount;
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _existingImageUrls.length + _newImageBytes.length + 1,
        itemBuilder: (context, index) {
          final totalImages =
              _existingImageUrls.length + _newImageBytes.length;
          // 追加ボタン
          if (index == totalImages) {
            return totalImages < maxImages
                ? _buildAddImageButton()
                : const SizedBox.shrink();
          }
          // 既存・新規画像の表示
          Widget imageWidget;
          bool isExistingImage = index < _existingImageUrls.length;
          if (isExistingImage) {
            imageWidget = CachedNetworkImage(
                imageUrl: _existingImageUrls[index],
                fit: BoxFit.cover,
                width: 100,
                height: 100);
          } else {
            imageWidget = Image.memory(
                _newImageBytes[index - _existingImageUrls.length],
                fit: BoxFit.cover,
                width: 100,
                height: 100);
          }
          return _buildImageTile(imageWidget, isExistingImage, index, () {
            setState(() {
              if (isExistingImage) {
                final removedUrl = _existingImageUrls.removeAt(index);
                _deletedImageUrls.add(removedUrl);
              } else {
                _newImageBytes.removeAt(index - _existingImageUrls.length);
              }
            });
          });
        },
      ),
    );
  }

  Widget _buildAddImageButton() {
    final bool useCamera = widget.tournament.rule.metric == 'SIZE' ||
        widget.tournament.rule.metric == 'COUNT';
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              useCamera ? Icons.camera_alt : Icons.photo_library,
              color: Colors.grey,
            ),
            Text(
              useCamera ? '撮影する' : '選択する',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile(
      Widget image, bool isExisting, int index, VoidCallback onDeleted) {
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
                  child: InteractiveViewer(
                    child: isExisting
                        ? CachedNetworkImage(
                            imageUrl: _existingImageUrls[index],
                            fit: BoxFit.contain)
                        : Image.memory(
                            _newImageBytes[index - _existingImageUrls.length],
                            fit: BoxFit.contain),
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child:
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
            ),
          ),
          Positioned(
            top: -14,
            right: -6,
            child: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.black54, size: 22),
              onPressed: onDeleted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTournamentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('必須項目'),
        DropdownButtonFormField<String>(
          value: _selectedSquidType,
          decoration: const InputDecoration(
              labelText: 'イカの種類 *', border: OutlineInputBorder()),
          items: ['アオリイカ', 'コウイカ', 'ヤリイカ', 'スルメイカ', 'ヒイカ', 'モンゴウイカ']
              .map((String value) =>
                  DropdownMenuItem<String>(value: value, child: Text(value)))
              .toList(),
          onChanged: (String? newValue) =>
              setState(() => _selectedSquidType = newValue),
          validator: (value) => value == null ? '必須項目です' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _egiNameController,
          decoration: const InputDecoration(
              labelText: 'エギ・ルアー名 *', border: OutlineInputBorder()),
          validator: (value) => value!.isEmpty ? '必須項目です' : null,
        ),
        if (widget.tournament.rule.metric == 'COUNT') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _countController,
            decoration:
                const InputDecoration(labelText: '匹数 *', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (value) =>
                (value == null || value.isEmpty) ? '必須項目です' : null,
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedWeather,
          decoration:
              const InputDecoration(labelText: '天気 *', border: OutlineInputBorder()),
          items: ['晴れ', '快晴', '曇り', '雨']
              .map((String value) =>
                  DropdownMenuItem<String>(value: value, child: Text(value)))
              .toList(),
          onChanged: (String? newValue) =>
              setState(() => _selectedWeather = newValue),
          validator: (value) => value == null ? '必須項目です' : null,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('任意項目'),
        TextFormField(
          controller: _weightController,
          decoration:
              const InputDecoration(labelText: '重さ (g)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildTemperatureSlider(
            '気温', _airTemperature, -10, 40, (v) => setState(() => _airTemperature = v)),
        const SizedBox(height: 16),
        _buildTemperatureSlider('水温', _waterTemperature, 0, 35,
            (v) => setState(() => _waterTemperature = v)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _egiMakerController,
          decoration: const InputDecoration(
              labelText: 'エギ・ルアーメーカー', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tackleRodControllerExisting,
          decoration:
              const InputDecoration(labelText: 'ロッド', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tackleReelControllerExisting,
          decoration:
              const InputDecoration(labelText: 'リール', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tackleLineControllerExisting,
          decoration:
              const InputDecoration(labelText: 'ライン', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _commentController,
          decoration:
              const InputDecoration(labelText: 'ひとこと', border: OutlineInputBorder()),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildCookingContestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('材料 *'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ingredientControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(children: [
                Expanded(
                    flex: 2,
                    child: TextFormField(
                        controller: _ingredientControllers[index].nameController,
                        decoration: const InputDecoration(
                            labelText: '材料名', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: TextFormField(
                        controller:
                            _ingredientControllers[index].quantityController,
                        decoration: const InputDecoration(
                            labelText: '分量', border: OutlineInputBorder()))),
                if (_ingredientControllers.length > 1)
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() {
                            _ingredientControllers[index].dispose();
                            _ingredientControllers.removeAt(index);
                          }))
                else
                  const SizedBox(width: 48),
              ]),
            );
          },
        ),
        TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('材料を追加'),
            onPressed: () =>
                setState(() => _ingredientControllers.add(IngredientController()))),
        const SizedBox(height: 16),
        _buildSectionTitle('作り方など'),
        TextFormField(
            controller: _processController,
            decoration: const InputDecoration(
                labelText: '調理工程 (任意)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true),
            maxLines: 10),
        const SizedBox(height: 16),
        TextFormField(
            controller: _impressionController,
            decoration: const InputDecoration(
                labelText: '感想 (任意)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true),
            maxLines: 3),
      ],
    );
  }

  Widget _buildTackleContestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('タックル情報'),
        TextFormField(
            controller: _tackleRodController,
            decoration: const InputDecoration(
                labelText: 'ロッド *', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? '必須項目です' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _tackleReelController,
            decoration: const InputDecoration(
                labelText: 'リール *', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? '必須項目です' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _tackleLureController,
            decoration: const InputDecoration(
                labelText: 'ルアー *', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? '必須項目です' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _tackleLineController,
            decoration: const InputDecoration(
                labelText: 'ライン *', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? '必須項目です' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _appealPointController,
            decoration: const InputDecoration(
                labelText: 'アピールポイント *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true),
            maxLines: 5,
            validator: (v) => (v == null || v.isEmpty) ? '必須項目です' : null),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey)),
    );
  }

  Widget _buildTemperatureSlider(String label, double value, double min,
      double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text('$label: ${value.toStringAsFixed(1)} ℃',
              style: TextStyle(color: Colors.grey.shade700)),
        ),
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

// 編集ページでもAppBarを固定表示するためのDelegate
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