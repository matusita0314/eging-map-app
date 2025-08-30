import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart'; 

class AddPostPage extends StatefulWidget {
  final LatLng location;

  const AddPostPage({super.key, required this.location});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _formKey = GlobalKey<FormState>();
  final List<Uint8List> _imageBytesList = [];
  bool _isUploading = false;
  String? _selectedWeather;
  String? _selectedSquidType;
  double _airTemperature = 15.0;
  double _waterTemperature = 15.0;
  DateTime? _selectedDateTime;

  final _dateTimeController = TextEditingController();
  final _egiNameController = TextEditingController();
  final _squidSizeController = TextEditingController();
  final _weightController = TextEditingController();
  final _tackleRodController = TextEditingController();
  final _tackleReelController = TextEditingController();
  final _tackleLineController = TextEditingController();
  final _egiMakerController = TextEditingController();
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _dateTimeController.dispose();
    _egiNameController.dispose();
    _squidSizeController.dispose();
    _weightController.dispose();
    _tackleRodController.dispose();
    _tackleReelController.dispose();
    _tackleLineController.dispose();
    _egiMakerController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_imageBytesList.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画像は3枚までです。')));
      return;
    }
    final pickedFiles = await ImagePicker().pickMultipleMedia();
    if (pickedFiles.isNotEmpty) {
      for (final file in pickedFiles) {
        if (_imageBytesList.length < 3) {
          _imageBytesList.add(await file.readAsBytes());
        }
      }
      setState(() {});
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('写真を1枚以上選択してください。')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final newPostDoc = FirebaseFirestore.instance.collection('posts').doc();
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.location.latitude,
        widget.location.longitude,
      );
      String region = "不明";
      if (placemarks.isNotEmpty) {
        region = placemarks[0].administrativeArea ?? "不明";
      }

      final hour = DateTime.now().hour;
      String timeOfDay;
      if (hour >= 5 && hour < 11) {
        timeOfDay = "朝";
      } else if (hour >= 11 && hour < 17) {
        timeOfDay = "昼";
      } else {
        timeOfDay = "夜";
      }

      await newPostDoc.set({
        'userId': user.uid,
        'userName': user.displayName ?? '名無しさん',
        'userPhotoUrl': user.photoURL,
        'createdAt': Timestamp.fromDate(_selectedDateTime!),
        'location': GeoPoint(widget.location.latitude, widget.location.longitude),
        'weather': _selectedWeather,
        'squidSize': double.tryParse(_squidSizeController.text) ?? 0.0,
        'weight': _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
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
        'imageUrls': [], 
        'thumbnailUrls': [],
        'region': region, 
        'squidType': _selectedSquidType, 
        'timeOfDay': timeOfDay, 
      });

      for (int i = 0; i < _imageBytesList.length; i++) {
        final imageBytes = _imageBytesList[i];
        final imageFileName = '${newPostDoc.id}_$i.jpg';
        final ref = FirebaseStorage.instance.ref('posts/${user.uid}/$imageFileName');
        await ref.putData(imageBytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿が完了しました！')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('投稿エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack( // ★ UI全体をStackでラップ
        children: [
          // --- メインコンテンツ ---
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
                              const Expanded(
                                child: Text(
                                  '釣果を投稿',
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
                                itemCount: _imageBytesList.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _imageBytesList.length) {
                                    return _imageBytesList.length < 3
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
                                              child: const Icon(Icons.add_a_photo, color: Colors.grey),
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
                                            onPressed: () {
                                              setState(() {
                                                _imageBytesList.removeAt(index);
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                                SizedBox(width: 8),
                                Text('投稿時の注意事項', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '・胴長が明確に分かるよう、必ず物差しなどを隣に置いてください。\n'
                              '・写真はイカの真上から撮影してください。\n'
                              '・故意に釣果を偽るなどの不正行為は絶対にやめてください。\n\n'
                              '※ 上記が守られていない投稿は、運営の判断で削除する場合があります。',
                              style: TextStyle(fontSize: 12, height: 1.4),
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
                            DropdownButtonFormField<String>(
                              value: _selectedSquidType,
                              decoration: const InputDecoration(labelText: 'イカの種類 *', prefixIcon: Icon(Icons.waves)),
                              hint: const Text('釣れたイカの種類を選択'),
                              items: ['アオリイカ', 'コウイカ', 'ヤリイカ', 'スルメイカ', 'ヒイカ', 'モンゴウイカ']
                                  .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                                  .toList(),
                              onChanged: (String? newValue) => setState(() => _selectedSquidType = newValue),
                              validator: (value) => value == null ? '必須項目です' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dateTimeController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: '釣った日時 *',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                                hintText: 'タップして日時を選択',
                              ),
                              onTap: () {
                                _selectDateTime(context);
                              },
                              validator: (value) {
                                if (_selectedDateTime == null) {
                                  return '必須項目です';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _egiNameController,
                              decoration: const InputDecoration(labelText: 'エギ・ルアー名', prefixIcon: Icon(Icons.label_outline)),
                              validator: (value) => value!.isEmpty ? '必須項目です' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _squidSizeController,
                              decoration: const InputDecoration(labelText: '胴長(cm)', prefixIcon: Icon(Icons.straighten_outlined)),
                              keyboardType: TextInputType.number,
                              validator: (value) => value!.isEmpty ? '必須項目です' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedWeather,
                              decoration: const InputDecoration(labelText: '天気', prefixIcon: Icon(Icons.wb_sunny_outlined), border: OutlineInputBorder()),
                              hint: const Text('天気を選択'),
                              items: ['晴れ', '快晴', '曇り', '雨']
                                  .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                                  .toList(),
                              onChanged: (String? newValue) => setState(() => _selectedWeather = newValue),
                              validator: (value) => value == null ? '必須項目です' : null,
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
                              decoration: const InputDecoration(labelText: '重さ (g)', prefixIcon: Icon(Icons.scale_outlined)),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 12.0),
                                  child: Text('気温: ${_airTemperature.toStringAsFixed(1)} ℃', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ),
                                Slider(
                                  value: _airTemperature,
                                  min: -10,
                                  max: 40,
                                  divisions: 100,
                                  label: _airTemperature.toStringAsFixed(1),
                                  onChanged: (double value) => setState(() => _airTemperature = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 12.0),
                                  child: Text('水温: ${_waterTemperature.toStringAsFixed(1)} ℃', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ),
                                Slider(
                                  value: _waterTemperature,
                                  min: 0,
                                  max: 35,
                                  divisions: 70,
                                  label: _waterTemperature.toStringAsFixed(1),
                                  onChanged: (double value) => setState(() => _waterTemperature = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _egiMakerController,
                              decoration: const InputDecoration(labelText: 'エギ・ルアーメーカー', prefixIcon: Icon(Icons.business_outlined)),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _tackleRodController,
                              decoration: const InputDecoration(labelText: 'ロッド', prefixIcon: Icon(Icons.sports_esports_outlined)),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _tackleReelController,
                              decoration: const InputDecoration(labelText: 'リール', prefixIcon: Icon(Icons.catching_pokemon_outlined)),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _tackleLineController,
                              decoration: const InputDecoration(labelText: 'ライン', prefixIcon: Icon(Icons.timeline_outlined)),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _captionController,
                              decoration: const InputDecoration(labelText: '一言コメント（任意）', prefixIcon: Icon(Icons.comment_outlined)),
                              maxLength: 100,
                            ),
                          ],
                        ),
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

  Future<void> _selectDateTime(BuildContext context) async {
    // 1. 日付を選択
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      // ピッカーの初期日付は、選択済みの値があればそれ、なければ今日
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;

    // 2. 時間を選択
    if (!context.mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      // ピッカーの初期時刻は、選択済みの値があればそれ、なければ現在時刻
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
    );

    if (pickedTime == null) return;

    // 3. 状態とテキスト入力欄を更新
    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      // ▼▼▼ 選択された日時を 'yyyy/MM/dd HH:mm' 形式で入力欄にセット ▼▼▼
      _dateTimeController.text = DateFormat('yyyy/MM/dd HH:mm').format(_selectedDateTime!);
    });
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        top: false,
        child: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
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
                : const Text('投稿する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
    );
  }
}

class _StickyAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyAppBarDelegate({required this.child});

  @override
  double get minExtent => 70.0; // ヘッダーの最小の高さ

  @override
  double get maxExtent => 70.0; // ヘッダーの最大の高さ

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent, // 背景のグラデーションを活かすため透明に
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true; // 常に再ビルドするようにしてシンプルに保つ
  }
}
