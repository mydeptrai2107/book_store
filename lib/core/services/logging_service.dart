import 'package:book_store/core/constant/firebase_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/logging_model.dart';

class LoggingService {
  Future<void> logging(LoggingModel model) async {
    await FirebaseFirestore.instance
        .collection(FirebaseCollections.logging)
        .add(model.toJson());
  }
}
