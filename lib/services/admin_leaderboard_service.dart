import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nihongo_japanese_app/models/leaderboard_model.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLeaderboardService {
  static const String _adminLeaderboardKey = 'admin_leaderboard';
  static const Duration _cacheExpiry = Duration(minutes: 5);

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseUserSyncService _firebaseSync = FirebaseUserSyncService();

  List<Map<String, dynamic>>? _cachedLeaderboardData;
  DateTime? _lastLeaderboardSync;

  // Get leaderboard data excluding admin users
  Future<LeaderboardData> getAdminLeaderboard() async {
    try {
      print('Fetching admin leaderboard data...');

      // Try to get real data from Firebase first
      final firebaseData = await _getFirebaseAdminLeaderboardData();
      if (firebaseData != null && firebaseData.entries.isNotEmpty) {
        print('Successfully loaded ${firebaseData.entries.length} users from Firebase');
        return firebaseData;
      }

      print('No Firebase data available, checking cached data...');

      // Fallback to cached data
      final prefs = await SharedPreferences.getInstance();
      final leaderboardJson = prefs.getString(_adminLeaderboardKey);

      if (leaderboardJson != null) {
        final data = LeaderboardData.fromJson(jsonDecode(leaderboardJson));

        // Check if data is recent (within last 5 minutes for admin)
        final now = DateTime.now();
        if (now.difference(data.lastUpdated).inMinutes < 5) {
          print('Using cached data with ${data.entries.length} users');
          return data;
        }
      }

      print('No cached data available, generating mock data...');
      // Generate fresh leaderboard data (mock data) as last resort
      return await _generateAdminLeaderboardData();
    } catch (e) {
      print('Error getting admin leaderboard: $e');
      return await _generateAdminLeaderboardData();
    }
  }

  // Get leaderboard data from Firebase excluding admin users
  Future<LeaderboardData?> _getFirebaseAdminLeaderboardData() async {
    try {
      final firebaseData = await _getFirebaseLeaderboardDataExcludingAdmins();
      if (firebaseData.isEmpty) return null;

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

        print('Processing user: $displayName (Level: $level, XP: $totalXp)');

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
          isCurrentUser: false, // Admin view doesn't highlight current user
        ));
      }

      final leaderboardData = LeaderboardData(
        entries: entries,
        currentUserEntry: null, // Admin doesn't need current user entry
        totalUsers: entries.length,
        lastUpdated: DateTime.now(),
      );

      // Save to local storage for offline access
      await _saveLeaderboardData(leaderboardData);

      return leaderboardData;
    } catch (e) {
      print('Error fetching Firebase admin leaderboard data: $e');
      return null;
    }
  }

  // Get Firebase leaderboard data excluding admin users
  Future<List<Map<String, dynamic>>> _getFirebaseLeaderboardDataExcludingAdmins(
      {bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh &&
          _cachedLeaderboardData != null &&
          _lastLeaderboardSync != null &&
          DateTime.now().difference(_lastLeaderboardSync!).compareTo(_cacheExpiry) < 0) {
        print('Returning cached admin leaderboard data');
        return _cachedLeaderboardData!;
      }

      // Get all leaderboard data
      final snapshot = await _database.ref().child('leaderboard').orderByChild('totalXp').get();

      if (snapshot.value == null) {
        print('No leaderboard data found in Firebase');
        return [];
      }

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> leaderboard = [];

      // Get all user IDs to check roles
      final userIds = data.keys.toList();
      final studentUserIds = <String>{};

      // Only include users with role: 'student'
      for (final userId in userIds) {
        try {
          // Check role field first
          final roleSnapshot =
              await _database.ref().child('users').child(userId).child('role').get();
          if (roleSnapshot.exists) {
            final role = roleSnapshot.value?.toString();
            if (role == 'student') {
              studentUserIds.add(userId);
            }
          } else {
            // If no role field exists, check if they're NOT an admin (legacy users default to student)
            final userSnapshot =
                await _database.ref().child('users').child(userId).child('isAdmin').get();
            if (!userSnapshot.exists || userSnapshot.value != true) {
              studentUserIds.add(userId);
            }
          }
        } catch (e) {
          print('Error checking role for user $userId: $e');
        }
      }

      // Only include students in leaderboard
      data.forEach((key, value) {
        if (studentUserIds.contains(key)) {
          final entry = Map<String, dynamic>.from(value as Map);
          entry['userId'] = key;
          leaderboard.add(entry);
        }
      });

      // Sort by XP (descending)
      leaderboard.sort((a, b) {
        final aXp = a['totalXp'] as int? ?? 0;
        final bXp = b['totalXp'] as int? ?? 0;
        return bXp.compareTo(aXp);
      });

      print('Found ${leaderboard.length} students in leaderboard');

      // Cache the result
      _cachedLeaderboardData = leaderboard;
      _lastLeaderboardSync = DateTime.now();

      return leaderboard;
    } catch (e) {
      print('Error fetching admin leaderboard data: $e');
      // Return cached data if available, even if expired
      return _cachedLeaderboardData ?? [];
    }
  }

  // Generate mock admin leaderboard data (excluding admin users)
  Future<LeaderboardData> _generateAdminLeaderboardData() async {
    // Mock data for demonstration (excluding admin users)
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

    // Create leaderboard entries with ranks
    final entries = <LeaderboardEntry>[];
    for (int i = 0; i < mockUsers.length; i++) {
      final user = mockUsers[i];
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
        isCurrentUser: false, // Admin view doesn't highlight current user
      ));
    }

    final leaderboardData = LeaderboardData(
      entries: entries,
      currentUserEntry: null, // Admin doesn't need current user entry
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
      await prefs.setString(_adminLeaderboardKey, jsonEncode(data.toJson()));
    } catch (e) {
      print('Error saving admin leaderboard data: $e');
    }
  }

  // Refresh leaderboard data
  Future<LeaderboardData> refreshLeaderboard() async {
    return await _generateAdminLeaderboardData();
  }

  // Force refresh from Firebase
  Future<LeaderboardData> refreshFromFirebase() async {
    final firebaseData = await _getFirebaseAdminLeaderboardData();
    if (firebaseData != null) {
      return firebaseData;
    }
    return await _generateAdminLeaderboardData();
  }

  // Watch real-time leaderboard updates from Firebase (excluding admins)
  Stream<LeaderboardData> watchAdminLeaderboard() {
    return _database
        .ref()
        .child('leaderboard')
        .orderByChild('totalXp')
        .onValue
        .asyncMap((event) async {
      if (event.snapshot.value == null) {
        return LeaderboardData(
          entries: [],
          currentUserEntry: null,
          totalUsers: 0,
          lastUpdated: DateTime.now(),
        );
      }

      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;

      // Get all user IDs to check roles
      final userIds = data.keys.toList();
      final studentUserIds = <String>{};

      // Only include users with role: 'student'
      for (final userId in userIds) {
        try {
          // Check role field first
          final roleSnapshot =
              await _database.ref().child('users').child(userId).child('role').get();
          if (roleSnapshot.exists) {
            final role = roleSnapshot.value?.toString();
            if (role == 'student') {
              studentUserIds.add(userId);
            }
          } else {
            // If no role field exists, check if they're NOT an admin (legacy users default to student)
            final userSnapshot =
                await _database.ref().child('users').child(userId).child('isAdmin').get();
            if (!userSnapshot.exists || userSnapshot.value != true) {
              studentUserIds.add(userId);
            }
          }
        } catch (e) {
          print('Error checking role for user $userId: $e');
        }
      }

      // Only include students in leaderboard
      final List<Map<String, dynamic>> leaderboard = [];
      data.forEach((key, value) {
        if (studentUserIds.contains(key)) {
          final entry = Map<String, dynamic>.from(value as Map);
          entry['userId'] = key;
          leaderboard.add(entry);
        }
      });

      // Sort by XP (descending)
      leaderboard.sort((a, b) => (b['totalXp'] as int).compareTo(a['totalXp'] as int));

      // Convert to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];
      for (int i = 0; i < leaderboard.length; i++) {
        final user = leaderboard[i];
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
          isCurrentUser: false,
        ));
      }

      return LeaderboardData(
        entries: entries,
        currentUserEntry: null,
        totalUsers: entries.length,
        lastUpdated: DateTime.now(),
      );
    });
  }
}
