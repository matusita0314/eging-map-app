// lib/pages/add_tournament_post_page.dart (実装版)

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTournamentPostPage extends StatefulWidget {
  final String tournamentId;
  const AddTournamentPostPage({super.key, required this.tournamentId});

  @override
  State<AddTournamentPostPage> createState() => _AddTournamentPostPageState();
}

class _AddTournamentPostPageState extends State<AddTournamentPostPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  Uint8List? _imageBytes;
  bool _isUploading = false;

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

  Future<void> _submitTournamentPost() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('判定用の写真を選択してください。')));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. 画像をFirebase Storageにアップロード
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'tournaments/${widget.tournamentId}/${_currentUser.uid}/$fileName',
      );
      await ref.putData(_imageBytes!);
      final imageUrl = await ref.getDownloadURL();

      // 2. Firestoreに大会用の投稿データを作成
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('posts')
          .add({
            'userId': _currentUser.uid,
            'userName': _currentUser.displayName ?? '名無しさん',
            'userPhotoUrl': _currentUser.photoURL ?? '',
            'imageUrl': imageUrl,
            'createdAt': Timestamp.now(),
            'status': 'pending', // 判定待ち状態
            'judgedSize': null, // 判定後に運営が入力する
            'score': 0, // 判定後に運営が入力する
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('釣果を提出しました！運営の判定をお待ちください。')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('提出エラー: $e');
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.tournamentId} 大会へ提出')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '判定用の写真を提出',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'メジャーなどをイカの横に置き、サイズが明確に分かるように撮影した写真をアップロードしてください。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 50,
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
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('提出する'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isUploading ? null : _submitTournamentPost,
          // アップロード中はローディング表示
          // child: _isUploading ? const SizedBox(...) : const Text(...)
          // ↑ childプロパティはElevatedButton.iconでは使わないので削除
        ),
      ),
    );
  }
}
