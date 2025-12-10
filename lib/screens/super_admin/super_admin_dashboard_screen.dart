import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/super_admin_activity_service.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final SuperAdminActivityService _activityService = SuperAdminActivityService();
  int _totalUsers = 0;
  int _totalTeachers = 0;
  int _totalStudents = 0;
  int _totalLessons = 0;
  int _totalQuizzes = 0;
  int _totalClasses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // Count only teachers (exclude super_admin from count)
  Future<int> _countTeachers() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      int teacherCount = 0;

      // Get all users
      final usersSnapshot = await db.child('users').get();
      if (usersSnapshot.exists) {
        final users = usersSnapshot.value as Map<dynamic, dynamic>;

        for (final userData in users.values) {
          if (userData is Map) {
            // Only count users with role 'teacher' (exclude super_admin)
            final role = userData['role']?.toString();
            if (role == 'teacher') {
              teacherCount++;
              continue;
            }

            // Fallback to legacy isAdmin flag but only if role is not super_admin
            if (role != 'super_admin') {
              final isAdmin = userData['isAdmin'];
              if (isAdmin == true) {
                teacherCount++;
              }
            }
          }
        }
      }

      debugPrint('Total teachers counted: $teacherCount');
      return teacherCount;
    } catch (e) {
      debugPrint('Error counting teachers: $e');
      return 0;
    }
  }

  // Count students who are actually enrolled in classes
  Future<int> _countEnrolledStudents() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      final Set<String> enrolledStudentIds = <String>{};

      // Get all classes
      final classesSnapshot = await db.child('classes').get();
      if (classesSnapshot.exists) {
        final classes = classesSnapshot.value as Map<dynamic, dynamic>;

        // For each class, count enrolled students
        for (final classId in classes.keys) {
          final classMembersSnapshot = await db.child('classMembers').child(classId).get();
          if (classMembersSnapshot.exists) {
            final members = classMembersSnapshot.value as Map<dynamic, dynamic>;
            enrolledStudentIds.addAll(members.keys.cast<String>());
          }
        }
      }

      return enrolledStudentIds.length;
    } catch (e) {
      debugPrint('Error counting enrolled students: $e');
      return 0;
    }
  }

  Future<void> _loadStats() async {
    try {
      final db = FirebaseDatabase.instance.ref();

      // Load user counts with proper filtering
      final usersSnapshot = await db.child('users').get();
      if (usersSnapshot.exists) {
        final users = usersSnapshot.value as Map<dynamic, dynamic>;

        // Filter out any null or invalid entries
        final validUsers = users.values
            .where((user) => user != null && user is Map && user.containsKey('role'))
            .toList();

        _totalUsers = validUsers.length;
        // Count only teachers (exclude super_admin from count)
        _totalTeachers = await _countTeachers();
        // Count students who are actually enrolled in classes (more accurate)
        _totalStudents = await _countEnrolledStudents();
      }

      // Load content counts with proper filtering
      final lessonsSnapshot = await db.child('lessons').get();
      if (lessonsSnapshot.exists) {
        final lessons = lessonsSnapshot.value as Map<dynamic, dynamic>;
        // Filter out any null entries or system entries
        _totalLessons = lessons.values.where((lesson) => lesson != null && lesson is Map).length;
      }

      // Load quizzes from admin_quizzes (teacher-created quizzes)
      final quizzesSnapshot = await db.child('admin_quizzes').get();
      if (quizzesSnapshot.exists) {
        final quizzes = quizzesSnapshot.value as Map<dynamic, dynamic>;
        // Filter out placeholder and null entries
        _totalQuizzes = quizzes.values
            .where((quiz) =>
                quiz != null &&
                quiz is Map &&
                quiz.containsKey('title') &&
                quiz['title'] != '_placeholder')
            .length;
      }

      // Load classes count
      final classesSnapshot = await db.child('classes').get();
      if (classesSnapshot.exists) {
        final classes = classesSnapshot.value as Map<dynamic, dynamic>;
        // Filter out any null entries
        _totalClasses =
            classes.values.where((classData) => classData != null && classData is Map).length;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading super admin stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading dashboard...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildStatsGrid(),
                const SizedBox(height: 24),
                _buildQuickActionsGrid(),
                const SizedBox(height: 24),
                _buildSystemStatusCard(),
                const SizedBox(height: 24),
                _buildRecentActivitySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'System Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'Database',
                    'Connected',
                    Icons.storage,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'Authentication',
                    'Active',
                    Icons.security,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'Storage',
                    'Available',
                    Icons.cloud,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, String status, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your entire MyGana ecosystem',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          'Total Users',
          _isLoading ? '...' : '$_totalUsers',
          Icons.people,
          Theme.of(context).colorScheme.primary,
        ),
        _buildStatCard(
          'Teachers',
          _isLoading ? '...' : '$_totalTeachers',
          Icons.school,
          Theme.of(context).colorScheme.secondary,
        ),
        _buildStatCard(
          'Students',
          _isLoading ? '...' : '$_totalStudents',
          Icons.person,
          Theme.of(context).colorScheme.tertiary,
        ),
        _buildStatCard(
          'Classes',
          _isLoading ? '...' : '$_totalClasses',
          Icons.class_,
          Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 14,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 0),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildActionCard(
              'Manage Users',
              'Teachers & Students',
              Icons.people,
              Theme.of(context).colorScheme.primary,
              () => _showNavigationHint('Users'),
            ),
            _buildActionCard(
              'Content Overview',
              'Lessons & Quizzes',
              Icons.dashboard_customize,
              Theme.of(context).colorScheme.secondary,
              () => _showNavigationHint('Content'),
            ),
            _buildActionCard(
              'Analytics',
              'User Insights',
              Icons.analytics,
              Theme.of(context).colorScheme.tertiary,
              () => _showNavigationHint('Analytics'),
            ),
            _buildActionCard(
              'System Config',
              'App Settings',
              Icons.settings,
              Colors.orange,
              () => _showNavigationHint('System Config'),
            ),
            _buildActionCard(
              'Activity Monitor',
              'User Activities',
              Icons.monitor_heart,
              Colors.purple,
              () => _showNavigationHint('Activity'),
            ),
            _buildActionCard(
              'Profile Settings',
              'Account Management',
              Icons.person,
              Colors.teal,
              () => _showNavigationHint('Profile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.timeline,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                // Navigate to full activity screen
                Navigator.pushNamed(context, '/super_admin/activity');
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<SuperAdminActivity>>(
          stream: _activityService.watchAllActivities(limit: 5),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading activities',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final activities = snapshot.data ?? [];

            if (activities.isEmpty) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timeline,
                        color: Theme.of(context).colorScheme.outline,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No recent activity',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  ...activities.map((activity) => _buildActivityItem(activity)),
                  if (activities.length >= 5)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/super_admin/activity');
                        },
                        child: const Text('View All Activities'),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityItem(SuperAdminActivity activity) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: activity.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              activity.icon,
              color: activity.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.formattedDescription,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: activity.userRole == 'student'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity.userRole.toUpperCase(),
                        style: TextStyle(
                          color: activity.userRole == 'student'
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activity.userName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activity.timeAgo,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNavigationHint(String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.menu, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Use the menu button to navigate to $section',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
