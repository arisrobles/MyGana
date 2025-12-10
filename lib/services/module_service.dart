import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/module_model.dart';

class ModuleService {
  // Maximum file size: 5MB (to stay well below Firebase DB limits)
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Module?> pickAndUploadPdf(
      {required String lessonId, String? title, String? description}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final fileName = file.name.endsWith('.pdf') ? file.name : '${file.name}.pdf';

    // Read file bytes
    List<int> fileBytes;
    if (file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    } else if (file.bytes != null) {
      fileBytes = file.bytes!;
    } else {
      throw Exception('Unable to read file. Please select a valid PDF file.');
    }

    // Check file size
    final fileSizeBytes = fileBytes.length;
    if (fileSizeBytes > maxFileSizeBytes) {
      throw Exception(
          'File too large. Maximum size is ${(maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(0)}MB. Your file is ${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB.');
    }

    // Convert to base64
    final base64String = base64Encode(fileBytes);

    // Generate module ID
    final moduleId = _db.child('lessons/$lessonId/modules').push().key ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final user = _auth.currentUser;
    final uploadedByUid = user?.uid ?? 'unknown';
    final uploadedByEmail = user?.email;

    // Create module object
    final module = Module(
      id: moduleId,
      lessonId: lessonId,
      title: title?.trim().isNotEmpty == true ? title!.trim() : fileName,
      description: (description?.trim().isNotEmpty == true) ? description!.trim() : null,
      base64Data: base64String,
      fileSizeBytes: fileSizeBytes,
      fileName: fileName,
      uploadedByUid: uploadedByUid,
      uploadedByEmail: uploadedByEmail,
      uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    // Store in Firebase Database
    await _db.child('lessons/$lessonId/modules/$moduleId').set(module.toMap());
    return module;
  }

  Stream<List<Module>> streamModules(String lessonId) {
    return _db.child('lessons/$lessonId/modules').onValue.map((event) {
      if (!event.snapshot.exists) return <Module>[];
      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return map.values.map((e) => Module.fromMap(Map<dynamic, dynamic>.from(e as Map))).toList()
        ..sort((a, b) => b.uploadedAtMs.compareTo(a.uploadedAtMs));
    });
  }

  Future<void> deleteModule(String lessonId, Module module) async {
    // Simply remove from database (no storage cleanup needed)
    await _db.child('lessons/$lessonId/modules/${module.id}').remove();
  }

  // Helper method to get base64 data URI for display
  static String getBase64DataUri(String base64Data) {
    return 'data:application/pdf;base64,$base64Data';
  }
}
