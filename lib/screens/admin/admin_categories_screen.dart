import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/teacher_activity_service.dart';

import 'admin_lessons_screen.dart';

class AdminCategoriesScreen extends StatefulWidget {
  final String level;
  final Color cardColor;
  final IconData icon;

  const AdminCategoriesScreen({
    super.key,
    required this.level,
    required this.cardColor,
    required this.icon,
  });

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final AuthService _authService = AuthService();
  final _categoryFormKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  // Method to count lessons for a specific category
  Future<int> _countLessonsInCategory(String categoryName) async {
    try {
      final lessonsSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('lessons')
          .orderByChild('category')
          .equalTo(categoryName)
          .get();

      if (lessonsSnapshot.exists) {
        final lessons = lessonsSnapshot.value as Map<dynamic, dynamic>;
        // Filter by level as well to ensure accuracy
        int count = 0;
        lessons.forEach((key, value) {
          if (value['level'] == widget.level) {
            count++;
          }
        });
        return count;
      }
      return 0;
    } catch (e) {
      debugPrint('Error counting lessons for category $categoryName: $e');
      return 0;
    }
  }

  // Method to update lesson count for a category
  Future<void> _updateCategoryLessonCount(String categoryKey, String categoryName) async {
    try {
      final lessonCount = await _countLessonsInCategory(categoryName);
      await FirebaseDatabase.instance
          .ref()
          .child('categories')
          .child(widget.level.toLowerCase())
          .child(categoryKey)
          .update({'lesson_count': lessonCount});
    } catch (e) {
      debugPrint('Error updating lesson count for category $categoryKey: $e');
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    bool isAdmin = await _authService.isAdmin();
    debugPrint('Admin check result in _showCreateCategoryDialog: $isAdmin');

    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Make Admin',
              onPressed: () async {
                try {
                  await _authService.setAdminStatus(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Admin status granted. Please try again.'),
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to grant admin status: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
      return;
    }

    _categoryController.clear();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _categoryFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Category',
                  style:
                      Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Hiragana & Katakana, Basic Vocabulary',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Category name is required' : null,
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
                        if (_categoryFormKey.currentState!.validate()) {
                          try {
                            debugPrint(
                                'Attempting to create category: ${_categoryController.text.trim()}');

                            // Verify admin status again before writing
                            bool isStillAdmin = await _authService.isAdmin();
                            if (!isStillAdmin) {
                              throw Exception(
                                  'Admin privileges lost. Please refresh and try again.');
                            }

                            final categoryName = _categoryController.text.trim();
                            final categoryKey = categoryName.toLowerCase().replaceAll(' ', '_');

                            // Count existing lessons for this category
                            final lessonCount = await _countLessonsInCategory(categoryName);

                            // Create category in the categories node
                            await FirebaseDatabase.instance
                                .ref()
                                .child('categories')
                                .child(widget.level.toLowerCase())
                                .child(categoryKey)
                                .set({
                              'name': categoryName,
                              'level': widget.level,
                              'created_at': DateTime.now().toIso8601String(),
                              'created_by': _authService.currentUser?.uid,
                              'lesson_count': lessonCount, // Use actual count instead of 0
                            });

                            debugPrint(
                                'Category created successfully at: categories/${widget.level.toLowerCase()}/$categoryKey');

                            // Log teacher activity
                            try {
                              await TeacherActivityService().logActivity(
                                activityType: 'category_created',
                                title: 'Category Created',
                                description: 'Created category: $categoryName',
                                relatedId: categoryKey,
                                metadata: {
                                  'categoryName': categoryName,
                                  'level': widget.level,
                                  'lessonCount': lessonCount,
                                },
                              );
                            } catch (activityError) {
                              print('Error logging category creation activity: $activityError');
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              _categoryController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Category successfully created with $lessonCount lessons.'),
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error creating category: $e');
                            if (mounted) {
                              String errorMessage = 'Failed to create category: $e';
                              if (e.toString().contains('permission_denied') ||
                                  e.toString().contains('Permission denied')) {
                                errorMessage =
                                    'Permission denied. Please ensure you have admin privileges and try again.';
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Theme.of(context).colorScheme.error,
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
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
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

  Future<void> _deleteCategory(String categoryKey, String categoryName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Are you sure you want to delete "$categoryName"? This will also delete all lessons in this category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // Delete category
        await FirebaseDatabase.instance
            .ref()
            .child('categories')
            .child(widget.level.toLowerCase())
            .child(categoryKey)
            .remove();

        // Delete all lessons in this category
        final lessonsSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('lessons')
            .orderByChild('category')
            .equalTo(categoryName)
            .get();

        if (lessonsSnapshot.exists) {
          final lessons = lessonsSnapshot.value as Map<dynamic, dynamic>;
          for (String lessonKey in lessons.keys) {
            await FirebaseDatabase.instance.ref().child('lessons').child(lessonKey).remove();
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Category and all its lessons deleted successfully.'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete category: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
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
        title: Text('${widget.level} Categories'),
        backgroundColor: widget.cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Refresh button to update lesson counts
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Update lesson counts for all categories
              final categoriesSnapshot = await FirebaseDatabase.instance
                  .ref()
                  .child('categories')
                  .child(widget.level.toLowerCase())
                  .get();

              if (categoriesSnapshot.exists) {
                final categoriesData = categoriesSnapshot.value as Map<dynamic, dynamic>;
                for (final entry in categoriesData.entries) {
                  final categoryKey = entry.key;
                  final categoryData = entry.value as Map<dynamic, dynamic>;
                  final categoryName = categoryData['name'];
                  await _updateCategoryLessonCount(categoryKey, categoryName);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Lesson counts updated successfully.'),
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              }
            },
          ),
          // Debug button to check admin status
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              final isAdmin = await _authService.isAdmin();
              final user = _authService.currentUser;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User: ${user?.uid}\nAdmin: $isAdmin'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
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
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.cardColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.level} Level',
                          style: TextStyle(
                            color: widget.cardColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Manage categories and their lessons',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateCategoryDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.cardColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Categories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Categories list - Now with real-time lesson counting
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('categories')
                  .child(widget.level.toLowerCase())
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading categories: ${snapshot.error}',
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No categories available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first category to get started',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final categoriesData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final categories = <Map<String, dynamic>>[];

                categoriesData.forEach((key, value) {
                  if (value is Map) {
                    categories.add({
                      'key': key,
                      'name': value['name'] ?? key,
                      'level': value['level'] ?? widget.level,
                      'created_at': value['created_at'],
                      'lesson_count': value['lesson_count'] ?? 0,
                    });
                  }
                });

                // Sort categories by name
                categories.sort((a, b) => a['name'].compareTo(b['name']));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminLessonsScreen(
                                level: widget.level,
                                category: category['name'],
                                cardColor: widget.cardColor,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: widget.cardColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.folder,
                                  color: widget.cardColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Use FutureBuilder to get real-time lesson count
                                    FutureBuilder<int>(
                                      future: _countLessonsInCategory(category['name']),
                                      builder: (context, countSnapshot) {
                                        final actualCount =
                                            countSnapshot.data ?? category['lesson_count'];
                                        return Text(
                                          '$actualCount lessons • Tap to manage',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteCategory(category['key'], category['name']);
                                  } else if (value == 'refresh') {
                                    _updateCategoryLessonCount(category['key'], category['name']);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'refresh',
                                    child: Row(
                                      children: [
                                        Icon(Icons.refresh, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Update Count'),
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
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // Also show categories from lessons for backward compatibility with lesson counts
            Text(
              'Categories from Lessons (Legacy)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),

            StreamBuilder<Map<String, int>>(
              stream: FirebaseDatabase.instance.ref().child('lessons').onValue.map((event) {
                final categoryLessonCounts = <String, int>{};
                if (event.snapshot.value != null) {
                  final data = event.snapshot.value as Map<dynamic, dynamic>;
                  data.forEach((key, value) {
                    if (value['level'] == widget.level) {
                      final category = value['category'] ?? 'Uncategorized';
                      categoryLessonCounts[category] = (categoryLessonCounts[category] ?? 0) + 1;
                    }
                  });
                }
                return categoryLessonCounts;
              }),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final categoryLessonCounts = snapshot.data!;
                if (categoryLessonCounts.isEmpty) {
                  return Text(
                    'No legacy categories found',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  );
                }

                final sortedCategories = categoryLessonCounts.keys.toList()..sort();

                return Column(
                  children: sortedCategories.map((category) {
                    final lessonCount = categoryLessonCounts[category] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      color: Colors.grey[50],
                      child: ListTile(
                        leading: Icon(Icons.folder_outlined, color: Colors.grey[600]),
                        title: Text(
                          category,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        subtitle: Text('$lessonCount lessons • From lessons data'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminLessonsScreen(
                                level: widget.level,
                                category: category,
                                cardColor: widget.cardColor,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
