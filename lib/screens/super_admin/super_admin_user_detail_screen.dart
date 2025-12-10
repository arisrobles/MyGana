import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/super_admin/super_admin_class_students_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';

class SuperAdminUserDetailScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userName;
  final String userRole;
  final int initialTabIndex;

  const SuperAdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userRole,
    this.initialTabIndex = 0,
  });

  @override
  State<SuperAdminUserDetailScreen> createState() => _SuperAdminUserDetailScreenState();
}

class _SuperAdminUserDetailScreenState extends State<SuperAdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final AuthService _auth = AuthService();
  late TabController _tabController;

  bool _loading = true;
  bool _classesLoading = true;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _userClasses = [];
  List<Map<String, dynamic>> _userProgress = [];
  List<Map<String, dynamic>> _userActivity = [];
  int _totalXp = 0;
  int _totalCoins = 0;
  int _lessonsCompleted = 0;
  int _quizzesCompleted = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);

    try {
      // Load user profile data
      final userSnapshot = await _db.child('users/${widget.userId}').get();
      if (userSnapshot.exists) {
        final rawData = userSnapshot.value;
        if (rawData is Map) {
          _userData = Map<String, dynamic>.from(rawData);
        } else {
          debugPrint('Warning: User data is not a Map: ${rawData.runtimeType}');
          _userData = <String, dynamic>{};
        }
      }

      if (widget.userRole == 'student') {
        await _loadStudentData();
      } else if (widget.userRole == 'teacher') {
        await _loadTeacherData();
      }

      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStudentData() async {
    try {
      // Load student progress from the correct Firebase path (users/{userId})
      final userSnapshot = await _db.child('users/${widget.userId}').get();
      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);

        // Extract progress data from user profile (consistent with student side)
        _totalXp = userData['totalXp'] ?? 0;
        _totalCoins = userData['mojiCoins'] ?? 0;

        // Load character progress for lessons completed (consistent with student side)
        final characterProgressSnapshot =
            await _db.child('users/${widget.userId}/characterProgress').get();
        if (characterProgressSnapshot.exists) {
          final characterProgress =
              Map<String, dynamic>.from(characterProgressSnapshot.value as Map);
          _lessonsCompleted = characterProgress.values.where((progress) {
            if (progress is Map && progress['done'] == true) {
              return true;
            }
            return false;
          }).length;

          // Convert character progress to lesson progress format
          _userProgress = characterProgress.entries
              .map((e) => {
                    'lessonId': e.key,
                    'data': {
                      'completed': e.value['done'] == true,
                      'xp': e.value['scorePercent'] ?? 0,
                      'masteryLevel': e.value['masteryLevel'] ?? 0,
                    },
                  })
              .toList();
        }

        // Load quiz results for quizzes completed (consistent with student side)
        final quizResults = userData['quizResults'] as List<dynamic>? ?? [];
        _quizzesCompleted = quizResults.length;

        // Load additional user statistics if available
        final userStats = userData['userStatistics'] as Map<String, dynamic>? ?? {};
        if (userStats.isNotEmpty) {
          _totalXp = userStats['totalXp'] ?? _totalXp;
          _totalCoins = userStats['totalCoins'] ?? _totalCoins;
          _lessonsCompleted = userStats['lessonsCompleted'] ?? _lessonsCompleted;
          _quizzesCompleted = userStats['quizzesCompleted'] ?? _quizzesCompleted;
        }
      }

      // Load class enrollment
      await _loadUserClasses();

      // Load recent activity
      await _loadUserActivity();
    } catch (e) {
      debugPrint('Error loading student data: $e');
    }
  }

  Future<void> _loadTeacherData() async {
    try {
      // Load teacher's classes (consistent with teacher side)
      await _loadUserClasses();

      // Load teacher activity from teacherActivity path (consistent with teacher side)
      await _loadTeacherActivity();
    } catch (e) {
      debugPrint('Error loading teacher data: $e');
    }
  }

  Future<void> _loadTeacherActivity() async {
    try {
      final activitySnapshot = await _db.child('teacherActivity/${widget.userId}').get();
      if (activitySnapshot.exists) {
        final activityData = Map<String, dynamic>.from(activitySnapshot.value as Map);
        _userActivity = activityData.entries
            .map((e) => {
                  'timestamp': e.key,
                  'data': e.value,
                })
            .toList();

        // Sort by timestamp (newest first)
        _userActivity.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      }
    } catch (e) {
      debugPrint('Error loading teacher activity: $e');
    }
  }

  Future<void> _loadUserClasses() async {
    try {
      setState(() => _classesLoading = true);
      debugPrint('=== LOADING CLASSES FOR ${widget.userRole.toUpperCase()}: ${widget.userId} ===');

      if (widget.userRole == 'student') {
        // For students, use the userClasses path which is more efficient
        final userClassesSnapshot = await _db.child('userClasses/${widget.userId}').get();
        debugPrint('User classes snapshot exists: ${userClassesSnapshot.exists}');

        if (userClassesSnapshot.exists) {
          final userClasses = Map<String, dynamic>.from(userClassesSnapshot.value as Map);
          debugPrint('Found ${userClasses.length} user classes: ${userClasses.keys.toList()}');
          _userClasses = [];

          for (final entry in userClasses.entries) {
            final classId = entry.key;
            final enrollmentData = Map<String, dynamic>.from(entry.value);
            debugPrint('Processing class $classId with enrollment data: $enrollmentData');

            // Get class information
            final classSnapshot = await _db.child('classes/$classId').get();
            if (classSnapshot.exists) {
              final classData = Map<String, dynamic>.from(classSnapshot.value as Map);
              debugPrint('Class $classId data: $classData');

              _userClasses.add({
                'classId': classId,
                'className': classData['nameSection'] ?? 'Unnamed Class',
                'yearRange': classData['yearRange'],
                'classCode': classData['classCode'],
                'role': 'student',
                'enrolledAt': enrollmentData['joinedAt'] ?? enrollmentData['enrolledAt'],
                'source': 'userClasses', // Debug: track data source
              });
            } else {
              debugPrint('Class $classId not found in classes collection');
            }
          }
        } else {
          debugPrint('No userClasses found for student ${widget.userId}');

          // Fallback 1: Check if user has a direct classId field
          if (_userData != null && _userData!['classId'] != null) {
            final classId = _userData!['classId'];
            debugPrint('Found direct classId in user data: $classId');

            final classSnapshot = await _db.child('classes/$classId').get();
            if (classSnapshot.exists) {
              final classData = Map<String, dynamic>.from(classSnapshot.value as Map);
              debugPrint('Class $classId data from direct classId: $classData');

              _userClasses.add({
                'classId': classId,
                'className': classData['nameSection'] ?? 'Unnamed Class',
                'yearRange': classData['yearRange'],
                'classCode': classData['classCode'],
                'role': 'student',
                'enrolledAt': _userData!['createdAt'], // Use creation date as fallback
                'source': 'directClassId', // Debug: track data source
              });
            }
          }

          // Fallback 2: Check classMembers path to find which classes this student belongs to
          if (_userClasses.isEmpty) {
            debugPrint('🔍 FALLBACK 2: Checking classMembers path for student ${widget.userId}');
            final classMembersSnapshot = await _db.child('classMembers').get();

            if (classMembersSnapshot.exists) {
              final classMembers = Map<String, dynamic>.from(classMembersSnapshot.value as Map);
              debugPrint(
                  '📊 Found ${classMembers.length} classes in classMembers: ${classMembers.keys.toList()}');

              bool foundStudent = false;
              for (final classEntry in classMembers.entries) {
                final classId = classEntry.key;
                final members = Map<String, dynamic>.from(classEntry.value);
                debugPrint(
                    '🔍 Checking class $classId with ${members.length} members: ${members.keys.toList()}');

                // Check if this student is a member of this class
                if (members.containsKey(widget.userId)) {
                  foundStudent = true;
                  debugPrint('✅ FOUND STUDENT ${widget.userId} in class $classId');

                  // Get class information
                  final classSnapshot = await _db.child('classes/$classId').get();
                  if (classSnapshot.exists) {
                    final classData = Map<String, dynamic>.from(classSnapshot.value as Map);
                    debugPrint('📋 Class $classId data from classMembers: $classData');

                    final memberData = Map<String, dynamic>.from(members[widget.userId]);
                    debugPrint('👤 Member data: $memberData');

                    _userClasses.add({
                      'classId': classId,
                      'className': classData['nameSection'] ?? 'Unnamed Class',
                      'yearRange': classData['yearRange'],
                      'classCode': classData['classCode'],
                      'role': 'student',
                      'enrolledAt': memberData['joinedAt'] ??
                          memberData['enrolledAt'] ??
                          _userData?['createdAt'],
                      'source': 'classMembers', // Debug: track data source
                    });
                  } else {
                    debugPrint('❌ Class $classId not found in classes collection');
                  }
                }
              }

              if (!foundStudent) {
                debugPrint('❌ Student ${widget.userId} NOT FOUND in any classMembers');
              }
            } else {
              debugPrint('❌ classMembers collection does not exist');
            }
          }
        }
      } else if (widget.userRole == 'teacher') {
        // For teachers, check all classes and find ones they manage
        final classesSnapshot = await _db.child('classes').get();
        if (classesSnapshot.exists) {
          final classes = Map<String, dynamic>.from(classesSnapshot.value as Map);
          _userClasses = [];

          for (final entry in classes.entries) {
            final classData = Map<String, dynamic>.from(entry.value);

            if (classData['adminId'] == widget.userId) {
              _userClasses.add({
                'classId': entry.key,
                'className': classData['nameSection'] ?? 'Unnamed Class',
                'yearRange': classData['yearRange'],
                'classCode': classData['classCode'],
                'role': 'teacher',
                'createdAt': classData['createdAt'],
              });
            }
          }
        }
      }

      debugPrint('🎯 FINAL RESULT: User classes count: ${_userClasses.length}');
      if (_userClasses.isNotEmpty) {
        for (int i = 0; i < _userClasses.length; i++) {
          final classData = _userClasses[i];
          debugPrint(
              '📚 Class ${i + 1}: ${classData['className']} (${classData['classId']}) - Source: ${classData['source']}');
        }
      } else {
        debugPrint('❌ NO CLASSES FOUND FOR USER ${widget.userId}');
      }
      debugPrint('=== END CLASS LOADING ===');

      // Trigger UI update after loading classes
      if (mounted) {
        setState(() => _classesLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user classes: $e');
      if (mounted) {
        setState(() => _classesLoading = false);
      }
    }
  }

  Future<void> _loadUserActivity() async {
    try {
      // For students, load from userActivity path
      if (widget.userRole == 'student') {
        final activitySnapshot = await _db.child('userActivity/${widget.userId}').get();
        if (activitySnapshot.exists) {
          final activityData = Map<String, dynamic>.from(activitySnapshot.value as Map);
          _userActivity = activityData.entries
              .map((e) => {
                    'timestamp': e.key,
                    'data': e.value,
                  })
              .toList();

          // Sort by timestamp (newest first)
          _userActivity.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        }
      }
      // For teachers, activity is loaded in _loadTeacherActivity()
    } catch (e) {
      debugPrint('Error loading user activity: $e');
    }
  }

  Future<void> _updateUserRole(String newRole) async {
    try {
      await _db.child('users/${widget.userId}').update({
        'role': newRole,
        'isAdmin': (newRole == 'teacher' || newRole == 'super_admin'),
        'updatedAt': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role updated to ${newRole.replaceAll('_', ' ')}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _navigateToClassStudents(Map<String, dynamic> classData) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SuperAdminClassStudentsScreen(
          classId: classData['classId'],
          className: classData['className'],
          yearRange: classData['yearRange'],
          classCode: classData['classCode'],
        ),
      ),
    );
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete ${widget.userName.isEmpty ? widget.userEmail : widget.userName}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.child('users/${widget.userId}').remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
          Navigator.pop(context, true); // Return true to refresh parent
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Details'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName.isEmpty ? widget.userEmail : widget.userName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: _updateUserRole,
            itemBuilder: (context) => [
              if (widget.userRole != 'student')
                const PopupMenuItem(value: 'student', child: Text('Make Student')),
              if (widget.userRole != 'teacher')
                const PopupMenuItem(value: 'teacher', child: Text('Make Teacher')),
              if (widget.userRole != 'super_admin')
                const PopupMenuItem(value: 'super_admin', child: Text('Make Super Admin')),
            ],
            icon: const Icon(Icons.more_vert),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.userId == _auth.currentUser?.uid ? null : _deleteUser,
            tooltip: widget.userId == _auth.currentUser?.uid
                ? 'Cannot delete current account'
                : 'Delete user',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.school), text: 'Classes'),
            Tab(icon: Icon(Icons.analytics), text: 'Progress'),
            Tab(icon: Icon(Icons.history), text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildClassesTab(),
          _buildProgressTab(),
          _buildActivityTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (widget.userName.isNotEmpty ? widget.userName[0] : widget.userEmail[0])
                        .toUpperCase(),
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userName.isEmpty ? widget.userEmail : widget.userName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userEmail,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.userRole.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // User Information
          _buildInfoCard('User Information', [
            _buildInfoRow('User ID', widget.userId),
            _buildInfoRow('Email', widget.userEmail),
            _buildInfoRow('Name', widget.userName.isEmpty ? 'Not set' : widget.userName),
            _buildInfoRow('Role', widget.userRole.replaceAll('_', ' ')),
            if (widget.userRole == 'student' && _userClasses.isNotEmpty) ...[
              _buildInfoRow('Section', _userClasses.first['className']),
              if (_userClasses.first['yearRange'] != null)
                _buildInfoRow('Year Range', _userClasses.first['yearRange']),
              if (_userClasses.first['classCode'] != null)
                _buildInfoRow('Class Code', _userClasses.first['classCode']),
              // Debug info
              _buildInfoRow('Debug: Classes Count', '${_userClasses.length}'),
              _buildInfoRow('Debug: Data Source', _userClasses.first['source'] ?? 'unknown'),
            ] else if (widget.userRole == 'student' && _userClasses.isEmpty) ...[
              _buildInfoRow('Section', 'Not enrolled in any class'),
              _buildInfoRow('Debug: Classes Count', '0'),
            ],
            if (_userData != null) ...[
              if (_userData!['firstName'] != null)
                _buildInfoRow('First Name', _userData!['firstName']),
              if (_userData!['lastName'] != null)
                _buildInfoRow('Last Name', _userData!['lastName']),
              if (_userData!['gender'] != null) _buildInfoRow('Gender', _userData!['gender']),
              if (_userData!['createdAt'] != null)
                _buildInfoRow('Created', _formatTimestamp(_userData!['createdAt'])),
              if (_userData!['lastLoginAt'] != null)
                _buildInfoRow('Last Login', _formatTimestamp(_userData!['lastLoginAt'])),
            ],
          ]),

          // Student Classes Section (if student has multiple classes)
          if (widget.userRole == 'student' && _userClasses.length > 1) ...[
            const SizedBox(height: 20),
            _buildInfoCard('Enrolled Classes', [
              for (int i = 0; i < _userClasses.length; i++) ...[
                _buildInfoRow(
                  'Class ${i + 1}',
                  '${_userClasses[i]['className']}${_userClasses[i]['yearRange'] != null ? ' (${_userClasses[i]['yearRange']})' : ''}',
                ),
                if (_userClasses[i]['classCode'] != null)
                  _buildInfoRow('  Class Code', _userClasses[i]['classCode']),
                if (_userClasses[i]['enrolledAt'] != null)
                  _buildInfoRow('  Enrolled', _formatTimestamp(_userClasses[i]['enrolledAt'])),
                if (i < _userClasses.length - 1) const Divider(),
              ],
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildClassesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Classes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            IconButton(
              onPressed: () async {
                await _loadUserClasses();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Classes',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_classesLoading)
          const Center(child: CircularProgressIndicator())
        else if (_userClasses.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No classes found',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Debug: Classes loading completed, count: ${_userClasses.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          )
        else
          ..._userClasses.map((classData) => _buildClassCard(classData)),
      ],
    );
  }

  Widget _buildProgressTab() {
    if (widget.userRole != 'student') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Progress tracking is only available for students',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Overview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.secondary,
                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Learning Progress',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProgressStat('XP', _totalXp.toString(), Icons.star),
                  _buildProgressStat('Coins', _totalCoins.toString(), Icons.monetization_on),
                  _buildProgressStat('Lessons', _lessonsCompleted.toString(), Icons.book),
                  _buildProgressStat('Quizzes', _quizzesCompleted.toString(), Icons.quiz),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Detailed Progress
        if (_userProgress.isNotEmpty) ...[
          Text(
            'Lesson Progress',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ..._userProgress.map((progress) => _buildProgressCard(progress)),
        ] else
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No progress data available',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (_userActivity.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No activity data available',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          )
        else
          ..._userActivity.take(20).map((activity) => _buildActivityCard(activity)),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    return GestureDetector(
      onTap: () => _navigateToClassStudents(classData),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                classData['role'] == 'teacher' ? Icons.person : Icons.school,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classData['className'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    classData['role'] == 'teacher' ? 'Managing Teacher' : 'Enrolled Student',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  if (classData['yearRange'] != null || classData['classCode'] != null)
                    Text(
                      '${classData['yearRange'] ?? ''}${classData['yearRange'] != null && classData['classCode'] != null ? ' • ' : ''}${classData['classCode'] != null ? 'Code: ${classData['classCode']}' : ''}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                if (classData['enrolledAt'] != null || classData['createdAt'] != null)
                  Text(
                    _formatTimestamp(classData['enrolledAt'] ?? classData['createdAt']),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildProgressCard(Map<String, dynamic> progress) {
    final data = progress['data'] as Map<String, dynamic>;
    final lessonId = progress['lessonId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            data['completed'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
            color: data['completed'] == true
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Character: $lessonId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (data['xp'] != null && data['xp'] > 0)
                      Text(
                        '${data['xp']} XP',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    if (data['masteryLevel'] != null && data['masteryLevel'] > 0) ...[
                      if (data['xp'] != null && data['xp'] > 0) const Text(' • '),
                      Text(
                        '${data['masteryLevel']}% Mastery',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final data = activity['data'] as Map<String, dynamic>;
    final timestamp = activity['timestamp'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['action'] ?? 'Unknown action',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
