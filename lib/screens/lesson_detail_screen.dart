import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nihongo_japanese_app/models/lesson_model.dart';
import 'package:nihongo_japanese_app/models/module_model.dart';
import 'package:nihongo_japanese_app/screens/module_viewer_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:nihongo_japanese_app/services/user_activity_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({
    Key? key,
    required this.lesson,
  }) : super(key: key);

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final AuthService _authService = AuthService();
  final UserActivityService _activityService = UserActivityService();
  final ProgressService _progressService = ProgressService();
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _isLessonCompleted = false;
  List<Map<String, dynamic>> _exampleSentences = [];
  List<Module> _modules = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _initializeAuthentication();
  }

  void _initTts() async {
    await flutterTts.setLanguage('ja-JP');
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    await flutterTts.setVoice({"name": "ja-JP-Standard-A", "locale": "ja-JP"});
    await flutterTts.setQueueMode(1);
  }

  Future<void> _initializeAuthentication() async {
    try {
      final isAuthenticated = await _authService.ensureAuthenticated();
      setState(() {
        _isAuthenticated = isAuthenticated;
      });

      // Load content regardless of authentication status
      _loadLessonContent();
    } catch (e) {
      setState(() {
        _isAuthenticated = false;
      });

      // Still try to load local content
      _loadLessonContent();
    }
  }

  Future<void> _loadLessonContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Always load both local and Firebase data in parallel
      final futures = await Future.wait([
        _loadLocalData(),
        _loadFirebaseData(),
      ]);
      await _loadModules();

      final localSentences = futures[0];
      final firebaseSentences = futures[1];

      // Combine and deduplicate data
      final combinedSentences = _combineAndDeduplicateData(localSentences, firebaseSentences);

      setState(() {
        _exampleSentences = combinedSentences;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _exampleSentences = [];
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalData() async {
    try {
      final localSentences = await DatabaseService().getExampleSentences(
        widget.lesson.id,
        characterType: _getCharacterType(),
      );

      // Clean data without source markers
      final cleanLocalSentences = localSentences.map((sentence) {
        return {
          'id': sentence['id'],
          'japanese': sentence['japanese'],
          'romaji': sentence['romaji'],
          'english': sentence['english'],
          'priority': 1, // Lower priority than Firebase
        };
      }).toList();

      return cleanLocalSentences;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadFirebaseData() async {
    if (!_isAuthenticated) {
      return [];
    }

    try {
      final lessonRef = FirebaseDatabase.instance.ref().child('lessons/${widget.lesson.id}');

      final lessonSnapshot = await lessonRef.get();

      if (!lessonSnapshot.exists) {
        return [];
      }

      final lessonData = lessonSnapshot.value as Map<dynamic, dynamic>;
      final exampleSentencesData = lessonData['example_sentences'];
      final firebaseSentences = <Map<String, dynamic>>[];

      if (exampleSentencesData != null && exampleSentencesData is Map) {
        (exampleSentencesData).forEach((key, value) {
          if (value is Map) {
            firebaseSentences.add({
              'id': key,
              'japanese': value['japanese'] ?? '',
              'romaji': value['romaji'] ?? '',
              'english': value['english'] ?? '',
              'priority': 2, // Higher priority than local
            });
          }
        });
      }

      return firebaseSentences;
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadModules() async {
    try {
      final ref = FirebaseDatabase.instance.ref().child('lessons/${widget.lesson.id}/modules');
      final snap = await ref.get();
      if (!snap.exists) {
        setState(() {
          _modules = [];
        });
        return;
      }
      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      final mods = map.values
          .map((e) => Module.fromMap(Map<dynamic, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.uploadedAtMs.compareTo(a.uploadedAtMs));
      setState(() {
        _modules = mods;
      });
    } catch (_) {
      setState(() {
        _modules = [];
      });
    }
  }

  List<Map<String, dynamic>> _combineAndDeduplicateData(
    List<Map<String, dynamic>> localData,
    List<Map<String, dynamic>> firebaseData,
  ) {
    final Map<String, Map<String, dynamic>> uniqueSentences = {};

    // Add local data first
    for (final sentence in localData) {
      final japanese = sentence['japanese'] as String;
      if (japanese.isNotEmpty) {
        uniqueSentences[japanese] = sentence;
      }
    }

    // Add Firebase data, which will override local data for duplicates
    for (final sentence in firebaseData) {
      final japanese = sentence['japanese'] as String;
      if (japanese.isNotEmpty) {
        uniqueSentences[japanese] = sentence; // Firebase takes priority
      }
    }

    // Sort by priority (Firebase first, then local) and then by content
    final sortedSentences = uniqueSentences.values.toList();
    sortedSentences.sort((a, b) {
      final aPriority = a['priority'] as int? ?? 0;
      final bPriority = b['priority'] as int? ?? 0;
      if (aPriority != bPriority) {
        return bPriority.compareTo(aPriority); // Higher priority first
      }
      return (a['japanese'] as String).compareTo(b['japanese'] as String);
    });

    return sortedSentences;
  }

  Future<void> _speakJapanese(String text) async {
    await flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await flutterTts.speak(text);
  }

  Future<void> _markLessonCompleted() async {
    if (!_isAuthenticated) return;

    try {
      // Log lesson completion activity
      await _activityService.logLessonCompleted(
        widget.lesson.id,
        widget.lesson.title,
        widget.lesson.category,
      );

      // Update progress service
      await _progressService.addLessonCompletion(
        widget.lesson.id,
        widget.lesson.title,
        widget.lesson.category,
      );

      // Update UI state
      setState(() {
        _isLessonCompleted = true;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lesson "${widget.lesson.title}" completed!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      debugPrint('Lesson completed: ${widget.lesson.title}');
    } catch (e) {
      debugPrint('Error marking lesson as completed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing lesson: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCharacterDetail(BuildContext context, String japanese, String romaji) {
    final List<String> characters = japanese.replaceAll(' ', '').split('');
    final List<String> romajiParts = romaji.split(' ');
    final List<String> romajiList = List.generate(
        characters.length, (index) => index < romajiParts.length ? romajiParts[index] : '');

    final PageController pageController = PageController();
    int currentPage = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (_modules.isNotEmpty) ...[
                  Text(
                    'Modules',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _modules.length,
                    itemBuilder: (context, index) {
                      final m = _modules[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          title: Text(m.title),
                          subtitle: Text(m.description ?? 'PDF module'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ModuleViewerScreen(title: m.title, base64Data: m.base64Data),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${currentPage + 1} / ${characters.length}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PageView.builder(
                        controller: pageController,
                        itemCount: characters.length,
                        onPageChanged: (index) {
                          setState(() => currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      characters[index],
                                      style: const TextStyle(
                                        fontSize: 80,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.volume_up),
                                      onPressed: () => _speakJapanese(characters[index]),
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  romajiList[index],
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      Positioned(
                        left: 0,
                        child: currentPage > 0
                            ? IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: () {
                                  pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                      Positioned(
                        right: 0,
                        child: currentPage < characters.length - 1
                            ? IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () {
                                  pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    characters.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentPage == index ? Colors.blue : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isCharacterLesson() {
    return widget.lesson.id.startsWith('BEGINNER-001') ||
        widget.lesson.id.startsWith('BEGINNER-011') ||
        widget.lesson.category == 'Hiragana & Katakana';
  }

  String _getCharacterType() {
    if (widget.lesson.id.startsWith('BEGINNER-001') ||
        widget.lesson.title.toLowerCase().contains('hiragana')) {
      return 'Hiragana';
    }
    if (widget.lesson.id.startsWith('BEGINNER-011') ||
        widget.lesson.title.toLowerCase().contains('katakana')) {
      return 'Katakana';
    }
    return 'Hiragana';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLessonContent,
            tooltip: 'Refresh content',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading lesson content...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.label, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          widget.lesson.level,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.category, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          widget.lesson.category,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.lesson.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _isCharacterLesson() ? 'Characters' : 'Example Sentences',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (_exampleSentences.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            _isCharacterLesson() ? Icons.text_fields : Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No ${_isCharacterLesson() ? 'characters' : 'sentences'} available',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Content will appear here when available',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (_isCharacterLesson())
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _exampleSentences.length,
                      itemBuilder: (context, index) {
                        final example = _exampleSentences[index];

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _showCharacterDetail(
                              context,
                              example['japanese'] as String,
                              example['romaji'] as String,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      example['japanese'] as String,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Flexible(
                                    child: Text(
                                      example['romaji'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _exampleSentences.length,
                      itemBuilder: (context, index) {
                        final example = _exampleSentences[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        example['japanese'] as String,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up),
                                      onPressed: () =>
                                          _speakJapanese(example['japanese'] as String),
                                      color: Colors.blue,
                                    ),
                                    // IconButton(
                                    //   icon: const Icon(Icons.mic),
                                    //   onPressed: () {
                                    //     Navigator.push(
                                    //       context,
                                    //       MaterialPageRoute(
                                    //         builder: (context) => PronunciationPracticeScreen(
                                    //           key: ValueKey('practice-${example['japanese']}'),
                                    //           japanese: example['japanese'] as String,
                                    //           romaji: example['romaji'] as String,
                                    //           english: example['english'] as String,
                                    //         ),
                                    //       ),
                                    //     );
                                    //   },
                                    //   color: Colors.green,
                                    // ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  example['romaji'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  example['english'] as String,
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
                    ),
                  const SizedBox(height: 32),
                  if (_isAuthenticated && !_isLessonCompleted)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _markLessonCompleted,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark as Completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  if (_isLessonCompleted)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'Lesson Completed!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
