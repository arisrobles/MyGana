import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nihongo_japanese_app/models/leaderboard_model.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardService {
  static const String _leaderboardKey = 'class_leaderboard';
  static const Duration _cacheExpiry = Duration(minutes: 5);

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProgressService _progressService = ProgressService();
  final FirebaseUserSyncService _firebaseSync = FirebaseUserSyncService();

  List<Map<String, dynamic>>? _cachedLeaderboardData;
  DateTime? _lastLeaderboardSync;

  // Get current user ID from Firebase Auth
  String? get _getCurrentUserId {
    return _auth.currentUser?.uid;
  }

  // Get leaderboard data
  Future<LeaderboardData> getLeaderboard() async {
    try {
      print('LeaderboardService: Getting leaderboard data...');
      // Try to get real data from Firebase first
      final firebaseData = await _getFirebaseLeaderboardData();
      if (firebaseData != null) {
        print(
            'LeaderboardService: Firebase data found, returning ${firebaseData.entries.length} entries');
        return firebaseData;
      }

      // Fallback to cached data
      final prefs = await SharedPreferences.getInstance();
      final leaderboardJson = prefs.getString(_leaderboardKey);

      if (leaderboardJson != null) {
        final data = LeaderboardData.fromJson(jsonDecode(leaderboardJson));

        // Check if data is recent (within last 5 minutes)
        final now = DateTime.now();
        if (now.difference(data.lastUpdated).inMinutes < 5) {
          return data;
        }
      }

      // Generate fresh leaderboard data (mock data)
      return await _generateLeaderboardData();
    } catch (e) {
      print('Error getting leaderboard: $e');
      return await _generateLeaderboardData();
    }
  }

  // Get leaderboard data from Firebase excluding admin users
  Future<LeaderboardData?> _getFirebaseLeaderboardData() async {
    try {
      // Check cache first
      if (_cachedLeaderboardData != null &&
          _lastLeaderboardSync != null &&
          DateTime.now().difference(_lastLeaderboardSync!).compareTo(_cacheExpiry) < 0) {
        print('Returning cached leaderboard data');
        return await _buildLeaderboardDataFromFirebase(_cachedLeaderboardData!);
      }

      // Get Firebase leaderboard data excluding admins
      final firebaseData = await _firebaseSync.getLeaderboardDataExcludingAdmins();
      if (firebaseData.isEmpty) return null;

      // Update cache
      _cachedLeaderboardData = firebaseData;
      _lastLeaderboardSync = DateTime.now();

      return await _buildLeaderboardDataFromFirebase(firebaseData);
    } catch (e) {
      print('Error fetching Firebase leaderboard data: $e');
      return null;
    }
  }

  // Build LeaderboardData from Firebase data
  Future<LeaderboardData?> _buildLeaderboardDataFromFirebase(
      List<Map<String, dynamic>> firebaseData) async {
    try {
      final currentUserId = _getCurrentUserId;

      // Initialize progress service if needed
      await _progressService.initialize();
      final currentUserProgress = _progressService.getUserProgress();

      // Convert Firebase data to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];
      for (int i = 0; i < firebaseData.length; i++) {
        final user = firebaseData[i];
        final rank = i + 1;
        final level = user['level'] as int? ?? 1;
        final totalXp = user['totalXp'] as int? ?? 0;
        final userId = user['userId'] as String? ?? '';
        final displayName = user['displayName'] as String? ?? 'Anonymous';
        final currentStreak = user['currentStreak'] as int? ?? 0;
        final lastActiveTimestamp = user['lastActive'] as int?;

        DateTime lastActive;
        if (lastActiveTimestamp != null) {
          lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveTimestamp);
        } else {
          lastActive = DateTime.now().subtract(const Duration(hours: 1));
        }

        entries.add(LeaderboardEntry(
          userId: userId,
          username: displayName,
          avatarUrl: user['photoURL'] as String? ?? '',
          level: level,
          totalXp: totalXp,
          rank: rank,
          rankBadge: LeaderboardEntry.calculateRankBadge(level),
          lastActive: lastActive,
          streak: currentStreak,
          recentAchievements: _getUserAchievements(level),
          isCurrentUser: userId == currentUserId,
        ));
      }

      // Find current user entry
      LeaderboardEntry? currentUserEntry;
      if (currentUserId != null) {
        try {
          currentUserEntry = entries.firstWhere((entry) => entry.isCurrentUser);
        } catch (e) {
          // Current user not found in leaderboard, create a placeholder
          currentUserEntry = LeaderboardEntry(
            userId: currentUserId,
            username: _auth.currentUser?.displayName ?? 'You',
            avatarUrl: _auth.currentUser?.photoURL ?? '',
            level: currentUserProgress.level,
            totalXp: currentUserProgress.totalXp,
            rank: entries.length + 1, // Place at end if not in top list
            rankBadge: LeaderboardEntry.calculateRankBadge(currentUserProgress.level),
            lastActive: DateTime.now(),
            streak: currentUserProgress.currentStreak,
            recentAchievements: _getUserAchievements(currentUserProgress.level),
            isCurrentUser: true,
          );
        }
      }

      final leaderboardData = LeaderboardData(
        entries: entries,
        currentUserEntry: currentUserEntry,
        totalUsers: entries.length,
        lastUpdated: DateTime.now(),
      );

      // Save to local storage for offline access
      _saveLeaderboardData(leaderboardData);

      return leaderboardData;
    } catch (e) {
      print('Error building leaderboard data from Firebase: $e');
      return null;
    }
  }

  // Generate mock leaderboard data (fallback when Firebase is unavailable)
  Future<LeaderboardData> _generateLeaderboardData() async {
    final currentUserId = _getCurrentUserId;

    // Initialize progress service if needed
    await _progressService.initialize();
    final currentUserProgress = _progressService.getUserProgress();

    // Mock data for demonstration
    final mockUsers = [
      {
        'userId': 'user_1',
        'username': 'SakuraMaster',
        'avatarUrl': '',
        'level': 25,
        'totalXp': 24000,
        'streak': 15,
        'recentAchievements': ['Level 25 Reached!', 'Week Warrior'],
        'lastActive': DateTime.now().subtract(const Duration(minutes: 5)),
      },
      {
        'userId': 'user_2',
        'username': 'HiraganaHero',
        'avatarUrl': '',
        'level': 22,
        'totalXp': 21000,
        'streak': 12,
        'recentAchievements': ['Level 20 Reached!', 'Hiragana Master'],
        'lastActive': DateTime.now().subtract(const Duration(minutes: 15)),
      },
      {
        'userId': 'user_3',
        'username': 'KatakanaKing',
        'avatarUrl': '',
        'level': 18,
        'totalXp': 17000,
        'streak': 8,
        'recentAchievements': ['Level 15 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 1)),
      },
      {
        'userId': 'user_4',
        'username': 'KanjiKnight',
        'avatarUrl': '',
        'level': 15,
        'totalXp': 14000,
        'streak': 6,
        'recentAchievements': ['Level 15 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'userId': 'user_5',
        'username': 'StudySensei',
        'avatarUrl': '',
        'level': 12,
        'totalXp': 11000,
        'streak': 4,
        'recentAchievements': ['Level 10 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 3)),
      },
      {
        'userId': 'user_6',
        'username': 'NihongoNinja',
        'avatarUrl': '',
        'level': 10,
        'totalXp': 9000,
        'streak': 3,
        'recentAchievements': ['Level 10 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 4)),
      },
      {
        'userId': 'user_7',
        'username': 'LanguageLover',
        'avatarUrl': '',
        'level': 8,
        'totalXp': 7000,
        'streak': 2,
        'recentAchievements': ['Level 5 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 5)),
      },
      {
        'userId': 'user_8',
        'username': 'JapaneseJedi',
        'avatarUrl': '',
        'level': 6,
        'totalXp': 5000,
        'streak': 1,
        'recentAchievements': ['Level 5 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 6)),
      },
      {
        'userId': 'user_9',
        'username': 'AnimeAce',
        'avatarUrl': '',
        'level': 4,
        'totalXp': 3000,
        'streak': 1,
        'recentAchievements': ['Level 2 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 7)),
      },
      {
        'userId': 'user_10',
        'username': 'MangaMaster',
        'avatarUrl': '',
        'level': 3,
        'totalXp': 2000,
        'streak': 0,
        'recentAchievements': ['Level 2 Reached!'],
        'lastActive': DateTime.now().subtract(const Duration(hours: 8)),
      },
    ];

    // Add current user to the list if authenticated
    final allUsers = List<Map<String, dynamic>>.from(mockUsers);
    if (currentUserId != null) {
      final currentUserData = {
        'userId': currentUserId,
        'username': _auth.currentUser?.displayName ?? 'You',
        'avatarUrl': _auth.currentUser?.photoURL ?? '',
        'level': currentUserProgress.level,
        'totalXp': currentUserProgress.totalXp,
        'streak': currentUserProgress.currentStreak,
        'recentAchievements': _getUserAchievements(currentUserProgress.level),
        'lastActive': DateTime.now(),
      };
      allUsers.add(currentUserData);
    }

    // Sort by total XP (descending)
    allUsers.sort((a, b) => (b['totalXp'] as int).compareTo(a['totalXp'] as int));

    // Create leaderboard entries with ranks
    final entries = <LeaderboardEntry>[];
    for (int i = 0; i < allUsers.length; i++) {
      final user = allUsers[i];
      final rank = i + 1;
      final level = user['level'] as int;

      entries.add(LeaderboardEntry(
        userId: user['userId'] as String,
        username: user['username'] as String,
        avatarUrl: user['avatarUrl'] as String,
        level: level,
        totalXp: user['totalXp'] as int,
        rank: rank,
        rankBadge: LeaderboardEntry.calculateRankBadge(level),
        lastActive: user['lastActive'] as DateTime,
        streak: user['streak'] as int,
        recentAchievements: List<String>.from(user['recentAchievements'] as List),
        isCurrentUser: user['userId'] == currentUserId,
      ));
    }

    // Find current user entry
    LeaderboardEntry? currentUserEntry;
    if (currentUserId != null) {
      try {
        currentUserEntry = entries.firstWhere((entry) => entry.isCurrentUser);
      } catch (e) {
        // Current user not found in leaderboard
        currentUserEntry = null;
      }
    }

    final leaderboardData = LeaderboardData(
      entries: entries,
      currentUserEntry: currentUserEntry,
      totalUsers: entries.length,
      lastUpdated: DateTime.now(),
    );

    // Save to local storage
    await _saveLeaderboardData(leaderboardData);

    return leaderboardData;
  }

  // Get user achievements based on level
  List<String> _getUserAchievements(int level) {
    final achievements = <String>[];

    if (level >= 2) achievements.add('Level 2 Reached!');
    if (level >= 5) achievements.add('Level 5 Reached!');
    if (level >= 10) achievements.add('Level 10 Reached!');
    if (level >= 15) achievements.add('Level 15 Reached!');
    if (level >= 20) achievements.add('Level 20 Reached!');
    if (level >= 25) achievements.add('Level 25 Reached!');
    if (level >= 50) achievements.add('Level 50 Reached!');

    return achievements;
  }

  // Save leaderboard data to local storage
  Future<void> _saveLeaderboardData(LeaderboardData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_leaderboardKey, jsonEncode(data.toJson()));
    } catch (e) {
      print('Error saving leaderboard data: $e');
    }
  }

  // Refresh leaderboard data
  Future<LeaderboardData> refreshLeaderboard() async {
    return await _generateLeaderboardData();
  }

  // Get user's rank in leaderboard
  Future<int> getUserRank() async {
    final leaderboard = await getLeaderboard();
    return leaderboard.currentUserEntry?.rank ?? 1;
  }

  // Get users around current user's rank
  Future<List<LeaderboardEntry>> getUsersAroundRank(int range) async {
    final leaderboard = await getLeaderboard();
    final currentRank = leaderboard.currentUserEntry?.rank ?? 1;

    final startIndex = (currentRank - range - 1).clamp(0, leaderboard.entries.length - 1);
    final endIndex = (currentRank + range).clamp(0, leaderboard.entries.length);

    return leaderboard.entries.sublist(startIndex, endIndex);
  }

  // Watch real-time leaderboard updates from Firebase (excluding admins)
  Stream<LeaderboardData> watchLeaderboard() {
    return _firebaseSync.watchLeaderboardExcludingAdmins().asyncMap((firebaseData) async {
      if (firebaseData.isEmpty) {
        // Return empty leaderboard if no data
        return LeaderboardData(
          entries: [],
          currentUserEntry: null,
          totalUsers: 0,
          lastUpdated: DateTime.now(),
        );
      }

      // Update cache
      _cachedLeaderboardData = firebaseData;
      _lastLeaderboardSync = DateTime.now();

      // Build leaderboard data from Firebase data
      final leaderboardData = await _buildLeaderboardDataFromFirebase(firebaseData);
      return leaderboardData ??
          LeaderboardData(
            entries: [],
            currentUserEntry: null,
            totalUsers: 0,
            lastUpdated: DateTime.now(),
          );
    });
  }

  // Force refresh from Firebase
  Future<LeaderboardData> refreshFromFirebase() async {
    final firebaseData = await _getFirebaseLeaderboardData();
    if (firebaseData != null) {
      return firebaseData;
    }
    return await _generateLeaderboardData();
  }
}
