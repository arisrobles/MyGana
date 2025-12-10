import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/lesson_model.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/screens/lesson_detail_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';

class CategoryScreen extends StatefulWidget {
  final String level;
  final Color cardColor;
  final IconData icon;

  const CategoryScreen({
    super.key,
    required this.level,
    required this.cardColor,
    required this.icon,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, List<Lesson>> _lessonsByCategory = {};
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadCategories();
  }

  Future<void> _initializeAndLoadCategories() async {
    // Initialize authentication first
    try {
      final isAuthenticated = await _authService.ensureAuthenticated();
      setState(() {
        _isAuthenticated = isAuthenticated;
      });
    } catch (e) {
      setState(() {
        _isAuthenticated = false;
      });
    }
    
    // Load categories regardless of authentication status
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load both local and Firebase data in parallel
      final futures = await Future.wait([
        _loadLocalCategories(),
        _loadFirebaseCategories(),
      ]);

      final localCategories = futures[0];
      final firebaseCategories = futures[1];

      // Combine and deduplicate categories
      final combinedCategories = _combineCategories(localCategories, firebaseCategories);

      setState(() {
        _lessonsByCategory = combinedCategories;
        _isLoading = false;
        _errorMessage = combinedCategories.isEmpty ? 'No categories available' : null;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading categories: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, List<Lesson>>> _loadLocalCategories() async {
    try {
      final allLessons = await DatabaseService().getLessons();
      final Map<String, List<Lesson>> lessonsByCategory = {};
      
      for (var lessonMap in allLessons) {
        final lesson = Lesson.fromMap(lessonMap);
        if (lesson.level == widget.level) {
          if (!lessonsByCategory.containsKey(lesson.category)) {
            lessonsByCategory[lesson.category] = [];
          }
          lessonsByCategory[lesson.category]!.add(lesson);
        }
      }
      
      return lessonsByCategory;
      
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, List<Lesson>>> _loadFirebaseCategories() async {
    if (!_isAuthenticated) {
      return {};
    }

    try {
      final levelKey = widget.level.toLowerCase();
      final categoriesRef = FirebaseDatabase.instance
          .ref()
          .child('categories/$levelKey');
      
      final categoriesSnapshot = await categoriesRef.get();
      
      if (!categoriesSnapshot.exists) {
        return {};
      }
      
      final categoriesData = categoriesSnapshot.value as Map<dynamic, dynamic>;
      final Map<String, List<Lesson>> lessonsByCategory = {};
      
      // Process each category
      for (final entry in categoriesData.entries) {
        final categoryData = entry.value as Map<dynamic, dynamic>;
        final categoryName = categoryData['name'] as String;
        
        // Fetch lessons for this category
        final categoryLessons = await _fetchFirebaseLessonsForCategory(categoryName);
        
        if (categoryLessons.isNotEmpty) {
          lessonsByCategory[categoryName] = categoryLessons;
        }
      }
      
      return lessonsByCategory;
      
    } catch (e) {
      return {};
    }
  }

  Future<List<Lesson>> _fetchFirebaseLessonsForCategory(String categoryName) async {
    try {
      final lessonsRef = FirebaseDatabase.instance.ref().child('lessons');
      
      // Try indexed query first
      try {
        final lessonsQuery = lessonsRef.orderByChild('category').equalTo(categoryName);
        final lessonsSnapshot = await lessonsQuery.get();
        
        if (lessonsSnapshot.exists) {
          return _processFirebaseLessons(lessonsSnapshot.value as Map<dynamic, dynamic>, categoryName);
        }
      } catch (indexError) {
        // Fallback to full scan
        final allLessonsSnapshot = await lessonsRef.get();
        
        if (allLessonsSnapshot.exists) {
          final allLessonsData = allLessonsSnapshot.value as Map<dynamic, dynamic>;
          final filteredLessons = <String, dynamic>{};
          
          allLessonsData.forEach((key, value) {
            if (value is Map && 
                value['category'] == categoryName &&
                value['level'] == widget.level) {
              filteredLessons[key] = value;
            }
          });
          
          return _processFirebaseLessons(filteredLessons, categoryName);
        }
      }
      
      return [];
      
    } catch (e) {
      return [];
    }
  }

  List<Lesson> _processFirebaseLessons(Map<dynamic, dynamic> lessonsData, String categoryName) {
    final List<Lesson> categoryLessons = [];
    
    lessonsData.forEach((lessonKey, lessonValue) {
      if (lessonValue is Map && lessonValue['level'] == widget.level) {
        final lesson = Lesson(
          id: lessonKey,
          title: lessonValue['title'] ?? 'Untitled',
          description: lessonValue['description'] ?? '',
          category: categoryName,
          level: widget.level,
        );
        
        categoryLessons.add(lesson);
      }
    });
    
    return categoryLessons;
  }

  Map<String, List<Lesson>> _combineCategories(
    Map<String, List<Lesson>> localCategories,
    Map<String, List<Lesson>> firebaseCategories,
  ) {
    final Map<String, List<Lesson>> combinedCategories = {};
    
    // Add all local categories first
    localCategories.forEach((category, lessons) {
      combinedCategories[category] = List.from(lessons);
    });
    
    // Add Firebase categories, merging with local where they exist
    firebaseCategories.forEach((category, firebaseLessons) {
      if (combinedCategories.containsKey(category)) {
        // Merge lessons, avoiding duplicates based on lesson ID
        final existingLessons = combinedCategories[category]!;
        final existingIds = existingLessons.map((l) => l.id).toSet();
        
        for (final firebaseLesson in firebaseLessons) {
          if (!existingIds.contains(firebaseLesson.id)) {
            existingLessons.add(firebaseLesson);
          } else {
            // Replace local lesson with Firebase version (Firebase takes priority)
            final index = existingLessons.indexWhere((l) => l.id == firebaseLesson.id);
            if (index != -1) {
              existingLessons[index] = firebaseLesson;
            }
          }
        }
      } else {
        // New category from Firebase
        combinedCategories[category] = List.from(firebaseLessons);
      }
    });
    
    // Sort lessons within each category
    combinedCategories.forEach((category, lessons) {
      lessons.sort((a, b) => a.title.compareTo(b.title));
    });
    
    return combinedCategories;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Grammar':
        return Icons.rule;
      case 'Vocabulary':
        return Icons.menu_book;
      case 'Hiragana & Katakana':
        return Icons.translate;
      case 'Kanji':
        return Icons.brush;
      case 'Expressions':
        return Icons.chat_bubble;
      case 'Listening & Pronunciation':
        return Icons.hearing;
      case 'Conversation':
        return Icons.forum;
      case 'Business Japanese':
        return Icons.business;
      case 'Writing Practice':
        return Icons.edit;
      case 'Love':
        return Icons.favorite;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.level} Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Refresh categories',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              widget.cardColor.withOpacity(0.1),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(_errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCategories,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _lessonsByCategory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.icon, size: 64, color: widget.cardColor.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'No categories available for ${widget.level} level',
                              style: TextStyle(color: widget.cardColor),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _lessonsByCategory.length,
                        itemBuilder: (context, index) {
                          final category = _lessonsByCategory.keys.elementAt(index);
                          final categoryLessons = _lessonsByCategory[category]!;
                          final categoryIcon = _getCategoryIcon(category);

                          return Hero(
                            tag: 'category_$category',
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: widget.cardColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(categoryIcon, color: widget.cardColor),
                                  ),
                                  title: Text(
                                    category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${categoryLessons.length} lessons',
                                    style: TextStyle(color: widget.cardColor),
                                  ),
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: categoryLessons.length,
                                      itemBuilder: (context, lessonIndex) {
                                        final lesson = categoryLessons[lessonIndex];
                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                            vertical: 8,
                                          ),
                                          leading: CircleAvatar(
                                            backgroundColor: widget.cardColor.withOpacity(0.1),
                                            child: Text(
                                              '${lessonIndex + 1}',
                                              style: TextStyle(
                                                color: widget.cardColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            lesson.title,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: Text(
                                            lesson.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: Icon(
                                            Icons.arrow_forward_ios, 
                                            size: 16, 
                                            color: widget.cardColor,
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => LessonDetailScreen(lesson: lesson),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}