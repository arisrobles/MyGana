class Module {
  final String id;
  final String lessonId;
  final String title;
  final String? description;
  final String base64Data; // Base64 encoded PDF data
  final int fileSizeBytes; // Original file size in bytes
  final String fileName;
  final String uploadedByUid;
  final String? uploadedByEmail;
  final int uploadedAtMs;

  Module({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.description,
    required this.base64Data,
    required this.fileSizeBytes,
    required this.fileName,
    required this.uploadedByUid,
    required this.uploadedByEmail,
    required this.uploadedAtMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lessonId': lessonId,
      'title': title,
      'description': description,
      'base64Data': base64Data,
      'fileSizeBytes': fileSizeBytes,
      'fileName': fileName,
      'uploadedByUid': uploadedByUid,
      'uploadedByEmail': uploadedByEmail,
      'uploadedAtMs': uploadedAtMs,
    };
  }

  static Module fromMap(Map<dynamic, dynamic> map) {
    return Module(
      id: (map['id'] ?? '').toString(),
      lessonId: (map['lessonId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: map['description']?.toString(),
      base64Data: (map['base64Data'] ?? '').toString(),
      fileSizeBytes: int.tryParse((map['fileSizeBytes'] ?? '0').toString()) ?? 0,
      fileName: (map['fileName'] ?? '').toString(),
      uploadedByUid: (map['uploadedByUid'] ?? '').toString(),
      uploadedByEmail: map['uploadedByEmail']?.toString(),
      uploadedAtMs: int.tryParse((map['uploadedAtMs'] ?? '0').toString()) ?? 0,
    );
  }

  // Helper to get file size in readable format
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
