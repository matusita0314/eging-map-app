import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/user_model.dart';

part 'user_provider.g.dart';

@Riverpod(keepAlive: true)
Future<UserModel> user(UserRef ref, String userId) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  return UserModel.fromFirestore(doc);
}