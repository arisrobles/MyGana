import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/class_management_service.dart';
import 'package:nihongo_japanese_app/services/teacher_activity_service.dart';

import 'admin_categories_screen.dart';

class AdminLevelsScreen extends StatefulWidget {
  const AdminLevelsScreen({super.key});

  @override
  State<AdminLevelsScreen> createState() => _AdminLevelsScreenState();
}

class _AdminLevelsScreenState extends State<AdminLevelsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedQuickAccessIndex = -1;
  final List<String> levels = const ['Beginner', 'Intermediate', 'Advanced'];
  final AuthService _authService = AuthService();
  final ClassManagementService _classService = ClassManagementService();

  // Data fetching methods
  Future<int> _getTotalStudents() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 0;

      // Get all classes for this teacher
      final classes = await _classService.watchAdminClasses().first;
      int totalStudents = 0;

      for (final classInfo in classes) {
        final students = await _classService.watchClassMembersWithStats(classInfo.classId).first;
        totalStudents += students.length;
      }

      return totalStudents;
    } catch (e) {
      debugPrint('Error fetching total students: $e');
      return 0;
    }
  }

  Future<int> _getTotalClasses() async {
    try {
      final classes = await _classService.watchAdminClasses().first;
      return classes.length;
    } catch (e) {
      debugPrint('Error fetching total classes: $e');
      return 0;
    }
  }

  Future<int> _getTotalLessons() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref().child('lessons').get();
      if (snapshot.exists) {
        final lessons = snapshot.value as Map<dynamic, dynamic>;
        return lessons.length;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching total lessons: $e');
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: primaryColor,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isDarkMode, primaryColor),
                const SizedBox(height: 24),
                // Teaching Performance Summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Teaching Performance',
                        Icons.insights_rounded,
                        onTap: () {
                          // Navigate to detailed teacher stats if needed
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTeachingPerformanceCard(context, isDarkMode, primaryColor),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Quick Access
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Quick Access',
                        Icons.grid_view_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildQuickAccessGrid(context, isDarkMode),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Recent Teaching Activity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Recent Activity',
                        Icons.history_rounded,
                        onTap: () {
                          // Refresh recent activity
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildRecentTeachingActivity(context, isDarkMode, primaryColor),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF2B2D42), const Color(0xFF1A1C2E)]
              : [primaryColor, Color.lerp(primaryColor, Colors.purple, 0.3)!],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final scaleAnimation = Tween<double>(
                      begin: 0.95,
                      end: 1.0,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
                    ));

                    return Transform.scale(
                      scale: scaleAnimation.value,
                      child: Text(
                        'MyGana Educator',
                        style: TextStyle(
                          fontFamily: 'TheLastShuriken',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              blurRadius: 6.0,
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              _buildProfileButton(context),
            ],
          ),
          const SizedBox(height: 24),
          _buildWelcomeMessage(context),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/admin_profile');
      },
      child: FutureBuilder<String?>(
        future: _getProfileImageUrl(),
        builder: (context, snapshot) {
          final profileImageUrl = snapshot.data;

          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildProfileImage(profileImageUrl),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage(String? profileImageUrl) {
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      if (profileImageUrl.startsWith('http')) {
        return Image.network(
          profileImageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            );
          },
        );
      } else {
        return Image.asset(
          profileImageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            );
          },
        );
      }
    }
    return const Icon(
      Icons.person_rounded,
      color: Colors.white,
      size: 24,
    );
  }

  Future<String?> _getProfileImageUrl() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return null;

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profileImageUrl')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching profile image URL: $e');
      return null;
    }
  }

  Widget _buildWelcomeMessage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Welcome back, Professor! ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon,
      {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTeachingPerformanceCard(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            // Navigate to detailed teacher stats
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with teaching overview
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, Color.lerp(primaryColor, Colors.green, 0.3)!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teaching Overview',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track your educational impact',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Teaching stats grid with real data
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _getTotalClasses(),
                        builder: (context, snapshot) {
                          return _buildStatItem(
                            context,
                            isDarkMode,
                            'Classes',
                            '${snapshot.data ?? 0}',
                            Icons.class_rounded,
                            Theme.of(context).colorScheme.secondary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _getTotalStudents(),
                        builder: (context, snapshot) {
                          return _buildStatItem(
                            context,
                            isDarkMode,
                            'Students',
                            '${snapshot.data ?? 0}',
                            Icons.people_rounded,
                            Theme.of(context).colorScheme.tertiary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _getTotalLessons(),
                        builder: (context, snapshot) {
                          return _buildStatItem(
                            context,
                            isDarkMode,
                            'Lessons',
                            '${snapshot.data ?? 0}',
                            Icons.book_rounded,
                            Theme.of(context).colorScheme.primary,
                          );
                        },
                      ),
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

  Widget _buildStatItem(BuildContext context, bool isDarkMode, String label, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, bool isDarkMode) {
    final List<Map<String, dynamic>> quickAccessItems = [
      {
        'title': 'Quiz Management',
        'subtitle': 'Create & manage',
        'icon': Icons.quiz_rounded,
        'color': Theme.of(context).colorScheme.secondary,
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).pushReplacementNamed('/admin', arguments: 1);
        },
      },
      {
        'title': 'Class Management',
        'subtitle': 'Manage students',
        'icon': Icons.group_rounded,
        'color': Theme.of(context).colorScheme.tertiary,
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).pushReplacementNamed('/admin', arguments: 2);
        },
      },
      {
        'title': 'Student Analytics',
        'subtitle': 'View progress',
        'icon': Icons.analytics_rounded,
        'color': Theme.of(context).colorScheme.secondary,
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).pushReplacementNamed('/admin', arguments: 3);
        },
      },
      {
        'title': 'Lessons Management',
        'subtitle': 'Manage lessons',
        'icon': Icons.book_rounded,
        'color': Theme.of(context).colorScheme.primary,
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminCategoriesScreen(
                level: 'Beginner',
                cardColor: Theme.of(context).colorScheme.primary,
                icon: Icons.school,
              ),
            ),
          );
        },
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: quickAccessItems.length,
        itemBuilder: (context, index) {
          final item = quickAccessItems[index];
          return _buildQuickAccessItem(
            context,
            isDarkMode,
            title: item['title'],
            subtitle: item['subtitle'],
            icon: item['icon'],
            color: item['color'],
            onTap: item['onTap'],
            index: index,
          );
        },
      ),
    );
  }

  Widget _buildQuickAccessItem(
    BuildContext context,
    bool isDarkMode, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    final isSelected = _selectedQuickAccessIndex == index;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTapDown: (_) {
                setState(() {
                  _selectedQuickAccessIndex = index;
                });
              },
              onTapUp: (_) {
                setState(() {
                  _selectedQuickAccessIndex = -1;
                });
                HapticFeedback.mediumImpact();
                onTap();
              },
              onTapCancel: () {
                setState(() {
                  _selectedQuickAccessIndex = -1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: isSelected ? Matrix4.translationValues(0, 2, 0) : Matrix4.identity(),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(isSelected ? 0.2 : 0.1),
                      blurRadius: isSelected ? 8 : 12,
                      offset: isSelected ? const Offset(0, 4) : const Offset(0, 6),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  icon,
                                  color: color,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: color.withOpacity(0.7),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentTeachingActivity(BuildContext context, bool isDarkMode, Color primaryColor) {
    return StreamBuilder<List<TeacherActivity>>(
      stream: TeacherActivityService().watchRecentActivities(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final activities = snapshot.data ?? [];

        if (activities.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'No recent activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your teaching activities will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: activities.map((activity) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildRecentActivityCard(
                context,
                isDarkMode,
                title: activity.title,
                description: activity.description,
                icon: activity.icon,
                color: activity.color,
                timeAgo: activity.timeAgo,
                progress: activity.progress,
                progressText: activity.progressText,
                onTap: () {
                  // Handle activity tap - could navigate to related content
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecentActivityCard(
    BuildContext context,
    bool isDarkMode, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String timeAgo,
    required double progress,
    required String progressText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: color.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            progressText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: color.withOpacity(0.7),
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
}
