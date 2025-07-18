import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

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

  // 変更済みかを判定するフラグ
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
      print("ユーザー情報の読み込みエラー: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    // 変更不可の場合は何もしない
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

      // 名前の更新処理
      if (!_hasChangedDisplayName &&
          _nameController.text != _user.displayName) {
        await _user.updateDisplayName(_nameController.text);
        await _user.reload();
        updateData['displayName'] = _nameController.text;
        updateData['hasChangedDisplayName'] = true;
      }

      // 画像の更新処理
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

      // Firestoreのusersコレクションを更新
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
      print('プロフィール更新エラー: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィールを編集')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _imageData != null
                            ? MemoryImage(_imageData!)
                            : (_user.photoURL != null &&
                                          _user.photoURL!.isNotEmpty
                                      ? NetworkImage(_user.photoURL!)
                                      : null)
                                  as ImageProvider?,
                        child:
                            _imageData == null &&
                                (_user.photoURL == null ||
                                    _user.photoURL!.isEmpty)
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
                  const SizedBox(height: 16),

                  // ▼▼▼ 注意喚起メッセージを追加 ▼▼▼
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '表示名とプロフィール画像は一度しか変更できません。',
                            style: TextStyle(
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _hasChangedDisplayName ? '表示名 (変更済み)' : '表示名',
                      border: const OutlineInputBorder(),
                      filled: !_hasChangedDisplayName, // 編集可の場合のみ色付け
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
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _updateProfile,
                    child: const Text('保存する'),
                  ),
                ],
              ),
            ),
    );
  }
}
