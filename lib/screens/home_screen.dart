import 'dart:io';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nihongo_japanese_app/models/challenge_topic.dart';
import 'package:nihongo_japanese_app/models/user_model.dart' as UserModel;
import 'package:nihongo_japanese_app/screens/challenge_screen.dart';
import 'package:nihongo_japanese_app/screens/challenge_topic_screen.dart' hide ChallengeTopic;
import 'package:nihongo_japanese_app/screens/difficulty_selection_screen.dart';
import 'package:nihongo_japanese_app/screens/lessons_screen.dart';
import 'package:nihongo_japanese_app/screens/practice_writing_screen.dart';
import 'package:nihongo_japanese_app/screens/profile_screen.dart';
import 'package:nihongo_japanese_app/screens/review_screen.dart';
import 'package:nihongo_japanese_app/screens/shop_screen.dart';
import 'package:nihongo_japanese_app/screens/user_stats_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/coin_service.dart';
import 'package:nihongo_japanese_app/services/daily_points_service.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/profile_image_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:nihongo_japanese_app/services/review_progress_service.dart';
import 'package:nihongo_japanese_app/services/streak_analytics_service.dart';
import 'package:nihongo_japanese_app/services/system_config_service.dart';
import 'package:nihongo_japanese_app/utils/character_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const HomeScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedQuickAccessIndex = -1;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final ProfileImageService _profileImageService = ProfileImageService();
  final AuthService _authService = AuthService();
  final SystemConfigService _systemConfig = SystemConfigService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Ensure user data is synced when the screen loads
    _syncUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method to sync user data from Firebase to SharedPreferences
  Future<void> _syncUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final snapshot = await FirebaseDatabase.instance.ref().child('users/${user.uid}').get();

        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;
          final prefs = await SharedPreferences.getInstance();

          // Update SharedPreferences with latest data from Firebase
          await prefs.setString('first_name', userData['firstName'] ?? '');
          await prefs.setString('last_name', userData['lastName'] ?? '');
          await prefs.setString('gender', userData['gender'] ?? '');
          await prefs.setBool('has_completed_profile', true);

          // Refresh the UI to show updated name
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing user data: $e');
    }
  }

  Future<void> _refreshData() async {
    await _syncUserData(); // Sync user data on refresh
    setState(() {});
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          key: _refreshKey,
          onRefresh: _refreshData,
          color: primaryColor,
          backgroundColor: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isDarkMode, primaryColor),
                _buildSystemAnnouncementBanner(),
                const SizedBox(height: 24),
                // Your Progress Summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Your Progress',
                        Icons.insights_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserStatsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildProgressSummaryCard(context, isDarkMode, primaryColor),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
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
                          _refreshKey.currentState?.show();
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildRecentActivity(context, isDarkMode, primaryColor),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildShopCard(context, isDarkMode),
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
              AnimatedBuilder(
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
                      'MyGana',
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
                    ),
                  );
                },
              ),
              Row(
                children: [
                  FutureBuilder<int>(
                    future: Future.wait([
                      // Challenge points from ChallengeProgressService
                      ChallengeProgressService().getTotalPoints(),
                      // Review points from ReviewProgressService
                      ReviewProgressService().getTotalReviewPoints(),
                      // Story points from SharedPreferences (if any)
                      SharedPreferences.getInstance()
                          .then((prefs) => prefs.getInt('story_total_points') ?? 0),
                      // Quiz points from SharedPreferences (if any)
                      SharedPreferences.getInstance()
                          .then((prefs) => prefs.getInt('quiz_total_points') ?? 0),
                      // Daily points from DailyPointsService
                      DailyPointsService().getLastClaimTime().then((lastClaim) async {
                        if (lastClaim == null) return 0;
                        final multiplier = await DailyPointsService().getStreakBonusMultiplier();
                        return (100 * multiplier).round();
                      }),
                    ]).then((results) => results.fold<int>(0, (sum, points) => sum + points)),
                    builder: (context, snapshot) {
                      return Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${snapshot.data ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FutureBuilder<int>(
                    future: CoinService().getCoins(),
                    builder: (context, snapshot) {
                      return Row(
                        children: [
                          Image.asset(
                            'assets/images/coin.png',
                            width: 16,
                            height: 16,
                            color: Colors.amber,
                            colorBlendMode: BlendMode.modulate,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${snapshot.data ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildProfileButton(context),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildWelcomeMessage(context),
        ],
      ),
    );
  }

  Widget _buildSystemAnnouncementBanner() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _systemConfig.watchSystemConfig(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final config = snapshot.data!;
        final announcement = config['systemAnnouncement'] as String? ?? '';

        if (announcement.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.announcement,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  announcement,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return FutureBuilder<String?>(
      future: _profileImageService.getProfileImage(),
      builder: (context, snapshot) {
        return FutureBuilder<bool>(
          future: _profileImageService.isCustomImage(),
          builder: (context, isCustomSnapshot) {
            Widget profileImage;
            if (snapshot.hasData && snapshot.data != null) {
              if (isCustomSnapshot.data == true) {
                profileImage = Image.file(
                  File(snapshot.data!),
                  fit: BoxFit.cover,
                  width: 44,
                  height: 44,
                );
              } else {
                profileImage = Image.asset(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  width: 44,
                  height: 44,
                );
              }
            } else {
              profileImage = const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 24,
              );
            }

            return Hero(
              tag: 'profile-icon',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ProfileScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          var begin = const Offset(1.0, 0.0);
                          var end = Offset.zero;
                          var curve = Curves.easeInOutCubic;
                          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
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
                      child: profileImage,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeMessage(BuildContext context) {
    return FutureBuilder<UserModel.User>(
      future: _getUserData(),
      builder: (context, snapshot) {
        String userName = 'there';

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final firstName = user.firstName.trim();
          final lastName = user.lastName.trim();

          // Build the name properly, handling empty values
          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            userName = '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            userName = firstName;
          } else if (lastName.isNotEmpty) {
            userName = lastName;
          }

          // Fallback to email if no name is available
          if (userName == 'there') {
            final currentUser = _authService.currentUser;
            if (currentUser?.email != null) {
              final emailName = currentUser!.email!.split('@')[0];
              userName = emailName.replaceAll('.', ' ').replaceAll('_', ' ');
              // Capitalize first letter of each word
              userName = userName
                  .split(' ')
                  .map((word) => word.isNotEmpty
                      ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                      : word)
                  .join(' ');
            }
          }
        }

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
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hello, $userName!',
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
      },
    );
  }

  Future<UserModel.User> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('first_name') ?? '';
    final lastName = prefs.getString('last_name') ?? '';
    final gender = prefs.getString('gender') ?? '';
    final isProfileComplete = prefs.getBool('has_completed_profile') ?? false;

    return UserModel.User(
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      isProfileComplete: isProfileComplete,
    );
  }

  // Rest of the methods remain the same...
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon,
      {VoidCallback? onTap}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).primaryColor,
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
              foregroundColor: Theme.of(context).primaryColor,
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

  Widget _buildQuickAccessGrid(BuildContext context, bool isDarkMode) {
    final List<Map<String, dynamic>> quickAccessItems = [
      {
        'title': 'Lessons',
        'subtitle': 'Structured learning',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF4CAF50),
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LessonsScreen(),
            ),
          );
        },
      },
      {
        'title': 'Challenges',
        'subtitle': 'Test your skills',
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFF8E54E9),
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChallengeTopicScreen(),
            ),
          );
        },
      },
      {
        'title': 'Kanji & Kana',
        'subtitle': 'Practice writing',
        'icon': Icons.edit_rounded,
        'color': const Color(0xFF4776E6),
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PracticeWritingScreen(),
            ),
          );
        },
      },
      {
        'title': 'Stories',
        'subtitle': 'Learn with context',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF26A69A),
        'onTap': () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DifficultySelectionScreen(),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDarkMode ? const Color(0xFF2A2D3E) : Colors.white,
                      isDarkMode ? const Color(0xFF232635) : Colors.white,
                    ],
                  ),
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
                  border: Border.all(
                    color: isSelected
                        ? color.withOpacity(0.3)
                        : (isDarkMode
                            ? Colors.grey.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.05)),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      color,
                                      Color.lerp(color, Colors.white, 0.3) ?? color,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              if (title == 'Practice')
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDarkMode ? const Color(0xFF2A2D3E) : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Text(
                                      '3',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
                                        color: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: color.withOpacity(0.7),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDarkMode, Color primaryColor) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([
        ChallengeProgressService().getRecentActivity().then((value) =>
            // ignore: unnecessary_null_comparison
            value == null ? null : {...value, 'type': 'challenge'}),
        ReviewProgressService().getAllRecentActivities().then(
            (activities) => activities.map((activity) => {...activity, 'type': 'review'}).toList()),
      ]).then((results) {
        List<Map<String, dynamic>> allActivities = [];
        if (results[0] != null) {
          allActivities.add(results[0] as Map<String, dynamic>);
        }
        allActivities.addAll((results[1] as List).cast<Map<String, dynamic>>());
        return allActivities;
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyRecentActivity(isDarkMode);
        }

        final activities = snapshot.data!;
        activities.sort((a, b) {
          final aTimestamp = a['timestamp'] as int? ?? 0;
          final bTimestamp = b['timestamp'] as int? ?? 0;
          return bTimestamp.compareTo(aTimestamp);
        });

        final recentActivities = activities.take(2).toList();

        for (var activity in recentActivities) {
          print('Activity: ${activity['type']} - CategoryID: ${activity['categoryId']}');
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseService().getFlashcardCategories(),
          builder: (context, categoriesSnapshot) {
            if (categoriesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!categoriesSnapshot.hasData) {
              return _buildEmptyRecentActivity(isDarkMode);
            }

            final allCategories = categoriesSnapshot.data!;
            print(
                'Available categories: ${allCategories.map((c) => '${c['id']}: ${c['name']}').join(', ')}');

            return Column(
              children: recentActivities.map((activity) {
                if (activity['type'] == 'challenge') {
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseService().getChallengeTopics(),
                    builder: (context, topicsSnapshot) {
                      if (topicsSnapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (!topicsSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final topics = topicsSnapshot.data!;
                      final topic = topics.firstWhere(
                        (t) => t['id'] == activity['topicId'],
                        orElse: () => topics.first,
                      );

                      final challengeTopic = ChallengeTopic.fromMap(topic);
                      final timestamp =
                          DateTime.fromMillisecondsSinceEpoch(activity['timestamp'] ?? 0);
                      final timeAgo = _getTimeAgo(timestamp);
                      final completedChallenges = activity['completedChallenges'] as int? ?? 0;
                      final totalChallenges = activity['totalChallenges'] as int? ?? 1;
                      final progress = completedChallenges / totalChallenges;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildRecentActivityCard(
                          context,
                          isDarkMode,
                          title: challengeTopic.title,
                          description: challengeTopic.description,
                          icon: challengeTopic.icon,
                          color: challengeTopic.color,
                          timeAgo: timeAgo,
                          progress: progress,
                          progressText: '$completedChallenges/$totalChallenges completed',
                          isCompleted: activity['isCompleted'] as bool? ?? false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeScreen(
                                  topicId: challengeTopic.id,
                                  initialChallengeId: '${challengeTopic.id}-1',
                                  topicColor: challengeTopic.color,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                } else {
                  final categoryId = activity['categoryId'] as String? ?? '';
                  print('Looking for category ID: $categoryId');
                  final category = allCategories.firstWhere(
                    (c) => c['id'].toString() == categoryId.toString(),
                    orElse: () {
                      print('Category not found for ID: $categoryId');
                      return allCategories.isNotEmpty
                          ? allCategories.first
                          : {
                              'id': 'unknown',
                              'name': 'Unknown Category',
                              'description': 'Category not found',
                              'icon': 'default',
                              'color': '#808080',
                            };
                    },
                  );

                  print('Found category: ${category['name']} for ID: $categoryId');

                  final correctCount = activity['correctCount'] as int? ?? 0;
                  final totalCards = activity['totalCards'] as int? ?? 1;
                  final accuracy = correctCount / totalCards * 100;
                  final isQuizMode = activity['isQuizMode'] as bool? ?? false;
                  final timestamp = DateTime.fromMillisecondsSinceEpoch(activity['timestamp'] ?? 0);
                  final timeAgo = _getTimeAgo(timestamp);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildRecentActivityCard(
                      context,
                      isDarkMode,
                      title: category['name'],
                      description: category['description'],
                      icon: _getIconFromName(category['icon']),
                      color: Color(
                          int.parse(category['color'].substring(1, 7), radix: 16) + 0xFF000000),
                      timeAgo: timeAgo,
                      progress: accuracy / 100,
                      progressText: '${accuracy.toStringAsFixed(1)}% accuracy',
                      isCompleted: true,
                      statusText: isQuizMode ? 'Quiz Completed' : 'Review Completed',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReviewScreen(),
                            settings: RouteSettings(
                              arguments: {
                                'categoryId': categoryId,
                                'isQuizMode': isQuizMode,
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              }).toList(),
            );
          },
        );
      },
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final timeDifference = DateTime.now().difference(timestamp);
    if (timeDifference.inMinutes < 60) {
      return '${timeDifference.inMinutes}m ago';
    } else if (timeDifference.inHours < 24) {
      return '${timeDifference.inHours}h ago';
    } else {
      return '${timeDifference.inDays}d ago';
    }
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'greetings':
        return Icons.waving_hand;
      case 'basic_nouns':
        return Icons.category;
      case 'basic_verbs':
        return Icons.run_circle;
      case 'basic_adjectives':
        return Icons.color_lens;
      case 'time_expressions':
        return Icons.access_time;
      default:
        return Icons.category;
    }
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
    required bool isCompleted,
    String? statusText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: color,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          progressText,
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                                color: color,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText ?? (isCompleted ? 'Completed' : 'Continue'),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
    );
  }

  Widget _buildEmptyRecentActivity(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a challenge to see your activity here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(BuildContext context, bool isDarkMode) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF2A2D3E), const Color(0xFF232635)]
              : [primaryColor.withOpacity(0.9), primaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ShopScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Visit the Shop',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Browse boosters, power-ups, and more!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Explore Shop',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2B2D42) : Colors.white,
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserStatsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with level and XP
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, Color.lerp(primaryColor, Colors.purple, 0.3)!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<Map<String, dynamic>>(
                            future: _getOverallStatistics(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }

                              final stats = snapshot.data ?? {};
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalXp XP',
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progressToNextLevel.clamp(0.0, 1.0),
                                      backgroundColor: primaryColor.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(nextLevelXp - totalXp)} XP to next level',
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Quick Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStatItem(
                        context,
                        isDarkMode,
                        'Streak %',
                        Icons.trending_up,
                        Colors.purple,
                        () => _getStreakPercentage(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildQuickStatItem(
                        context,
                        isDarkMode,
                        'Daily Goal',
                        Icons.timer,
                        Colors.blue,
                        () => _getDailyGoalProgress(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildQuickStatItem(
                        context,
                        isDarkMode,
                        'Mastery',
                        Icons.abc,
                        Colors.green,
                        () => _getOverallMastery(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // View Details Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Detailed Statistics',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: primaryColor,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(
    BuildContext context,
    bool isDarkMode,
    String label,
    IconData icon,
    Color color,
    Future<String> Function() valueFuture,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2235) : Colors.grey[50],
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
          FutureBuilder<String>(
            future: valueFuture(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? '0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods to get statistics
  Future<Map<String, dynamic>> _getOverallStatistics() async {
    try {
      final progressService = ProgressService();
      await progressService.initialize();

      final userProgress = progressService.getUserProgress();
      final dashboardProgress = await progressService.getDashboardProgress();

      return {
        'level': userProgress.level,
        'totalXp': userProgress.totalXp,
        'longestStreak': userProgress.longestStreak,
        'dailyGoalMinutes': dashboardProgress.dailyGoalMinutes,
        'minutesStudiedToday': dashboardProgress.minutesStudiedToday,
        'totalLessonsCompleted': dashboardProgress.totalLessonsCompleted,
        'totalLessons': dashboardProgress.totalLessons,
      };
    } catch (e) {
      print('Error getting overall statistics: $e');
      return {};
    }
  }

  Future<String> _getDailyGoalProgress() async {
    try {
      final stats = await _getOverallStatistics();
      final minutesStudied = stats['minutesStudiedToday'] ?? 0;
      final dailyGoal = stats['dailyGoalMinutes'] ?? 15;
      final progress = (minutesStudied / dailyGoal).clamp(0.0, 1.0);
      return '${(progress * 100).toStringAsFixed(0)}%';
    } catch (e) {
      return '0%';
    }
  }

  Future<String> _getOverallMastery() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return '0%';

      final firebaseSync = FirebaseUserSyncService();
      final userData = await firebaseSync.getRealtimeUserData();

      if (userData == null || userData.isEmpty) return '0%';

      final characterProgressData = userData['characterProgress'];
      if (characterProgressData == null || characterProgressData is! Map) {
        return '0%';
      }

      final characterProgress = Map<String, dynamic>.from(characterProgressData);
      int completedCharacters = 0;
      int totalCharacters = 0;

      // Count all characters (Hiragana + Katakana + Kanji)
      totalCharacters = CharacterConstants.totalCharacters;

      for (final entry in characterProgress.entries) {
        try {
          final progressData = entry.value;
          if (progressData is! Map) continue;

          final progress = Map<String, dynamic>.from(progressData);
          final masteryLevel = progress['masteryLevel'];
          final masteryValue = masteryLevel is int
              ? masteryLevel
              : masteryLevel is double
                  ? masteryLevel.toInt()
                  : 0;

          if (masteryValue >= CharacterConstants.masteryThreshold) {
            completedCharacters++;
          }
        } catch (e) {
          print('Error parsing character progress for ${entry.key}: $e');
          continue;
        }
      }

      if (totalCharacters == 0) return '0%';
      final percentage = (completedCharacters / totalCharacters * 100).clamp(0.0, 100.0);
      return '${percentage.toStringAsFixed(1)}%';
    } catch (e) {
      print('Error getting overall mastery: $e');
      return '0%';
    }
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
}
