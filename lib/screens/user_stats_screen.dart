import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/leaderboard_screen.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:nihongo_japanese_app/services/streak_analytics_service.dart';
import 'package:nihongo_japanese_app/utils/character_constants.dart';
import 'package:nihongo_japanese_app/widgets/sync_status_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStatsScreen extends StatefulWidget {
  const UserStatsScreen({super.key});

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
  final FirebaseUserSyncService _firebaseSync = FirebaseUserSyncService();
  bool _isLoading = true;
  StreamSubscription<User?>? _authStateSubscription;
  Map<String, dynamic>? _userData;
  StreamSubscription<DatabaseEvent>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupAuthStateListener();
  }

  void _setupAuthStateListener() {
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        // Clear existing subscription
        _userDataSubscription?.cancel();
        // Refresh Firebase listeners for the new user
        _firebaseSync.refreshListeners();
        // Refresh data when auth state changes
        _initializeData();
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _userDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _userData = null;
            _isLoading = false;
          });
        }
        return;
      }

      // Ensure all data is synced to Firebase before fetching
      await _ensureDataSync();
      
      // Fetch user data directly from Firebase
      final userData = await _firebaseSync.getRealtimeUserData();
      
      if (mounted) {
        setState(() {
          _userData = userData ?? {};
          _isLoading = false;
        });
      }

      // Set up real-time listener for user data changes
      _setupRealtimeListener();
    } catch (e) {
      print('Error initializing user stats data: $e');
      if (mounted) {
        setState(() {
          _userData = {};
          _isLoading = false;
        });
      }
    }
  }

  // Ensure all progress data is synced with Firebase
  Future<void> _ensureDataSync() async {
    try {
      // Sync user progress to Firebase
      await _firebaseSync.syncUserProgressToFirebase();
      
      // Sync any pending data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Sync story points if they exist
      final storyPoints = prefs.getInt('story_total_points') ?? 0;
      if (storyPoints > 0) {
        await _firebaseSync.syncMojiPoints(storyPoints);
      }
      
      // Sync quiz points if they exist
      final quizPoints = prefs.getInt('quiz_total_points') ?? 0;
      if (quizPoints > 0) {
        await _firebaseSync.syncMojiPoints(quizPoints);
      }
      
      // Sync total points
      final totalPoints = prefs.getInt('total_points') ?? 0;
      if (totalPoints > 0) {
        await _firebaseSync.syncMojiPoints(totalPoints);
      }
      
      print('Data sync completed successfully');
    } catch (e) {
      print('Error during data sync: $e');
    }
  }

  void _setupRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDataSubscription?.cancel();
    _userDataSubscription = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(user.uid)
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        try {
          final snapshotValue = event.snapshot.value;
          if (snapshotValue != null) {
            final userData = Map<String, dynamic>.from(snapshotValue as Map<dynamic, dynamic>);
            setState(() {
              _userData = userData;
            });
          }
        } catch (e) {
          print('Error parsing Firebase data: $e');
          // Keep existing data if parsing fails
        }
      }
    }, onError: (error) {
      print('Firebase listener error: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1C2E) : Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Your Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          const SyncStatusWidget(showDetails: true),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.leaderboard_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: _initializeData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null || _userData!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No user data available',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please log in to view your statistics',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeData,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _initializeData,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(context, isDarkMode, primaryColor),
                        const SizedBox(height: 24),
                        _buildProgressOverview(context, isDarkMode, primaryColor),
                        const SizedBox(height: 24),
                        _buildCharacterMasterySection(context, isDarkMode, primaryColor),
                        const SizedBox(height: 24),
                        _buildQuizPerformanceSection(context, isDarkMode, primaryColor),
                        const SizedBox(height: 24),
                        _buildStoryStatisticsSection(context, isDarkMode, primaryColor),
                        const SizedBox(height: 24),
                        _buildStreakAnalyticsSection(context, isDarkMode, primaryColor),
                        const SizedBox(height: 24),
                        _buildAchievementsSection(context, isDarkMode, primaryColor),
                      ],
                    ),
                  ),
            ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, Color.lerp(primaryColor, Colors.purple, 0.3)!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _userData != null
                      ? Builder(
                          builder: (context) {
                            final stats = _userData!;
                      final level = stats['level'] ?? 1;
                      final totalXp = stats['totalXp'] ?? 0;
                      final nextLevelXp = level * 1000;
                      final currentLevelXp = (level - 1) * 1000;
                      final progressToNextLevel =
                          (totalXp - currentLevelXp) / (nextLevelXp - currentLevelXp);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level $level',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$totalXp XP',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressToNextLevel.clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(nextLevelXp - totalXp)} XP to next level',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                        )
                      : const CircularProgressIndicator(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverview(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Overview',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FutureBuilder<String>(
                future: _getStreakPercentage(),
                builder: (context, snapshot) {
                  return _buildOverviewCard(
                    context,
                    isDarkMode,
                    'Streak Success %',
                    Icons.trending_up,
                    Colors.purple,
                    snapshot.data ?? '0.0%',
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FutureBuilder<String>(
                future: _getDailyGoalProgress(),
                builder: (context, snapshot) {
                  return _buildOverviewCard(
                    context,
                    isDarkMode,
                    'Daily Goal',
                    Icons.timer,
                    Colors.blue,
                    snapshot.data ?? '0%',
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                context,
                isDarkMode,
                'Total Points',
                Icons.stars,
                Colors.indigo,
                _getTotalPoints(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOverviewCard(
                context,
                isDarkMode,
                'Longest Streak',
                Icons.workspace_premium,
                Colors.amber,
                _getLongestStreak(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharacterMasterySection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Character Mastery',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMasteryCard(
                context,
                isDarkMode,
                'Hiragana',
                Icons.abc,
                Colors.green,
                _getScriptCompletionFraction('hiragana'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMasteryCard(
                context,
                isDarkMode,
                'Katakana',
                Icons.abc,
                Colors.blue,
                _getScriptCompletionFraction('katakana'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizPerformanceSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quiz Performance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final quizStats = _getQuizStatistics();
            final totalQuizzes = quizStats['totalQuizzes'] ?? 0;
            final averageScore = quizStats['averageScore'] ?? 0.0;
            final perfectScores = quizStats['perfectScores'] ?? 0;

            return Row(
              children: [
                Expanded(
                  child: _buildQuizCard(
                    context,
                    isDarkMode,
                    'Total Quizzes',
                    Icons.quiz,
                    Colors.indigo,
                    '$totalQuizzes',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuizCard(
                    context,
                    isDarkMode,
                    'Avg. Score',
                    Icons.trending_up,
                    Colors.teal,
                    '${averageScore.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuizCard(
                    context,
                    isDarkMode,
                    'Perfect',
                    Icons.celebration,
                    Colors.pink,
                    '$perfectScores',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStoryStatisticsSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Story Mode Statistics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final storyStats = _getStoryStatistics();
            final totalPoints = storyStats['totalPoints'] ?? 0;
            final sessionCount = storyStats['sessionCount'] ?? 0;
            final averageScore = storyStats['averageScore'] ?? 0.0;

            return Row(
              children: [
                Expanded(
                  child: _buildQuizCard(
                    context,
                    isDarkMode,
                    'Total Points',
                    Icons.stars,
                    Colors.purple,
                    '$totalPoints',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuizCard(
                    context,
                    isDarkMode,
                    'Sessions',
                    Icons.play_arrow,
                    Colors.orange,
                    '$sessionCount',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuizCard(
                    context,
                    isDarkMode,
                    'Avg Score',
                    Icons.trending_up,
                    Colors.green,
                    '${averageScore.toStringAsFixed(0)}',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStreakAnalyticsSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Streak Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _getStreakAnalytics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final analytics = snapshot.data ?? {};
            final overallPercentage = analytics['overallPercentage'] ?? 0.0;
            final challengePercentage = analytics['challengePercentage'] ?? 0.0;
            final reviewPercentage = analytics['reviewPercentage'] ?? 0.0;
            final performanceLevel = analytics['performanceLevel'] ?? 'Needs Improvement';
            final performanceColor = Color(analytics['performanceColor'] ?? 0xFFF44336);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2B2D42) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: performanceColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Overall Streak Performance',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${overallPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                              color: performanceColor,
                            ),
                          ),
                          Text(
                            performanceLevel,
                            style: TextStyle(
                              color: performanceColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: performanceColor.withOpacity(0.1),
                          border: Border.all(
                            color: performanceColor,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${overallPercentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: performanceColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStreakBreakdownCard(
                          context,
                          isDarkMode,
                          'Challenges',
                          challengePercentage,
                          Icons.emoji_events,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStreakBreakdownCard(
                          context,
                          isDarkMode,
                          'Reviews',
                          reviewPercentage,
                          Icons.quiz,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStreakBreakdownCard(
    BuildContext context,
    bool isDarkMode,
    String title,
    double percentage,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2235) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Achievements',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final achievements = _getAchievements();

            if (achievements.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2B2D42) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 48,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No achievements yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete lessons and quizzes to earn achievements!',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: achievements.map<Widget>((achievement) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2B2D42) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: achievement['color'].withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: achievement['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          achievement['icon'],
                          color: achievement['color'],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              achievement['title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              achievement['description'],
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        achievement['date'],
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    bool isDarkMode,
    String label,
    IconData icon,
    Color color,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2B2D42) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryCard(
    BuildContext context,
    bool isDarkMode,
    String label,
    IconData icon,
    Color color,
    String masteryPercentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2B2D42) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 12),
          Column(
                children: [
                  Text(
                masteryPercentage,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final progressDetails = _getCharacterProgressDetails(label.toLowerCase());
                  final completed = progressDetails['completed'] as int;
                  final total = progressDetails['total'] as int;
                  return Text(
                    '$completed of $total characters',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  );
                },
              ),
                  const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final progressDetails = _getCharacterProgressDetails(label.toLowerCase());
                  final percentageValue = progressDetails['percentage'] as double;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentageValue / 100,
                      backgroundColor: color.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
              );
            },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(
    BuildContext context,
    bool isDarkMode,
    String label,
    IconData icon,
    Color color,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2B2D42) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods to get statistics from Firebase
  Map<String, dynamic> _getOverallStatistics() {
    if (_userData == null || _userData!.isEmpty) {
      return {
        'level': 1,
        'totalXp': 0,
        'longestStreak': 0,
        'currentStreak': 0,
        'mojiPoints': 0,
        'mojiCoins': 0,
        'totalPoints': 0,
      };
    }
    
    try {
      return {
        'level': _userData!['level'] is int ? _userData!['level'] : 1,
        'totalXp': _userData!['totalXp'] is int ? _userData!['totalXp'] : 0,
        'longestStreak': _userData!['longestStreak'] is int ? _userData!['longestStreak'] : 0,
        'currentStreak': _userData!['currentStreak'] is int ? _userData!['currentStreak'] : 0,
        'mojiPoints': _userData!['mojiPoints'] is int ? _userData!['mojiPoints'] : 0,
        'mojiCoins': _userData!['mojiCoins'] is int ? _userData!['mojiCoins'] : 0,
        'totalPoints': _userData!['totalPoints'] is int ? _userData!['totalPoints'] : 0,
      };
    } catch (e) {
      print('Error parsing overall statistics: $e');
      return {
        'level': 1,
        'totalXp': 0,
        'longestStreak': 0,
        'currentStreak': 0,
        'mojiPoints': 0,
        'mojiCoins': 0,
        'totalPoints': 0,
      };
    }
  }

  String _getLongestStreak() {
    final stats = _getOverallStatistics();
      return '${stats['longestStreak'] ?? 0}';
  }

  Future<String> _getDailyGoalProgress() async {
    try {
      final progressService = ProgressService();
      await progressService.initialize();
      final dashboardProgress = await progressService.getDashboardProgress();
      
      final minutesStudied = dashboardProgress.minutesStudiedToday;
      final dailyGoal = dashboardProgress.dailyGoalMinutes;
      final progress = (minutesStudied / dailyGoal).clamp(0.0, 1.0);
      return '${(progress * 100).toStringAsFixed(0)}%';
    } catch (e) {
      return '0%';
    }
  }

  String _getTotalPoints() {
    final stats = _getOverallStatistics();
    return '${stats['mojiPoints'] ?? 0}';
  }

  Future<String> _getStreakPercentage() async {
    try {
      final streakService = StreakAnalyticsService();
      final stats = await streakService.getStreakStatistics();
      return stats['overallPercentageFormatted'] ?? '0.0%';
    } catch (e) {
      return '0.0%';
    }
  }

  String _getScriptCompletionFraction(String script) {
    if (_userData == null || _userData!.isEmpty) return '0%';
    
    try {
      final characterProgressData = _userData!['characterProgress'];
      if (characterProgressData == null || characterProgressData is! Map) {
        return '0%';
      }
      
      final characterProgress = Map<String, dynamic>.from(characterProgressData);
      int completedCharacters = 0;
      
      // Get the total number of characters available for this script
      final totalCharactersForScript = CharacterConstants.getTotalCharactersForScript(script);
      
      // Count completed characters for this script
      for (final entry in characterProgress.entries) {
        try {
          final progressData = entry.value;
          if (progressData is! Map) continue;
          
          final progress = Map<String, dynamic>.from(progressData);
          
          // Check if character belongs to the script
          final characterType = progress['characterType']?.toString() ?? '';
          if (characterType.toLowerCase() == script.toLowerCase()) {
            final masteryLevel = progress['masteryLevel'];
            final masteryValue = masteryLevel is int ? masteryLevel : 
                                masteryLevel is double ? masteryLevel.toInt() : 0;
            
            // Use the mastery threshold from constants
            if (masteryValue >= CharacterConstants.masteryThreshold) {
              completedCharacters++;
            }
          }
    } catch (e) {
          print('Error parsing character progress for ${entry.key}: $e');
          continue;
        }
      }
      
      // Calculate percentage based on actual total characters available
      if (totalCharactersForScript == 0) return '0%';
      
      final percentage = (completedCharacters / totalCharactersForScript * 100).clamp(0.0, 100.0);
      return '${percentage.toStringAsFixed(1)}%';
    } catch (e) {
      print('Error calculating script completion: $e');
      return '0%';
    }
  }

  // Get detailed character progress information
  Map<String, dynamic> _getCharacterProgressDetails(String script) {
    if (_userData == null || _userData!.isEmpty) {
      return {
        'completed': 0,
        'total': CharacterConstants.getTotalCharactersForScript(script),
        'percentage': 0.0,
        'characters': <String>[],
      };
    }
    
    try {
      final characterProgressData = _userData!['characterProgress'];
      if (characterProgressData == null || characterProgressData is! Map) {
        return {
          'completed': 0,
          'total': CharacterConstants.getTotalCharactersForScript(script),
          'percentage': 0.0,
          'characters': <String>[],
        };
      }
      
      final characterProgress = Map<String, dynamic>.from(characterProgressData);
      int completedCharacters = 0;
      final completedCharacterList = <String>[];
      final totalCharactersForScript = CharacterConstants.getTotalCharactersForScript(script);
      
      for (final entry in characterProgress.entries) {
        try {
          final progressData = entry.value;
          if (progressData is! Map) continue;
          
          final progress = Map<String, dynamic>.from(progressData);
          final characterType = progress['characterType']?.toString() ?? '';
          
          if (characterType.toLowerCase() == script.toLowerCase()) {
            final masteryLevel = progress['masteryLevel'];
            final masteryValue = masteryLevel is int ? masteryLevel : 
                                masteryLevel is double ? masteryLevel.toInt() : 0;
            
            if (masteryValue >= CharacterConstants.masteryThreshold) {
              completedCharacters++;
              completedCharacterList.add(entry.key);
            }
          }
    } catch (e) {
          print('Error parsing character progress for ${entry.key}: $e');
          continue;
        }
      }
      
      final percentage = totalCharactersForScript > 0 
          ? (completedCharacters / totalCharactersForScript * 100).clamp(0.0, 100.0)
          : 0.0;
      
      return {
        'completed': completedCharacters,
        'total': totalCharactersForScript,
        'percentage': percentage,
        'characters': completedCharacterList,
      };
    } catch (e) {
      print('Error getting character progress details: $e');
      return {
        'completed': 0,
        'total': CharacterConstants.getTotalCharactersForScript(script),
        'percentage': 0.0,
        'characters': <String>[],
      };
    }
  }

  // Get story mode statistics from Firebase and SharedPreferences
  Map<String, dynamic> _getStoryStatistics() {
    if (_userData == null || _userData!.isEmpty) {
      return {
        'totalPoints': 0,
        'sessionCount': 0,
        'averageScore': 0.0,
      };
    }

    try {
      // Get story points from SharedPreferences
      int totalStoryPoints = 0;
      int sessionCount = 0;
      double totalScore = 0.0;
      
      // Try to get from SharedPreferences first
      SharedPreferences.getInstance().then((prefs) {
        totalStoryPoints = prefs.getInt('story_total_points') ?? 0;
        
        // Count story sessions
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('story_session_')) {
            sessionCount++;
            try {
              final sessionData = prefs.getString(key);
              if (sessionData != null) {
                // Parse session data to get score
                final scoreMatch = RegExp(r"'score':\s*(\d+)").firstMatch(sessionData);
                if (scoreMatch != null) {
                  totalScore += int.parse(scoreMatch.group(1)!);
                }
              }
            } catch (e) {
              print('Error parsing story session $key: $e');
            }
          }
        }
      });
      
      // Also check Firebase story progress
      final storyProgressData = _userData!['storyProgress'];
      if (storyProgressData != null && storyProgressData is Map) {
        final storyProgress = Map<String, dynamic>.from(storyProgressData);
        
        for (final entry in storyProgress.entries) {
          try {
            final storyData = entry.value;
            if (storyData is! Map) continue;
            
            final story = Map<String, dynamic>.from(storyData);
            final points = story['totalPoints'];
            if (points is int) {
              totalStoryPoints += points;
            } else if (points is double) {
              totalStoryPoints += points.toInt();
            }
            
            sessionCount++;
          } catch (e) {
            print('Error parsing story data for ${entry.key}: $e');
            continue;
          }
        }
      }

      return {
        'totalPoints': totalStoryPoints,
        'sessionCount': sessionCount,
        'averageScore': sessionCount > 0 ? totalScore / sessionCount : 0.0,
      };
    } catch (e) {
      print('Error parsing story statistics: $e');
      return {
        'totalPoints': 0,
        'sessionCount': 0,
        'averageScore': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> _getStreakAnalytics() async {
    try {
      final streakService = StreakAnalyticsService();
      final stats = await streakService.getStreakStatistics();
      
      final overallPercentage = stats['overallPercentage'] ?? 0.0;
      final challengePercentage = stats['challengePercentage'] ?? 0.0;
      final reviewPercentage = stats['reviewPercentage'] ?? 0.0;
      
      return {
        'overallPercentage': overallPercentage,
        'challengePercentage': challengePercentage,
        'reviewPercentage': reviewPercentage,
        'performanceLevel': overallPercentage >= 80 ? 'Excellent' : 
                           overallPercentage >= 60 ? 'Good' : 
                           overallPercentage >= 40 ? 'Fair' : 'Needs Improvement',
        'performanceColor': overallPercentage >= 80 ? 0xFF4CAF50 : 
                           overallPercentage >= 60 ? 0xFF2196F3 : 
                           overallPercentage >= 40 ? 0xFFFF9800 : 0xFFF44336,
      };
    } catch (e) {
      print('Error getting streak analytics: $e');
      return {
        'overallPercentage': 0.0,
        'challengePercentage': 0.0,
        'reviewPercentage': 0.0,
        'performanceLevel': 'Needs Improvement',
        'performanceColor': 0xFFF44336,
      };
    }
  }

  // Deprecated helpers removed in favor of script completion fraction methods

  Map<String, dynamic> _getQuizStatistics() {
    if (_userData == null || _userData!.isEmpty) {
      return {
        'totalQuizzes': 0,
        'averageScore': 0.0,
        'perfectScores': 0,
        'passedQuizzes': 0,
      };
    }

    try {
      int totalQuizzes = 0;
      double totalScore = 0.0;
      int perfectScores = 0;
      int passedQuizzes = 0;
      
      // Check Firebase quiz results first
      final quizResultsData = _userData!['quizResults'];
      if (quizResultsData != null && quizResultsData is List) {
        final quizResults = List<dynamic>.from(quizResultsData);

        for (final result in quizResults) {
          try {
            if (result is! Map) continue;
            
            final quizData = Map<String, dynamic>.from(result);
            final scoreData = quizData['score'];
            final totalQuestionsData = quizData['totalQuestions'];
            
            final score = scoreData is int ? scoreData : 
                         scoreData is double ? scoreData.toInt() : 0;
            final totalQuestions = totalQuestionsData is int ? totalQuestionsData : 
                                  totalQuestionsData is double ? totalQuestionsData.toInt() : 1;
            
            final percentage = totalQuestions > 0 ? (score / totalQuestions * 100).clamp(0.0, 100.0) : 0.0;
            
            totalQuizzes++;
            totalScore += percentage;
            
            if (percentage >= 70) { // Assuming 70% is passing
              passedQuizzes++;
            }

            if (percentage == 100.0) {
              perfectScores++;
            }
          } catch (e) {
            print('Error parsing quiz result: $e');
            continue;
          }
        }
      }
      
      // Also check SharedPreferences for additional quiz data
      SharedPreferences.getInstance().then((prefs) {
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('quiz_result_')) {
            try {
              final resultData = prefs.getString(key);
              if (resultData != null) {
                final result = jsonDecode(resultData);
                final percentage = result['percentage'] ?? 0.0;
                
                totalQuizzes++;
                totalScore += percentage;
                
                if (percentage >= 70) {
                  passedQuizzes++;
                }
                
                if (percentage == 100.0) {
                  perfectScores++;
                }
              }
            } catch (e) {
              print('Error parsing SharedPreferences quiz result $key: $e');
            }
          }
        }
      });

      final averageScore = totalQuizzes > 0 ? totalScore / totalQuizzes : 0.0;

      return {
        'totalQuizzes': totalQuizzes,
        'averageScore': averageScore,
        'perfectScores': perfectScores,
        'passedQuizzes': passedQuizzes,
      };
    } catch (e) {
      print('Error parsing quiz statistics: $e');
      return {
        'totalQuizzes': 0,
        'averageScore': 0.0,
        'perfectScores': 0,
        'passedQuizzes': 0,
      };
    }
  }

  List<Map<String, dynamic>> _getAchievements() {
    if (_userData == null || _userData!.isEmpty) return [];
    
    try {
      final achievements = <Map<String, dynamic>>[];
      
      final levelData = _userData!['level'];
      final totalXpData = _userData!['totalXp'];
      final longestStreakData = _userData!['longestStreak'];
      
      final level = levelData is int ? levelData : 
                   levelData is double ? levelData.toInt() : 1;
      final totalXp = totalXpData is int ? totalXpData : 
                     totalXpData is double ? totalXpData.toInt() : 0;
      final longestStreak = longestStreakData is int ? longestStreakData : 
                           longestStreakData is double ? longestStreakData.toInt() : 0;

      // Level achievements
      if (level >= 2) {
        achievements.add({
          'title': 'Level 2 Reached!',
          'description': 'You\'ve reached level 2 - Getting Started!',
          'icon': Icons.star,
          'color': Colors.blue,
          'date': 'Today',
        });
      }

      if (level >= 5) {
        achievements.add({
          'title': 'Level 5 Reached!',
          'description': 'You\'ve reached level 5 - Making Progress!',
          'icon': Icons.emoji_events,
          'color': Colors.amber,
          'date': 'Today',
        });
      }

      if (level >= 10) {
        achievements.add({
          'title': 'Level 10 Reached!',
          'description': 'You\'ve reached level 10 - Dedicated Learner!',
          'icon': Icons.workspace_premium,
          'color': Colors.purple,
          'date': 'Today',
        });
      }

      // XP achievements
      if (totalXp >= 1000) {
        achievements.add({
          'title': '1000 XP Milestone!',
          'description': 'You\'ve earned 1000 XP - Great progress!',
          'icon': Icons.trending_up,
          'color': Colors.green,
          'date': 'Today',
        });
      }

      if (totalXp >= 5000) {
        achievements.add({
          'title': '5000 XP Milestone!',
          'description': 'You\'ve earned 5000 XP - Excellent work!',
          'icon': Icons.emoji_events,
          'color': Colors.orange,
          'date': 'Today',
        });
      }

      // Streak achievements
      if (longestStreak >= 7) {
        achievements.add({
          'title': 'Week Streak!',
          'description': 'You\'ve maintained a 7-day streak!',
          'icon': Icons.local_fire_department,
          'color': Colors.red,
          'date': 'Today',
        });
      }

      if (longestStreak >= 30) {
        achievements.add({
          'title': 'Month Streak!',
          'description': 'You\'ve maintained a 30-day streak!',
          'icon': Icons.whatshot,
          'color': Colors.deepOrange,
          'date': 'Today',
        });
      }

      return achievements;
    } catch (e) {
      print('Error parsing achievements: $e');
      return [];
    }
  }
}
