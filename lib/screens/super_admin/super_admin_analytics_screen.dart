import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class SuperAdminAnalyticsScreen extends StatefulWidget {
  const SuperAdminAnalyticsScreen({super.key});

  @override
  State<SuperAdminAnalyticsScreen> createState() => _SuperAdminAnalyticsScreenState();
}

class _SuperAdminAnalyticsScreenState extends State<SuperAdminAnalyticsScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;

  // Analytics data
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalLessons = 0;
  int _totalQuizzes = 0;
  int _totalClasses = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      // Load user statistics
      final usersSnapshot = await _db.child('users').get();
      if (usersSnapshot.exists) {
        final users = usersSnapshot.value as Map<dynamic, dynamic>;
        _totalUsers = users.length;

        // Count active users (users with recent activity)
        final now = DateTime.now().millisecondsSinceEpoch;
        final weekAgo = now - (7 * 24 * 60 * 60 * 1000);

        int activeCount = 0;
        for (final userData in users.values) {
          if (userData is Map) {
            final lastActive = userData['lastActive'] as int? ?? 0;
            if (lastActive > weekAgo) {
              activeCount++;
            }
          }
        }
        _activeUsers = activeCount;
      }

      // Load lesson statistics
      final lessonsSnapshot = await _db.child('lessons').get();
      if (lessonsSnapshot.exists) {
        final lessons = lessonsSnapshot.value as Map<dynamic, dynamic>;
        _totalLessons = lessons.length;
      }

      // Load quiz statistics
      final quizzesSnapshot = await _db.child('admin_quizzes').get();
      if (quizzesSnapshot.exists) {
        final quizzes = quizzesSnapshot.value as Map<dynamic, dynamic>;
        _totalQuizzes = quizzes.length;
      }

      // Load class statistics
      final classesSnapshot = await _db.child('classes').get();
      if (classesSnapshot.exists) {
        final classes = classesSnapshot.value as Map<dynamic, dynamic>;
        _totalClasses = classes.length;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
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
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    offset: const Offset(0, 8),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Analytics Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'System performance and user insights',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildContentOverviewCard(),
                  const SizedBox(height: 24), // Add bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Users',
                _totalUsers.toString(),
                Icons.people,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Active Users',
                _activeUsers.toString(),
                Icons.person_pin_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Lessons',
                _totalLessons.toString(),
                Icons.book,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Quizzes',
                _totalQuizzes.toString(),
                Icons.quiz,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Classes',
                _totalClasses.toString(),
                Icons.class_,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'System Status',
                'Online',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentOverviewCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'System Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildOverviewItem('Users', _totalUsers, Icons.people),
            _buildOverviewItem('Lessons', _totalLessons, Icons.book),
            _buildOverviewItem('Quizzes', _totalQuizzes, Icons.quiz),
            _buildOverviewItem('Classes', _totalClasses, Icons.class_),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
