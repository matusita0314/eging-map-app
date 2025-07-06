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
  final _user = FirebaseAuth.instance.currentUser!;
  Uint8List? _imageData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 現在の表示名をフォームの初期値として設定
    _nameController.text = _user.displayName ?? '';
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageData = bytes;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表示名を入力してください。')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? photoUrl = _user.photoURL;

      // 新しい画像が選択されている場合のみ、アップロード処理を行う
      if (_imageData != null) {
        // 画像を圧縮
        final originalImage = img.decodeImage(_imageData!);
        final resizedImage = originalImage!.width > 500
            ? img.copyResize(originalImage, width: 500)
            : originalImage;
        final compressedImageData = img.encodeJpg(resizedImage, quality: 85);

        // Storageにアップロード
        final storageRef = FirebaseStorage.instance.ref('profile_images/${_user.uid}.jpg');
        await storageRef.putData(compressedImageData);
        photoUrl = await storageRef.getDownloadURL();
      }

      // FirebaseAuthのプロフィールを更新
      await _user.updateDisplayName(_nameController.text);
      if (photoUrl != null) {
        await _user.updatePhotoURL(photoUrl);
      }

      // Firestoreのusersコレクションも更新
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({
        'displayName': _nameController.text,
        'photoUrl': photoUrl ?? '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを更新しました。')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('プロフィール更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
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
                  // プロフィール画像プレビューと選択ボタン
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _imageData != null
                            ? MemoryImage(_imageData!)
                            : (_user.photoURL != null && _user.photoURL!.isNotEmpty
                                ? NetworkImage(_user.photoURL!)
                                : null) as ImageProvider?,
                        child: _imageData == null && (_user.photoURL == null || _user.photoURL!.isEmpty)
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      IconButton.filled(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _pickImage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 表示名入力フォーム
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '表示名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 保存ボタン
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: _updateProfile,
                    child: const Text('保存する'),
                  ),
                ],
              ),
            ),
    );
  }
}
