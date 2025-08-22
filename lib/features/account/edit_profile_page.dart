import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _introductionController = TextEditingController();
  final _user = FirebaseAuth.instance.currentUser!;

  Uint8List? _imageData;
  bool _isLoading = true;

  bool _hasChangedDisplayName = false;
  bool _hasChangedPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  Future<void> _loadCurrentUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null && mounted) {
        setState(() {
          _nameController.text = userData['displayName'] ?? '';
          _introductionController.text = userData['introduction'] ?? '';
          _hasChangedDisplayName = userData['hasChangedDisplayName'] ?? false;
          _hasChangedPhoto = userData['hasChangedPhoto'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("ユーザー情報の読み込みエラー: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    if (_hasChangedPhoto) return;
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageData = bytes;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('表示名を入力してください。')));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updateData = {
        'introduction': _introductionController.text,
      };

      if (!_hasChangedDisplayName &&
          _nameController.text != _user.displayName) {
        await _user.updateDisplayName(_nameController.text);
        await _user.reload();
        updateData['displayName'] = _nameController.text;
        updateData['hasChangedDisplayName'] = true;
      }

      if (!_hasChangedPhoto && _imageData != null) {
        final originalImage = img.decodeImage(_imageData!);
        final resizedImage = originalImage!.width > 500
            ? img.copyResize(originalImage, width: 500)
            : originalImage;
        final compressedImageData = img.encodeJpg(resizedImage, quality: 85);

        final storageRef = FirebaseStorage.instance.ref(
          'profile_images/${_user.uid}/profile.jpg',
        );
        await storageRef.putData(compressedImageData);
        final photoUrl = await storageRef.getDownloadURL();

        await _user.updatePhotoURL(photoUrl);
        await _user.reload();
        updateData['photoUrl'] = photoUrl;
        updateData['hasChangedPhoto'] = true;
      }

      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .update(updateData);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました。')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('プロフィール更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introductionController.dispose();
    super.dispose();
  }
  
  // ★★★ UI構造を全面的に刷新 ★★★
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        // ★ 背景グラデーション
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
        child: Stack(
          children: [
            SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    // ★ フローティングAppBar
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
                            const Expanded(child: Text('プロフィールを編集', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13547a)))),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // ★ メインコンテンツをカード化
                          Container(
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundImage: _imageData != null
                                          ? MemoryImage(_imageData!)
                                          : (_user.photoURL != null && _user.photoURL!.isNotEmpty
                                              ? CachedNetworkImageProvider(_user.photoURL!)
                                              : null) as ImageProvider?,
                                      child: _imageData == null && (_user.photoURL == null || _user.photoURL!.isEmpty)
                                          ? const Icon(Icons.person, size: 60)
                                          : null,
                                    ),
                                    if (!_hasChangedPhoto)
                                      IconButton.filled(
                                        icon: const Icon(Icons.camera_alt),
                                        onPressed: _pickImage,
                                        tooltip: 'プロフィール画像を変更',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.blue),
                                      SizedBox(width: 12),
                                      Expanded(child: Text('表示名とプロフィール画像は一度しか変更できません。', style: TextStyle(height: 1.4, color: Colors.black87))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: _hasChangedDisplayName ? '表示名 (変更済み)' : '表示名',
                                    border: const OutlineInputBorder(),
                                    filled: !_hasChangedDisplayName,
                                    fillColor: Colors.white,
                                  ),
                                  enabled: !_hasChangedDisplayName,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _introductionController,
                                  decoration: const InputDecoration(
                                    labelText: '自己紹介',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true, // ラベルを左上に
                                  ),
                                  maxLines: 5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 100), // ボタンとのスペース
                        ],
                      ),
                    ),
              ),
            ),
            // ★ 保存ボタンを画面下部に固定
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _updateProfile,
                    child: const Text('保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}