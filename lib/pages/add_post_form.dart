// import 'dart:typed_data';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:image/image.dart' as img; // imageパッケージをインポート

// class AddPostForm extends StatefulWidget {
//   final LatLng location;
//   const AddPostForm({super.key, required this.location});
//   @override
//   State<AddPostForm> createState() => _AddPostFormState();
// }

// class _AddPostFormState extends State<AddPostForm> {
//   final _squidSizeController = TextEditingController();
//   final _egiTypeController = TextEditingController();
//   Uint8List? _imageData;
//   final _picker = ImagePicker();
//   bool _isUploading = false;

//   Future<void> _pickImage() async {
//     // (このメソッドは変更なし)
//   }

//   Future<void> submitPost() async {
//     if (_imageData == null || _squidSizeController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('写真とイカのサイズは必須です。')));
//       return;
//     }
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     setState(() { _isUploading = true; });

//     try {
//       // ▼▼▼ ここからがリサイズ処理 ▼▼▼
//       // 1. 選択された画像データ(Uint8List)をデコード
//       img.Image? image = img.decodeImage(_imageData!);
//       if (image == null) throw Exception('画像のデコードに失敗');

//       // 2. 画像をリサイズ（幅が800pxより大きい場合のみリサイズ）
//       img.Image resizedImage = image.width > 800 ? img.copyResize(image, width: 800) : image;

//       // 3. リサイズ後の画像をJPG形式(品質85%)のデータに再エンコード
//       final resizedImageData = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));
//       // ▲▲▲ ここまで ▲▲▲

//       final storageRef = FirebaseStorage.instance.ref();
//       final imageFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
//       final imageRef = storageRef.child('posts/${user.uid}/$imageFileName');

//       // ▼▼▼ リサイズ後のデータをアップロード ▼▼▼
//       await imageRef.putData(resizedImageData);
//       final imageUrl = await imageRef.getDownloadURL();

//       await FirebaseFirestore.instance.collection('posts').add({
//         'userld': user.uid,
//         'userName': user.displayName ?? '名無しさん',
//         'userPhotoUrl': user.photoURL ?? "",
//         'squidSize': double.tryParse(_squidSizeController.text) ?? 0.0,
//         'egiType': _egiTypeController.text,
//         'imageUrl': imageUrl, // 保存されるのはリサイズ後のURL
//         'location': GeoPoint(widget.location.latitude, widget.location.longitude),
//         'createdAt': Timestamp.now(),
//         'likeCount': 0,
//         'commentCount': 0,
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿が完了しました。')));
//         Navigator.of(context).pop();
//       }
//     } catch (e) {
//       // エラー処理
//     } finally {
//       if (mounted) {
//         setState(() { _isUploading = false; });
//       }
//     }
//   }

//   // disposeやbuildメソッドは変更なし
//   @override
//   void dispose() {
//     _squidSizeController.dispose();
//     _egiTypeController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // (buildメソッドの中身は変更なし)
//     return SingleChildScrollView(
//       // ... 既存のUIコード
//     );
//   }
// }
