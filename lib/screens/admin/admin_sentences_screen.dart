import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:nihongo_japanese_app/screens/admin/admin_modules_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:translator/translator.dart';

class AdminSentencesScreen extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final String level;
  final String category;
  final Color cardColor;

  const AdminSentencesScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.level,
    required this.category,
    required this.cardColor,
  });

  @override
  State<AdminSentencesScreen> createState() => _AdminSentencesScreenState();
}

class _AdminSentencesScreenState extends State<AdminSentencesScreen> {
  final AuthService _authService = AuthService();
  final _sentenceFormKey = GlobalKey<FormState>();
  final _editSentenceFormKey = GlobalKey<FormState>();
  final _japaneseController = TextEditingController();
  final _romajiController = TextEditingController();
  final _englishController = TextEditingController();
  final GoogleTranslator _translator = GoogleTranslator();
  final KanaKit _kanaKit = KanaKit();
  final FlutterTts _flutterTts = FlutterTts();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _englishController.addListener(_onEnglishInputChanged);
    _initTts();
  }

  @override
  void dispose() {
    _japaneseController.dispose();
    _romajiController.dispose();
    _englishController.dispose();
    _debounce?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _initTts() async {
    await _flutterTts.setLanguage('ja-JP');
    await _flutterTts.setSpeechRate(0.4); // Slower for better pronunciation
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    // Add these settings for better Japanese pronunciation
    await _flutterTts.setVoice({"name": "ja-JP-Standard-A", "locale": "ja-JP"});
    await _flutterTts.setQueueMode(1); // Queue mode for better handling
  }

  Future<void> _speakJapanese(String text) async {
    try {
      // Stop any ongoing speech before starting new one
      await _flutterTts.stop();
      // Add a small pause between requests
      await Future.delayed(const Duration(milliseconds: 100));
      await _flutterTts.speak(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TTS Error: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _onEnglishInputChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final englishText = _englishController.text.trim();
      if (englishText.isNotEmpty) {
        _translateToJapaneseAndRomaji(englishText);
      } else {
        _japaneseController.clear();
        _romajiController.clear();
      }
    });
  }

  Future<void> _translateToJapaneseAndRomaji(String englishText) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Processing translation...'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final translation = await _translator.translate(englishText, from: 'en', to: 'ja');
      final japaneseText = translation.text;

      _japaneseController.text = japaneseText;
      final romajiText = _convertToRomaji(japaneseText);
      _romajiController.text = romajiText;

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  String _convertToRomaji(String japaneseText) {
    return _kanaKit.toRomaji(japaneseText);
  }

  bool _isCharacterLesson() {
    return widget.lessonId.startsWith('BEGINNER-001') ||
        widget.lessonId.startsWith('BEGINNER-011') ||
        widget.category == 'Hiragana & Katakana';
  }

  Future<void> _showCreateSentenceDialog() async {
    bool isAdmin = await _authService.isAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    _japaneseController.clear();
    _romajiController.clear();
    _englishController.clear();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _sentenceFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCharacterLesson() ? 'Add Character/Phrase' : 'Add Sentence',
                  style:
                      Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.level} - ${widget.category} - ${widget.lessonTitle}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _englishController,
                  decoration: const InputDecoration(
                    labelText: 'English Translation',
                    border: OutlineInputBorder(),
                    hintText: 'Enter English to auto-translate',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'English translation is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _japaneseController,
                  decoration: InputDecoration(
                    labelText:
                        _isCharacterLesson() ? 'Japanese Character/Phrase' : 'Japanese Sentence',
                    border: const OutlineInputBorder(),
                    hintText: 'Ensure input is primarily kana for accurate Romaji',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.blue),
                      onPressed: () {
                        final text = _japaneseController.text.trim();
                        if (text.isNotEmpty) {
                          _speakJapanese(text);
                        }
                      },
                      tooltip: 'Listen to pronunciation',
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Japanese text is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _romajiController,
                  decoration: const InputDecoration(
                    labelText: 'Romaji',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Romaji is required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (_sentenceFormKey.currentState!.validate()) {
                          final sentence = {
                            'japanese': _japaneseController.text.trim(),
                            'romaji': _romajiController.text.trim(),
                            'english': _englishController.text.trim(),
                          };

                          try {
                            await FirebaseDatabase.instance
                                .ref()
                                .child('lessons/${widget.lessonId}/example_sentences')
                                .push()
                                .set(sentence);
                            if (mounted) {
                              Navigator.pop(context);
                              _japaneseController.clear();
                              _romajiController.clear();
                              _englishController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${_isCharacterLesson() ? 'Character/Phrase' : 'Sentence'} successfully created.'),
                                  backgroundColor: Colors.green[700],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              String errorMessage =
                                  'Failed to create ${_isCharacterLesson() ? 'character/phrase' : 'sentence'}: $e';
                              if (e.toString().contains('permission_denied')) {
                                errorMessage = 'You do not have permission to create content.';
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red[700],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showModifySentenceDialog(String sentenceId, Map<String, dynamic> sentence) async {
    bool isAdmin = await _authService.isAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    _japaneseController.text = sentence['japanese'] ?? '';
    _romajiController.text = sentence['romaji'] ?? '';
    _englishController.text = sentence['english'] ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _editSentenceFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCharacterLesson() ? 'Edit Character/Phrase' : 'Edit Sentence',
                  style:
                      Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.level} - ${widget.category} - ${widget.lessonTitle}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _englishController,
                  decoration: const InputDecoration(
                    labelText: 'English Translation',
                    border: OutlineInputBorder(),
                    hintText: 'Enter English to auto-translate',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'English translation is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _japaneseController,
                  decoration: InputDecoration(
                    labelText:
                        _isCharacterLesson() ? 'Japanese Character/Phrase' : 'Japanese Sentence',
                    border: const OutlineInputBorder(),
                    hintText: 'Ensure input is primarily kana for accurate Romaji',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.blue),
                      onPressed: () {
                        final text = _japaneseController.text.trim();
                        if (text.isNotEmpty) {
                          _speakJapanese(text);
                        }
                      },
                      tooltip: 'Listen to pronunciation',
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Japanese text is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _romajiController,
                  decoration: const InputDecoration(
                    labelText: 'Romaji',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Romaji is required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (_editSentenceFormKey.currentState!.validate()) {
                          final updatedSentence = {
                            'japanese': _japaneseController.text.trim(),
                            'romaji': _romajiController.text.trim(),
                            'english': _englishController.text.trim(),
                          };

                          try {
                            await FirebaseDatabase.instance
                                .ref()
                                .child('lessons/${widget.lessonId}/example_sentences/$sentenceId')
                                .update(updatedSentence);
                            if (mounted) {
                              Navigator.pop(context);
                              _japaneseController.clear();
                              _romajiController.clear();
                              _englishController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${_isCharacterLesson() ? 'Character/Phrase' : 'Sentence'} successfully updated.'),
                                  backgroundColor: Colors.green[700],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              String errorMessage =
                                  'Failed to update ${_isCharacterLesson() ? 'character/phrase' : 'sentence'}: $e';
                              if (e.toString().contains('permission_denied')) {
                                errorMessage = 'You do not have permission to update content.';
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red[700],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSentence(String sentenceId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirm Deletion',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                  'Are you sure you want to delete this ${_isCharacterLesson() ? 'character/phrase' : 'sentence'}? This action cannot be undone.'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('lessons/${widget.lessonId}/example_sentences/$sentenceId')
            .remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_isCharacterLesson() ? 'Character/Phrase' : 'Sentence'} successfully deleted.'),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to delete ${_isCharacterLesson() ? 'character/phrase' : 'sentence'}: $e'),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: widget.cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.cardColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate, color: widget.cardColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lessonTitle,
                              style: TextStyle(
                                color: widget.cardColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${widget.level} - ${widget.category}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showCreateSentenceDialog,
                        icon: const Icon(Icons.add),
                        label: Text(_isCharacterLesson() ? 'Add Character' : 'Add Sentence'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.cardColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminModulesScreen(
                                lessonId: widget.lessonId,
                                lessonTitle: widget.lessonTitle,
                                level: widget.level,
                                category: widget.category,
                                cardColor: widget.cardColor,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        label: const Text('Modules'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.cardColor,
                          side: BorderSide(color: widget.cardColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              _isCharacterLesson() ? 'Characters & Phrases' : 'Example Sentences',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('lessons/${widget.lessonId}/example_sentences')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          _isCharacterLesson() ? Icons.text_fields : Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_isCharacterLesson() ? 'characters/phrases' : 'sentences'} available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first ${_isCharacterLesson() ? 'character or phrase' : 'sentence'} to get started',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final sentences = <Map<String, dynamic>>[];
                data.forEach((key, value) {
                  sentences.add({
                    'id': key,
                    'japanese': value['japanese'] ?? '',
                    'romaji': value['romaji'] ?? '',
                    'english': value['english'] ?? '',
                  });
                });

                if (_isCharacterLesson()) {
                  // Grid layout for characters
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: sentences.length,
                    itemBuilder: (context, index) {
                      final sentence = sentences[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sentence['japanese'],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.volume_up,
                                            color: Colors.blue, size: 20),
                                        onPressed: () => _speakJapanese(sentence['japanese']),
                                        tooltip: 'Listen',
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showModifySentenceDialog(sentence['id'], sentence);
                                          } else if (value == 'delete') {
                                            _confirmDeleteSentence(sentence['id']);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Delete'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                sentence['romaji'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sentence['english'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                // List layout for sentences
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sentences.length,
                  itemBuilder: (context, index) {
                    final sentence = sentences[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sentence['japanese'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up, color: Colors.blue),
                                  onPressed: () => _speakJapanese(sentence['japanese']),
                                  tooltip: 'Listen to pronunciation',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _showModifySentenceDialog(sentence['id'], sentence),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDeleteSentence(sentence['id']),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sentence['romaji'],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sentence['english'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
