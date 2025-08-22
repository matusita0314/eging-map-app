import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tournament_model.dart';

class TournamentSubmissionPage extends StatefulWidget {
  final Tournament tournament;
  final DocumentSnapshot? post;

  const TournamentSubmissionPage({super.key, required this.tournament, this.post});

  @override
  State<TournamentSubmissionPage> createState() => _TournamentSubmissionPageState();
}

class _TournamentSubmissionPageState extends State<TournamentSubmissionPage> {  
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isUploading = false;
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.post != null;
  
  final List<Uint8List> _imageBytesList = [];
  String? _selectedWeather;
  String? _selectedSquidType;
  double _airTemperature = 15.0;
  double _waterTemperature = 15.0;

  final List<IngredientController> _ingredientControllers = [];
  final _egiNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _tackleRodController = TextEditingController();
  final _tackleReelController = TextEditingController();
  final _tackleLineController = TextEditingController();
  final _egiMakerController = TextEditingController();
  final _commentController = TextEditingController();
  final _countController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _processController = TextEditingController();
  final _impressionController = TextEditingController();
  final _tackleLureController = TextEditingController();
  final _appealPointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.tournament.name.contains("料理")) {
      _ingredientControllers.add(IngredientController());
    }
  }

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
    _ingredientsController.dispose();
    _processController.dispose();
    _impressionController.dispose();  
    _tackleLureController.dispose();
    _appealPointController.dispose();
    for (var c in _ingredientControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final maxImages = widget.tournament.rule.maxImageCount;
    final bool useCamera = widget.tournament.rule.metric == 'SIZE' || widget.tournament.rule.metric == 'COUNT';

    if (_imageBytesList.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像は${maxImages}枚までです。')),
      );
      return;
    }
    
    final picker = ImagePicker();
    if (useCamera) {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _imageBytesList.add(bytes));
      }
    } else {
      final pickedFiles = await picker.pickMultipleMedia();
      if (pickedFiles.isNotEmpty) {
        for (final file in pickedFiles) {
          if (_imageBytesList.length < maxImages) {
            _imageBytesList.add(await file.readAsBytes());
          }
        }
        setState(() {});
      }
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('写真を1枚以上撮影してください。')));
      return;
    } 
    if (widget.tournament.name.contains("料理") && _ingredientControllers.every((c) => c.nameController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('材料を1つ以上入力してください。')));
      return;
    }
    setState(() => _isUploading = true);

    try {
      final List<String> downloadUrls = [];
      for (final bytes in _imageBytesList) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${downloadUrls.length}.jpg';
        final ref = FirebaseStorage.instance.ref().child(
          'tournaments/${widget.tournament.id}/${_currentUser.uid}/$fileName',
        );
        await ref.putData(bytes);
        final url = await ref.getDownloadURL();
        downloadUrls.add(url);
      }

      final submissionData = <String, dynamic>{
        'userId': _currentUser.uid,
        'userName': _currentUser.displayName ?? '名無しさん',
        'userPhotoUrl': _currentUser.photoURL ?? '',
        'createdAt': Timestamp.now(),
        'status': widget.tournament.rule.judgingType == 'MANUAL' ? 'pending' : 'approved',
        'imageUrls': downloadUrls,
        'likeCount': 0,
        'commentCount': 0,
      };

      final metric = widget.tournament.rule.metric;
      if (metric == 'SIZE' || metric == 'COUNT') {
        submissionData.addAll({
          'squidType': _selectedSquidType,
          'egiName': _egiNameController.text,
          'weather': _selectedWeather,
          'judgedCount': int.tryParse(_countController.text), // nullの可能性もある
        });
      } else if (metric == 'LIKE_COUNT') {
        if (widget.tournament.name.contains("料理")) {
          final ingredientsList = _ingredientControllers
              .where((c) => c.nameController.text.isNotEmpty)
              .map((c) => {
                    'name': c.nameController.text,
                    'quantity': c.quantityController.text,
                  })
              .toList();
          submissionData.addAll({
            'ingredients': ingredientsList,
            'process': _processController.text,
            'impression': _impressionController.text,
          });
        } else if (widget.tournament.name.contains("タックル")) {
          submissionData.addAll({
            'tackleRod': _tackleRodController.text,
            'tackleReel': _tackleReelController.text,
            'lure': _tackleLureController.text,
            'tackleLine': _tackleLineController.text,
            'appealPoint': _appealPointController.text,
          });
        }
      }

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('posts')
          .add(submissionData);

      if (mounted) {
        final message = widget.tournament.rule.judgingType == 'MANUAL'
            ? '提出しました！運営の判定をお待ちください。'
            : '投稿が完了しました！';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- 以下、既存のフォーム生成ロジック（変更なし） ---
  Widget _buildMainTournamentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ingredientControllers[index].nameController,
                      decoration: const InputDecoration(labelText: '材料名', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ingredientControllers[index].quantityController,
                      decoration: const InputDecoration(labelText: '分量', border: OutlineInputBorder()),
                    ),
                  ),
                  if (_ingredientControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          _ingredientControllers[index].dispose();
                          _ingredientControllers.removeAt(index);
                        });
                      },
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            );
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('材料を追加'),
          onPressed: () {
            setState(() {
              _ingredientControllers.add(IngredientController());
            });
          },
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('作り方など'),
        TextFormField(
          controller: _processController,
          decoration: const InputDecoration(labelText: '調理工程 (任意)', border: OutlineInputBorder(), alignLabelWithHint: true),
          maxLines: 10,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _impressionController,
          decoration: const InputDecoration(labelText: '感想 (任意)', border: OutlineInputBorder(), alignLabelWithHint: true),
          maxLines: 3,
        ),
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
          decoration: const InputDecoration(labelText: 'ロッド *', border: OutlineInputBorder()),
           validator: (value) => (value == null || value.isEmpty) ? '必須項目です' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tackleReelController,
          decoration: const InputDecoration(labelText: 'リール *', border: OutlineInputBorder()),
           validator: (value) => (value == null || value.isEmpty) ? '必須項目です' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tackleLureController,
          decoration: const InputDecoration(labelText: 'ルアー *', border: OutlineInputBorder()),
           validator: (value) => (value == null || value.isEmpty) ? '必須項目です' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tackleLineController,
          decoration: const InputDecoration(labelText: 'ライン *', border: OutlineInputBorder()),
           validator: (value) => (value == null || value.isEmpty) ? '必須項目です' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _appealPointController,
          decoration: const InputDecoration(labelText: 'アピールポイント *', border: OutlineInputBorder(), alignLabelWithHint: true),
          maxLines: 5,
           validator: (value) => (value == null || value.isEmpty) ? '必須項目です' : null,
        ),
      ],
    );
  }

  // --- ここからUIのビルド部分 ---
  @override
  Widget build(BuildContext context) {
    final maxImages = widget.tournament.rule.maxImageCount;
    final metric = widget.tournament.rule.metric;
    final imageSectionTitle = '写真 ($maxImages枚まで)';
    final bool useCamera = metric == 'SIZE' || metric == 'COUNT';

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
            child: SafeArea(
              bottom: false,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyAppBarDelegate(
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
                              Expanded(
                                child: Text(
                                  '${widget.tournament.name}へ提出',
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
                            _buildSectionTitle(imageSectionTitle),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _imageBytesList.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _imageBytesList.length) {
                                    return _imageBytesList.length < maxImages
                                        ? GestureDetector(
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
                                                child: InteractiveViewer(
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
                                          right: -12,
                                          child: IconButton(
                                            icon: const Icon(Icons.cancel, color: Colors.black54, size: 20),
                                            onPressed: () => setState(() => _imageBytesList.removeAt(index)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCard(
                        child: _buildDynamicForm(metric),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSubmitButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicForm(String metric) {
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

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        top: false,
        child: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: const StadiumBorder(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 8,
            ),
            onPressed: _isUploading ? null : _submitPost,
            child: _isUploading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text('提出する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildTemperatureSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text('$label: ${value.toStringAsFixed(1)} ℃', style: TextStyle(color: Colors.grey.shade700)),
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

class IngredientController {
  final TextEditingController nameController;
  final TextEditingController quantityController;

  IngredientController({String name = '', String quantity = ''})
      : nameController = TextEditingController(),
        quantityController = TextEditingController();

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
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