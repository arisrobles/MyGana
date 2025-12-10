import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/daily_points_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:nihongo_japanese_app/services/review_progress_service.dart';
import 'package:nihongo_japanese_app/services/streak_analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseUserSyncService {
  static final FirebaseUserSyncService _instance = FirebaseUserSyncService._internal();
  factory FirebaseUserSyncService() => _instance;

  FirebaseUserSyncService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sync queue for offline operations
  final List<Map<String, dynamic>> _syncQueue = [];
  Timer? _syncTimer;
  bool _isOnline = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  // Caching for performance optimization
  Map<String, dynamic>? _cachedUserData;
  List<Map<String, dynamic>>? _cachedLeaderboardData;
  DateTime? _lastUserDataSync;
  DateTime? _lastLeaderboardSync;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Firebase listeners management
  StreamSubscription<DatabaseEvent>? _userDataListener;
  StreamSubscription<DatabaseEvent>? _leaderboardListener;
  String? _currentListenerUid;

  // Initialize sync service
  void initialize() {
    _startSyncTimer();
    _checkConnectivity();
    _setupRealtimeListeners();
  }

  // Clear listeners and cache when user changes
  void clearUserData() {
    print('Clearing Firebase listeners and cache for user change');
    
    // Cancel existing listeners
    _userDataListener?.cancel();
    _leaderboardListener?.cancel();
    _userDataListener = null;
    _leaderboardListener = null;
    
    // Clear cache
    _cachedUserData = null;
    _cachedLeaderboardData = null;
    _lastUserDataSync = null;
    _lastLeaderboardSync = null;
    _currentListenerUid = null;
    
    print('Firebase listeners and cache cleared');
  }

  // Refresh listeners for current user (useful when auth state changes)
  void refreshListeners() {
    print('Refreshing Firebase listeners for current user');
    _setupRealtimeListeners();
  }

  // Start periodic sync timer
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && _syncQueue.isNotEmpty) {
        _processSyncQueue();
      }
    });
  }

  // Check connectivity and process queue
  void _checkConnectivity() {
    // Simple connectivity check - will be updated when connection is lost
    _isOnline = true;
  }

  // Process queued sync operations
  Future<void> _processSyncQueue() async {
    if (_syncQueue.isEmpty) return;

    final operations = List<Map<String, dynamic>>.from(_syncQueue);
    _syncQueue.clear();

    for (final operation in operations) {
      try {
        await _executeSyncOperation(operation);
      } catch (e) {
        print('Failed to process queued operation: $e');
        // Re-queue failed operations
        _syncQueue.add(operation);
      }
    }
  }

  // Execute a sync operation
  Future<void> _executeSyncOperation(Map<String, dynamic> operation) async {
    final type = operation['type'] as String;
    final data = operation['data'] as Map<String, dynamic>;

    switch (type) {
      case 'full_sync':
        await _performFullSync(data);
        break;
      case 'xp_change':
        await _performXpSync(data);
        break;
      case 'streak_change':
        await _performStreakSync(data);
        break;
    }
  }

  // Sync user XP and rank data to Firebase with retry logic
  Future<void> syncUserProgressToFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No authenticated user found, skipping Firebase sync');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userProgressData = await _getUserProgressData(prefs);
      final totalPoints = await _getTotalPoints(prefs);

      // Get displayName from Firebase Database (firstName + lastName) or fallback to Firebase Auth
      String displayName = 'Anonymous User';
      try {
        final userSnapshot = await _database.child('users').child(user.uid).get();
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          final firstName = userData['firstName']?.toString() ?? '';
          final lastName = userData['lastName']?.toString() ?? '';
          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            displayName = '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            displayName = firstName;
          } else if (lastName.isNotEmpty) {
            displayName = lastName;
          }
        }
      } catch (e) {
        print('Error getting user data for displayName: $e');
        // Fallback to Firebase Auth displayName
        displayName = user.displayName ?? 'Anonymous User';
      }

      // Get comprehensive user data from all sources
      final comprehensiveData = await _getComprehensiveUserData(prefs);

      final syncData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'lastUpdated': ServerValue.timestamp,
        'totalXp': userProgressData['totalXp'] ?? 0,
        'level': userProgressData['level'] ?? 1,
        'currentStreak': userProgressData['currentStreak'] ?? 0,
        'longestStreak': userProgressData['longestStreak'] ?? 0,
        'totalPoints': totalPoints,
        'lastActive': ServerValue.timestamp,
        'isOnline': true,
        'rank': _calculateRank(userProgressData['totalXp'] ?? 0),
        'rankBadge': _getRankBadge(userProgressData['totalXp'] ?? 0),
        'characterMastery': userProgressData['characterMastery'] ?? {},
        'recentAchievements': userProgressData['recentAchievements'] ?? [],

        // NEW: Comprehensive user data - Use calculated totalPoints instead of just total_points
        'mojiPoints': totalPoints, // This is the calculated total from all sources
        'mojiCoins': comprehensiveData['mojiCoins'] ?? 0,
        'characterProgress': comprehensiveData['characterProgress'] ?? {},
        'storyProgress': comprehensiveData['storyProgress'] ?? {},
        'quizResults': comprehensiveData['quizResults'] ?? [],
        'lessonProgress': comprehensiveData['lessonProgress'] ?? {},
        'challengeProgress': comprehensiveData['challengeProgress'] ?? {},
        'reviewProgress': comprehensiveData['reviewProgress'] ?? {},
        'dailyProgress': comprehensiveData['dailyProgress'] ?? {},
        'dashboardProgress': comprehensiveData['dashboardProgress'] ?? {},
        'individualQuizSessions': comprehensiveData['individualQuizSessions'] ?? {},
        'individualStorySessions': comprehensiveData['individualStorySessions'] ?? {},
        'unfinishedActivities': comprehensiveData['unfinishedActivities'] ?? {},
        'settings': comprehensiveData['settings'] ?? {},
        'userStatistics': comprehensiveData['userStatistics'] ?? {},
      };

      if (_isOnline) {
        await _performFullSync(syncData);
      } else {
        _queueSyncOperation('full_sync', syncData);
      }
    } catch (e) {
      print('Error syncing user progress to Firebase: $e');
      _handleSyncError(e);
    }
  }

  // Perform full sync with retry logic
  Future<void> _performFullSync(Map<String, dynamic> userData) async {
    await _retryOperation(() async {
      final user = _auth.currentUser!;

      // Validate and sanitize data before sync
      final validatedData = _validateAndSanitizeUserData(userData);

      // IMPORTANT: Do not overwrite per-character marks subtree; those are
      // managed via setCharacterMark() at users/{uid}/characterProgress/{characterId}
      // Removing here prevents a full-node replace that would wipe siblings
      validatedData.remove('characterProgress');

      // Update user data in Firebase
      await _database.child('users').child(user.uid).update(validatedData);

      // Also update leaderboard data
      await _updateLeaderboardEntry(user.uid, validatedData);

      // Update cache
      _cachedUserData = validatedData;
      _lastUserDataSync = DateTime.now();

      print('Successfully synced user progress to Firebase');
      _retryCount = 0; // Reset retry count on success
    });
  }

  // Validate and sanitize user data
  Map<String, dynamic> _validateAndSanitizeUserData(Map<String, dynamic> data) {
    final validated = <String, dynamic>{};

    // Validate required fields
    validated['userId'] = data['userId']?.toString() ?? '';
    validated['email'] = _sanitizeEmail(data['email']?.toString() ?? '');
    validated['displayName'] =
        _sanitizeString(data['displayName']?.toString() ?? 'Anonymous User', maxLength: 50);
    validated['photoURL'] = _sanitizeUrl(data['photoURL']?.toString() ?? '');

    // Validate numeric fields
    validated['totalXp'] = _validateInt(data['totalXp'], min: 0, max: 1000000);
    validated['level'] = _validateInt(data['level'], min: 1, max: 100);
    validated['currentStreak'] = _validateInt(data['currentStreak'], min: 0, max: 365);
    validated['longestStreak'] = _validateInt(data['longestStreak'], min: 0, max: 365);
    validated['totalPoints'] = _validateInt(data['totalPoints'], min: 0, max: 10000000);

    // Validate rank data
    validated['rank'] = _validateString(data['rank']?.toString() ?? 'Rookie',
        allowedValues: ['Rookie', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond']);
    validated['rankBadge'] = _validateString(data['rankBadge']?.toString() ?? '🌱',
        allowedValues: ['🌱', '🥉', '🥈', '🥇', '🏆', '💎']);

    // Validate arrays
    validated['recentAchievements'] =
        _validateStringList(data['recentAchievements'], maxLength: 10);
    validated['characterMastery'] = _validateMap(data['characterMastery'] ?? {});

    // NEW: Validate comprehensive data
    validated['mojiPoints'] = _validateInt(data['mojiPoints'], min: 0, max: 10000000);
    validated['mojiCoins'] = _validateInt(data['mojiCoins'], min: 0, max: 1000000);
    validated['characterProgress'] = _validateMap(data['characterProgress'] ?? {});
    validated['storyProgress'] = _validateMap(data['storyProgress'] ?? {});
    validated['quizResults'] = _validateList(data['quizResults'] ?? []);
    validated['lessonProgress'] = _validateMap(data['lessonProgress'] ?? {});
    validated['challengeProgress'] = _validateMap(data['challengeProgress'] ?? {});
    validated['reviewProgress'] = _validateMap(data['reviewProgress'] ?? {});
    validated['dailyProgress'] = _validateMap(data['dailyProgress'] ?? {});
    validated['dashboardProgress'] = _validateMap(data['dashboardProgress'] ?? {});
    validated['individualQuizSessions'] = _validateMap(data['individualQuizSessions'] ?? {});
    validated['individualStorySessions'] = _validateMap(data['individualStorySessions'] ?? {});
    validated['unfinishedActivities'] = _validateMap(data['unfinishedActivities'] ?? {});
    validated['settings'] = _validateMap(data['settings'] ?? {});
    validated['userStatistics'] = _validateMap(data['userStatistics'] ?? {});

    // Add timestamps
    validated['lastUpdated'] = data['lastUpdated'] ?? ServerValue.timestamp;
    validated['lastActive'] = data['lastActive'] ?? ServerValue.timestamp;
    validated['isOnline'] = data['isOnline'] == true;

    return validated;
  }

  // Sanitize email
  String _sanitizeEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email) ? email : '';
  }

  // Sanitize string
  String _sanitizeString(String input, {int maxLength = 100}) {
    return input
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim()
        .substring(0, input.length > maxLength ? maxLength : input.length);
  }

  // Sanitize URL
  String _sanitizeUrl(String url) {
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') ? url : '';
  }

  // Validate integer
  int _validateInt(dynamic value, {int min = 0, int max = 999999}) {
    if (value is int) {
      return value.clamp(min, max);
    } else if (value is String) {
      final parsed = int.tryParse(value);
      return parsed != null ? parsed.clamp(min, max) : min;
    }
    return min;
  }

  // Validate string with allowed values
  String _validateString(String value, {List<String>? allowedValues}) {
    if (allowedValues != null && !allowedValues.contains(value)) {
      return allowedValues.first;
    }
    return _sanitizeString(value);
  }

  // Validate string list
  List<String> _validateStringList(dynamic value, {int maxLength = 10}) {
    if (value is List) {
      return value
          .where((item) => item is String)
          .cast<String>()
          .map((s) => _sanitizeString(s, maxLength: 50))
          .take(maxLength)
          .toList();
    }
    return [];
  }

  // Validate map
  Map<String, dynamic> _validateMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return {};
  }

  // Retry operation with exponential backoff
  Future<void> _retryOperation(Future<void> Function() operation) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await operation();
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          throw e;
        }

        final delay = Duration(seconds: _retryDelay.inSeconds * (attempt + 1));
        print('Sync attempt ${attempt + 1} failed, retrying in ${delay.inSeconds}s: $e');
        await Future.delayed(delay);
      }
    }
  }

  // Queue sync operation for offline processing
  void _queueSyncOperation(String type, Map<String, dynamic> data) {
    _syncQueue.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('Queued sync operation: $type');
  }

  // Handle sync errors
  void _handleSyncError(dynamic error) {
    _retryCount++;
    if (_retryCount >= _maxRetries) {
      print('Max retry attempts reached, marking as offline');
      _isOnline = false;
    }
  }

  // Get user progress data from SharedPreferences
  Future<Map<String, dynamic>> _getUserProgressData(SharedPreferences prefs) async {
    try {
      final progressJson = prefs.getString('user_progress');
      if (progressJson != null) {
        final Map<String, dynamic> data = jsonDecode(progressJson);
        return data;
      }
    } catch (e) {
      print('Error reading user progress data: $e');
    }
    return {};
  }

  // Get total points from all sources (same calculation as used throughout the app)
  Future<int> _getTotalPoints(SharedPreferences prefs) async {
    try {
      // Calculate total points the same way as in the app UI
      final results = await Future.wait([
        // Challenge points from ChallengeProgressService
        ChallengeProgressService().getTotalPoints(),
        // Review points from ReviewProgressService
        ReviewProgressService().getTotalReviewPoints(),
        // Story points from SharedPreferences
        Future.value(prefs.getInt('story_total_points') ?? 0),
        // Quiz points from SharedPreferences
        Future.value(prefs.getInt('quiz_total_points') ?? 0),
        // Daily points from DailyPointsService (live calculation)
        DailyPointsService().getLastClaimTime().then((lastClaim) async {
          if (lastClaim == null) return 0;
          final multiplier = await DailyPointsService().getStreakBonusMultiplier();
          return (100 * multiplier).round();
        }),
      ]);

      // Sum all the results
      final totalPoints = results.fold<int>(0, (sum, points) => sum + points);

      print('Total points calculation:');
      print('Challenge points: ${results[0]}');
      print('Review points: ${results[1]}');
      print('Story points: ${results[2]}');
      print('Quiz points: ${results[3]}');
      print('Daily points: ${results[4]}');
      print('Total calculated: $totalPoints');

      return totalPoints;
    } catch (e) {
      print('Error calculating total points: $e');
      return 0;
    }
  }

  // Calculate rank based on XP
  String _calculateRank(int totalXp) {
    if (totalXp >= 10000) return 'Diamond';
    if (totalXp >= 5000) return 'Platinum';
    if (totalXp >= 2500) return 'Gold';
    if (totalXp >= 1000) return 'Silver';
    if (totalXp >= 500) return 'Bronze';
    return 'Rookie';
  }

  // Get rank badge based on XP
  String _getRankBadge(int totalXp) {
    if (totalXp >= 10000) return '💎';
    if (totalXp >= 5000) return '🏆';
    if (totalXp >= 2500) return '🥇';
    if (totalXp >= 1000) return '🥈';
    if (totalXp >= 500) return '🥉';
    return '🌱';
  }

  // Update leaderboard entry
  Future<void> _updateLeaderboardEntry(String userId, Map<String, dynamic> userData) async {
    try {
      final leaderboardData = {
        'userId': userId,
        'displayName': userData['displayName'],
        'totalXp': userData['totalXp'],
        'level': userData['level'],
        'rank': userData['rank'],
        'rankBadge': userData['rankBadge'],
        'currentStreak': userData['currentStreak'],
        'lastActive': userData['lastActive'],
        'isOnline': userData['isOnline'],
      };

      await _database.child('leaderboard').child(userId).update(leaderboardData);
    } catch (e) {
      print('Error updating leaderboard entry: $e');
    }
  }

  // Get leaderboard data from Firebase with caching
  Future<List<Map<String, dynamic>>> getLeaderboardData({bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh &&
          _cachedLeaderboardData != null &&
          _lastLeaderboardSync != null &&
          DateTime.now().difference(_lastLeaderboardSync!).compareTo(_cacheExpiry) < 0) {
        print('Returning cached leaderboard data');
        return _cachedLeaderboardData!;
      }

      final snapshot = await _database.child('leaderboard').orderByChild('totalXp').get();

      if (snapshot.value == null) return [];

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> leaderboard = [];

      data.forEach((key, value) {
        final entry = Map<String, dynamic>.from(value as Map);
        entry['userId'] = key;
        leaderboard.add(entry);
      });

      // Sort by XP (descending)
      leaderboard.sort((a, b) {
        final aXp = a['totalXp'] as int? ?? 0;
        final bXp = b['totalXp'] as int? ?? 0;
        return bXp.compareTo(aXp);
      });

      // Cache the result
      _cachedLeaderboardData = leaderboard;
      _lastLeaderboardSync = DateTime.now();

      return leaderboard;
    } catch (e) {
      print('Error fetching leaderboard data: $e');
      // Return cached data if available, even if expired
      return _cachedLeaderboardData ?? [];
    }
  }

  // Get current user's leaderboard position
  Future<Map<String, dynamic>?> getCurrentUserLeaderboardData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _database.child('leaderboard').child(user.uid).get();

      if (snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['userId'] = user.uid;

      return data;
    } catch (e) {
      print('Error fetching current user leaderboard data: $e');
      return null;
    }
  }

  // Set user as offline
  Future<void> setUserOffline() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _database.child('users').child(user.uid).update({
        'isOnline': false,
        'lastActive': ServerValue.timestamp,
      });

      await _database.child('leaderboard').child(user.uid).update({
        'isOnline': false,
        'lastActive': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error setting user offline: $e');
    }
  }

  // Listen to real-time leaderboard updates
  Stream<List<Map<String, dynamic>>> watchLeaderboard() {
    return _database.child('leaderboard').orderByChild('totalXp').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> leaderboard = [];

      data.forEach((key, value) {
        final entry = Map<String, dynamic>.from(value as Map);
        entry['userId'] = key;
        leaderboard.add(entry);
      });

      // Sort by XP (descending)
      leaderboard.sort((a, b) {
        final aXp = a['totalXp'] as int? ?? 0;
        final bXp = b['totalXp'] as int? ?? 0;
        return bXp.compareTo(aXp);
      });

      return leaderboard;
    });
  }

  // Get leaderboard data excluding admin users
  Future<List<Map<String, dynamic>>> getLeaderboardDataExcludingAdmins({bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh &&
          _cachedLeaderboardData != null &&
          _lastLeaderboardSync != null &&
          DateTime.now().difference(_lastLeaderboardSync!).compareTo(_cacheExpiry) < 0) {
        print('Returning cached leaderboard data (excluding admins)');
        return _cachedLeaderboardData!;
      }

      // Get all leaderboard data
      final snapshot = await _database.child('leaderboard').orderByChild('totalXp').get();

      if (snapshot.value == null) return [];

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> leaderboard = [];

      // Get all user IDs to check admin status
      final userIds = data.keys.toList();
      final adminUserIds = <String>{};

      // Check which users are admins
      for (final userId in userIds) {
        try {
          final userSnapshot = await _database.child('users').child(userId).child('isAdmin').get();
          if (userSnapshot.exists && userSnapshot.value == true) {
            adminUserIds.add(userId);
          }
        } catch (e) {
          print('Error checking admin status for user $userId: $e');
        }
      }

      // Filter out admin users and build leaderboard
      data.forEach((key, value) {
        if (!adminUserIds.contains(key)) {
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

      // Cache the result
      _cachedLeaderboardData = leaderboard;
      _lastLeaderboardSync = DateTime.now();

      return leaderboard;
    } catch (e) {
      print('Error fetching leaderboard data (excluding admins): $e');
      // Return cached data if available, even if expired
      return _cachedLeaderboardData ?? [];
    }
  }

  // Watch real-time leaderboard updates excluding admin users
  Stream<List<Map<String, dynamic>>> watchLeaderboardExcludingAdmins() {
    return _database.child('leaderboard').orderByChild('totalXp').onValue.asyncMap((event) async {
      if (event.snapshot.value == null) return [];

      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      
      // Get all user IDs to check admin status
      final userIds = data.keys.toList();
      final adminUserIds = <String>{};

      // Check which users are admins
      for (final userId in userIds) {
        try {
          final userSnapshot = await _database.child('users').child(userId).child('isAdmin').get();
          if (userSnapshot.exists && userSnapshot.value == true) {
            adminUserIds.add(userId);
          }
        } catch (e) {
          print('Error checking admin status for user $userId: $e');
        }
      }

      // Filter out admin users and build leaderboard
      final List<Map<String, dynamic>> leaderboard = [];
      data.forEach((key, value) {
        if (!adminUserIds.contains(key)) {
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

      return leaderboard;
    });
  }

  // Sync specific XP change with retry logic
  Future<void> syncXpChange(int newXp, int newLevel) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userData = {
        'totalXp': newXp,
        'level': newLevel,
        'rank': _calculateRank(newXp),
        'rankBadge': _getRankBadge(newXp),
        'lastUpdated': ServerValue.timestamp,
        'lastActive': ServerValue.timestamp,
      };

      if (_isOnline) {
        await _performXpSync(userData);
      } else {
        _queueSyncOperation('xp_change', userData);
      }
    } catch (e) {
      print('Error syncing XP change: $e');
      _handleSyncError(e);
    }
  }

  // Perform XP sync with retry logic
  Future<void> _performXpSync(Map<String, dynamic> userData) async {
    await _retryOperation(() async {
      final user = _auth.currentUser!;

      await _database.child('users').child(user.uid).update(userData);
      await _database.child('leaderboard').child(user.uid).update(userData);

      print('Successfully synced XP change: ${userData['totalXp']} XP, Level ${userData['level']}');
    });
  }

  // Sync streak change with retry logic
  Future<void> syncStreakChange(int currentStreak, int longestStreak) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userData = {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastUpdated': ServerValue.timestamp,
        'lastActive': ServerValue.timestamp,
      };

      if (_isOnline) {
        await _performStreakSync(userData);
      } else {
        _queueSyncOperation('streak_change', userData);
      }
    } catch (e) {
      print('Error syncing streak change: $e');
      _handleSyncError(e);
    }
  }

  // Perform streak sync with retry logic
  Future<void> _performStreakSync(Map<String, dynamic> userData) async {
    await _retryOperation(() async {
      final user = _auth.currentUser!;

      await _database.child('users').child(user.uid).update(userData);
      await _database.child('leaderboard').child(user.uid).update(userData);

      print(
          'Successfully synced streak change: ${userData['currentStreak']} current, ${userData['longestStreak']} longest');
    });
  }

  // Get sync status
  bool get isOnline => _isOnline;
  int get queuedOperations => _syncQueue.length;
  int get retryCount => _retryCount;

  // -------- Character marks (writing) --------
  Future<void> setCharacterMark({
    required String characterId,
    required String script,
    required String mark,
    required int scorePercent,
    String? drawingPath,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final done = mark == 'goods' || mark == 'excellent';
      final now = ServerValue.timestamp;

      final payload = {
        'characterId': characterId,
        'script': script,
        'mark': mark,
        'scorePercent': scorePercent,
        'done': done,
        'drawingPath': drawingPath,
        'updatedAt': now,
        // Backward compatible fields for existing dashboards
        'characterType': script,
        'masteryLevel': scorePercent,
        'practiceCount': 1,
        'lastPracticed': now,
      };

      // Update only the specific character node (upsert)
      await _database
          .child('users')
          .child(user.uid)
          .child('characterProgress')
          .child(characterId)
          .update(payload);
    } catch (e) {
      print('Error setting character mark: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchCharacterMarks() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};
      final snapshot =
          await _database.child('users').child(user.uid).child('characterProgress').get();
      if (!snapshot.exists) return {};
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return map;
    } catch (e) {
      print('Error fetching character marks: $e');
      return {};
    }
  }

  Stream<Map<String, dynamic>> watchCharacterMarks() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _database
        .child('users')
        .child(user.uid)
        .child('characterProgress')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <String, dynamic>{};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  // Force sync all queued operations
  Future<void> forceSync() async {
    if (_syncQueue.isNotEmpty) {
      await _processSyncQueue();
    }
  }

  // Batch sync multiple operations for better performance
  Future<void> batchSync(List<Map<String, dynamic>> operations) async {
    if (operations.isEmpty) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Group operations by type
      final Map<String, List<Map<String, dynamic>>> groupedOps = {};
      for (final op in operations) {
        final type = op['type'] as String;
        groupedOps.putIfAbsent(type, () => []).add(op);
      }

      // Process each group
      for (final entry in groupedOps.entries) {
        final type = entry.key;
        final ops = entry.value;

        switch (type) {
          case 'xp_change':
            await _batchXpSync(ops);
            break;
          case 'streak_change':
            await _batchStreakSync(ops);
            break;
          case 'full_sync':
            // Only sync the latest full sync
            if (ops.isNotEmpty) {
              await _performFullSync(ops.last['data']);
            }
            break;
        }
      }

      print('Successfully batch synced ${operations.length} operations');
    } catch (e) {
      print('Error in batch sync: $e');
      // Fallback to individual sync
      for (final op in operations) {
        _queueSyncOperation(op['type'], op['data']);
      }
    }
  }

  // Batch XP sync operations
  Future<void> _batchXpSync(List<Map<String, dynamic>> operations) async {
    if (operations.isEmpty) return;

    // Use the latest XP values
    final latestOp = operations.last;
    final userData = latestOp['data'] as Map<String, dynamic>;

    await _retryOperation(() async {
      final user = _auth.currentUser!;

      await _database.child('users').child(user.uid).update(userData);
      await _database.child('leaderboard').child(user.uid).update(userData);

      print('Successfully batch synced ${operations.length} XP changes');
    });
  }

  // Batch streak sync operations
  Future<void> _batchStreakSync(List<Map<String, dynamic>> operations) async {
    if (operations.isEmpty) return;

    // Use the latest streak values
    final latestOp = operations.last;
    final userData = latestOp['data'] as Map<String, dynamic>;

    await _retryOperation(() async {
      final user = _auth.currentUser!;

      await _database.child('users').child(user.uid).update(userData);
      await _database.child('leaderboard').child(user.uid).update(userData);

      print('Successfully batch synced ${operations.length} streak changes');
    });
  }

  // Clear cache
  void clearCache() {
    _cachedUserData = null;
    _cachedLeaderboardData = null;
    _lastUserDataSync = null;
    _lastLeaderboardSync = null;
  }

  // Get cache status
  Map<String, dynamic> getCacheStatus() {
    return {
      'hasUserData': _cachedUserData != null,
      'hasLeaderboardData': _cachedLeaderboardData != null,
      'lastUserDataSync': _lastUserDataSync?.toIso8601String(),
      'lastLeaderboardSync': _lastLeaderboardSync?.toIso8601String(),
      'queuedOperations': _syncQueue.length,
      'isOnline': _isOnline,
      'retryCount': _retryCount,
    };
  }

  // Get comprehensive user data from all sources
  Future<Map<String, dynamic>> _getComprehensiveUserData(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> data = {};

      // 1. Moji Points & Coins - Calculate total points from all sources
      data['mojiPoints'] = await _getTotalPoints(prefs); // Use calculated total
      data['mojiCoins'] = prefs.getInt('moji_coins') ?? 1000; // Default coins

      // 2. Character Progress (from user_progress JSON)
      final userProgressJson = prefs.getString('user_progress');
      if (userProgressJson != null) {
        final userProgressData = jsonDecode(userProgressJson);
        data['characterProgress'] = userProgressData['characterProgress'] ?? {};
        data['storyProgress'] = userProgressData['storyProgress'] ?? {};
        data['quizResults'] = userProgressData['quizResults'] ?? [];
      }

      // 3. Dashboard Progress (from dashboard_progress JSON)
      final dashboardProgressJson = prefs.getString('dashboard_progress');
      if (dashboardProgressJson != null) {
        data['dashboardProgress'] = jsonDecode(dashboardProgressJson);
      }

      // 4. Challenge Progress
      data['challengeProgress'] = await _getChallengeProgressData(prefs);

      // 5. Review Progress
      data['reviewProgress'] = await _getReviewProgressData(prefs);

      // 6. Daily Progress
      data['dailyProgress'] = await _getDailyProgressData(prefs);

      // 7. Unfinished Activities
      data['unfinishedActivities'] = await _getUnfinishedActivitiesData(prefs);

      // 8. Individual Quiz and Story Sessions
      data['individualQuizSessions'] = await _getIndividualQuizSessions(prefs);
      data['individualStorySessions'] = await _getIndividualStorySessions(prefs);

      // 9. Settings
      data['settings'] = await _getSettingsData(prefs);

      // 10. Lesson Progress (from various sources)
      data['lessonProgress'] = await _getLessonProgressData(prefs);

      // 11. User Statistics (comprehensive stats from user stats screen)
      data['userStatistics'] = await _getUserStatistics(prefs);

      return data;
    } catch (e) {
      print('Error getting comprehensive user data: $e');
      return {};
    }
  }

  // Get challenge progress data
  Future<Map<String, dynamic>> _getChallengeProgressData(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> challengeData = {};
      final keys = prefs.getKeys();

      // Get all challenge-related keys
      for (var key in keys) {
        if (key.startsWith('topic_score_') ||
            key.startsWith('challenge_completed_') ||
            key.startsWith('recent_activity_')) {
          final value = prefs.get(key);
          challengeData[key] = value;
        }
      }

      return challengeData;
    } catch (e) {
      print('Error getting challenge progress data: $e');
      return {};
    }
  }

  // Get review progress data
  Future<Map<String, dynamic>> _getReviewProgressData(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> reviewData = {};
      final keys = prefs.getKeys();

      // Get all review-related keys
      for (var key in keys) {
        if (key.startsWith('review_') ||
            key.startsWith('review_score_') ||
            key.startsWith('review_completed_')) {
          final value = prefs.get(key);
          reviewData[key] = value;
        }
      }

      return reviewData;
    } catch (e) {
      print('Error getting review progress data: $e');
      return {};
    }
  }

  // Get daily progress data
  Future<Map<String, dynamic>> _getDailyProgressData(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> dailyData = {};
      final keys = prefs.getKeys();

      // Get all daily-related keys
      for (var key in keys) {
        if (key.startsWith('daily_') ||
            key.startsWith('claimed_today_') ||
            key.startsWith('spins_remaining') ||
            key.startsWith('last_claim_time')) {
          final value = prefs.get(key);
          dailyData[key] = value;
        }
      }

      return dailyData;
    } catch (e) {
      print('Error getting daily progress data: $e');
      return {};
    }
  }

  // Get unfinished activities data
  Future<Map<String, dynamic>> _getUnfinishedActivitiesData(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> activitiesData = {};
      final keys = prefs.getKeys();

      // Get all activity-related keys
      for (var key in keys) {
        if (key.startsWith('activity_') ||
            key.startsWith('unfinished_') ||
            key.startsWith('current_')) {
          final value = prefs.get(key);
          activitiesData[key] = value;
        }
      }

      return activitiesData;
    } catch (e) {
      print('Error getting unfinished activities data: $e');
      return {};
    }
  }

  // Get settings data
  Future<Map<String, dynamic>> _getSettingsData(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> settingsData = {};
      final keys = prefs.getKeys();

      // Get all settings-related keys
      for (var key in keys) {
        if (key.startsWith('setting_') ||
            key.startsWith('preference_') ||
            key.startsWith('theme_') ||
            key.startsWith('sound_') ||
            key.startsWith('notification_')) {
          final value = prefs.get(key);
          settingsData[key] = value;
        }
      }

      return settingsData;
    } catch (e) {
      print('Error getting settings data: $e');
      return {};
    }
  }

  // Get lesson progress data
  Future<Map<String, dynamic>> _getLessonProgressData(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> lessonData = {};
      final keys = prefs.getKeys();

      // Get all lesson-related keys
      for (var key in keys) {
        if (key.startsWith('lesson_') ||
            key.startsWith('quiz_completed_') ||
            key.startsWith('quiz_result_') ||
            key.startsWith('story_completed_') ||
            key.startsWith('story_progress_')) {
          final value = prefs.get(key);
          lessonData[key] = value;
        }
      }

      return lessonData;
    } catch (e) {
      print('Error getting lesson progress data: $e');
      return {};
    }
  }

  // Validate list
  List<dynamic> _validateList(dynamic value) {
    if (value is List) {
      return value;
    }
    return [];
  }

  // Restore user data from Firebase to local storage
  Future<void> restoreUserDataFromFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('Restoring user data from Firebase...');

      // Get user data from Firebase
      final userSnapshot = await _database.child('users').child(user.uid).get();
      if (!userSnapshot.exists) {
        print('No user data found in Firebase');
        return;
      }

      final userData = userSnapshot.value as Map<dynamic, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      // Restore comprehensive data
      await _restoreComprehensiveData(userData, prefs);

      // Merge with local data (keep newer data)
      await _mergeWithLocalData(userData, prefs);

      print('User data restored from Firebase successfully');
    } catch (e) {
      print('Error restoring user data from Firebase: $e');
    }
  }

  // Restore comprehensive data to local storage
  Future<void> _restoreComprehensiveData(
      Map<dynamic, dynamic> userData, SharedPreferences prefs) async {
    try {
      // 1. Restore Moji Points & Coins
      if (userData.containsKey('mojiPoints')) {
        await prefs.setInt('total_points', userData['mojiPoints'] as int);
      }
      if (userData.containsKey('mojiCoins')) {
        await prefs.setInt('moji_coins', userData['mojiCoins'] as int);
      }

      // 2. Restore Character Progress
      if (userData.containsKey('characterProgress')) {
        final userProgressJson = prefs.getString('user_progress');
        Map<String, dynamic> userProgressData = {};
        if (userProgressJson != null) {
          userProgressData = jsonDecode(userProgressJson);
        }
        userProgressData['characterProgress'] = userData['characterProgress'];
        await prefs.setString('user_progress', jsonEncode(userProgressData));
      }

      // 3. Restore Story Progress
      if (userData.containsKey('storyProgress')) {
        final userProgressJson = prefs.getString('user_progress');
        Map<String, dynamic> userProgressData = {};
        if (userProgressJson != null) {
          userProgressData = jsonDecode(userProgressJson);
        }
        userProgressData['storyProgress'] = userData['storyProgress'];
        await prefs.setString('user_progress', jsonEncode(userProgressData));
      }

      // 4. Restore Quiz Results
      if (userData.containsKey('quizResults')) {
        final userProgressJson = prefs.getString('user_progress');
        Map<String, dynamic> userProgressData = {};
        if (userProgressJson != null) {
          userProgressData = jsonDecode(userProgressJson);
        }
        userProgressData['quizResults'] = userData['quizResults'];
        await prefs.setString('user_progress', jsonEncode(userProgressData));
      }

      // 5. Restore Dashboard Progress
      if (userData.containsKey('dashboardProgress')) {
        await prefs.setString('dashboard_progress', jsonEncode(userData['dashboardProgress']));
      }

      // 6. Restore Challenge Progress
      if (userData.containsKey('challengeProgress')) {
        final challengeData = userData['challengeProgress'] as Map<dynamic, dynamic>;
        for (var entry in challengeData.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          }
        }
      }

      // 7. Restore Review Progress
      if (userData.containsKey('reviewProgress')) {
        final reviewData = userData['reviewProgress'] as Map<dynamic, dynamic>;
        for (var entry in reviewData.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          }
        }
      }

      // 8. Restore Daily Progress
      if (userData.containsKey('dailyProgress')) {
        final dailyData = userData['dailyProgress'] as Map<dynamic, dynamic>;
        for (var entry in dailyData.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          }
        }
      }

      // 9. Restore Unfinished Activities
      if (userData.containsKey('unfinishedActivities')) {
        final activitiesData = userData['unfinishedActivities'] as Map<dynamic, dynamic>;
        for (var entry in activitiesData.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          }
        }
      }

      // 10. Restore Settings
      if (userData.containsKey('settings')) {
        final settingsData = userData['settings'] as Map<dynamic, dynamic>;
        for (var entry in settingsData.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          }
        }
      }

      // 11. Restore Lesson Progress
      if (userData.containsKey('lessonProgress')) {
        final lessonData = userData['lessonProgress'] as Map<dynamic, dynamic>;
        for (var entry in lessonData.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          }
        }
      }

      // 12. Restore Individual Quiz Sessions
      if (userData.containsKey('individualQuizSessions')) {
        final quizSessions = userData['individualQuizSessions'] as Map<dynamic, dynamic>;
        for (var entry in quizSessions.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is Map) {
            await prefs.setString(key, jsonEncode(value));
          }
        }
      }

      // 13. Restore Individual Story Sessions
      if (userData.containsKey('individualStorySessions')) {
        final storySessions = userData['individualStorySessions'] as Map<dynamic, dynamic>;
        for (var entry in storySessions.entries) {
          final key = entry.key as String;
          final value = entry.value;
          if (value is Map) {
            // Convert map back to string format for story sessions
            final sessionString = _convertMapToStorySessionString(value);
            await prefs.setString(key, sessionString);
          }
        }
      }
    } catch (e) {
      print('Error restoring comprehensive data: $e');
    }
  }

  // Merge Firebase data with local data, keeping the newer/more complete data
  Future<void> _mergeWithLocalData(
      Map<dynamic, dynamic> firebaseData, SharedPreferences prefs) async {
    try {
      print('Merging Firebase data with local data...');

      // For points and coins, use the higher value (user might have earned more locally)
      final localPoints = prefs.getInt('total_points') ?? 0;
      final firebasePoints = firebaseData['mojiPoints'] as int? ?? 0;
      if (localPoints > firebasePoints) {
        await prefs.setInt('total_points', localPoints);
        print('Keeping local points ($localPoints) over Firebase points ($firebasePoints)');
      }

      final localCoins = prefs.getInt('moji_coins') ?? 1000;
      final firebaseCoins = firebaseData['mojiCoins'] as int? ?? 1000;
      if (localCoins > firebaseCoins) {
        await prefs.setInt('moji_coins', localCoins);
        print('Keeping local coins ($localCoins) over Firebase coins ($firebaseCoins)');
      }

      // For individual sessions, merge both local and Firebase sessions
      await _mergeIndividualSessions(firebaseData, prefs);

      print('Data merge completed successfully');
    } catch (e) {
      print('Error merging data: $e');
    }
  }

  // Merge individual quiz and story sessions from both local and Firebase
  Future<void> _mergeIndividualSessions(
      Map<dynamic, dynamic> firebaseData, SharedPreferences prefs) async {
    try {
      // Merge quiz sessions
      if (firebaseData.containsKey('individualQuizSessions')) {
        final firebaseQuizSessions =
            firebaseData['individualQuizSessions'] as Map<dynamic, dynamic>;
        final allKeys = prefs.getKeys();
        final localQuizKeys = allKeys.where((key) => key.startsWith('quiz_result_')).toList();

        // Add any Firebase quiz sessions that don't exist locally
        for (var entry in firebaseQuizSessions.entries) {
          final key = entry.key as String;
          if (!localQuizKeys.contains(key)) {
            final value = entry.value;
            if (value is Map) {
              await prefs.setString(key, jsonEncode(value));
              print('Restored missing quiz session: $key');
            }
          }
        }
      }

      // Merge story sessions
      if (firebaseData.containsKey('individualStorySessions')) {
        final firebaseStorySessions =
            firebaseData['individualStorySessions'] as Map<dynamic, dynamic>;
        final allKeys = prefs.getKeys();
        final localStoryKeys = allKeys.where((key) => key.startsWith('story_session_')).toList();

        // Add any Firebase story sessions that don't exist locally
        for (var entry in firebaseStorySessions.entries) {
          final key = entry.key as String;
          if (!localStoryKeys.contains(key)) {
            final value = entry.value;
            if (value is Map) {
              final sessionString = _convertMapToStorySessionString(value);
              await prefs.setString(key, sessionString);
              print('Restored missing story session: $key');
            }
          }
        }
      }
    } catch (e) {
      print('Error merging individual sessions: $e');
    }
  }

  // Sync specific data types to Firebase
  Future<void> syncMojiPoints(int points) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the actual calculated total points from all sources
      final prefs = await SharedPreferences.getInstance();
      final actualTotalPoints = await _getTotalPoints(prefs);

      final userData = {
        'mojiPoints': actualTotalPoints, // Use calculated total, not just the passed points
        'lastUpdated': ServerValue.timestamp,
        'lastActive': ServerValue.timestamp,
      };

      if (_isOnline) {
        await _database.child('users').child(user.uid).update(userData);
        print('Successfully synced Moji Points: $actualTotalPoints (calculated from all sources)');
      } else {
        _queueSyncOperation('moji_points', userData);
      }
    } catch (e) {
      print('Error syncing Moji Points: $e');
    }
  }

  Future<void> syncMojiCoins(int coins) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userData = {
        'mojiCoins': coins,
        'lastUpdated': ServerValue.timestamp,
        'lastActive': ServerValue.timestamp,
      };

      if (_isOnline) {
        await _database.child('users').child(user.uid).update(userData);
        print('Successfully synced Moji Coins: $coins');
      } else {
        _queueSyncOperation('moji_coins', userData);
      }
    } catch (e) {
      print('Error syncing Moji Coins: $e');
    }
  }

  // Force sync current total points to Firebase
  Future<void> forceSyncCurrentPoints() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final currentTotalPoints = await _getTotalPoints(prefs);

      final userData = {
        'mojiPoints': currentTotalPoints,
        'lastUpdated': ServerValue.timestamp,
        'lastActive': ServerValue.timestamp,
      };

      if (_isOnline) {
        await _database.child('users').child(user.uid).update(userData);
        print('Force synced current total points: $currentTotalPoints');
      } else {
        _queueSyncOperation('force_points_sync', userData);
      }
    } catch (e) {
      print('Error force syncing current points: $e');
    }
  }

  // Get individual quiz sessions
  Future<Map<String, dynamic>> _getIndividualQuizSessions(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> sessions = {};
      final allKeys = prefs.getKeys();

      for (final key in allKeys) {
        if (key.startsWith('quiz_result_')) {
          final sessionData = prefs.getString(key);
          if (sessionData != null) {
            try {
              final parsedData = jsonDecode(sessionData);
              sessions[key] = parsedData;
            } catch (e) {
              print('Error parsing quiz session $key: $e');
            }
          }
        }
      }

      return sessions;
    } catch (e) {
      print('Error getting individual quiz sessions: $e');
      return {};
    }
  }

  // Get individual story sessions
  Future<Map<String, dynamic>> _getIndividualStorySessions(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> sessions = {};
      final allKeys = prefs.getKeys();

      for (final key in allKeys) {
        if (key.startsWith('story_session_')) {
          final sessionData = prefs.getString(key);
          if (sessionData != null) {
            try {
              // Story session data is stored as a string representation of a map
              // We need to parse it properly
              final parsedData = _parseStorySessionString(sessionData);
              sessions[key] = parsedData;
            } catch (e) {
              print('Error parsing story session $key: $e');
            }
          }
        }
      }

      return sessions;
    } catch (e) {
      print('Error getting individual story sessions: $e');
      return {};
    }
  }

  // Parse story session string data
  Map<String, dynamic> _parseStorySessionString(String sessionString) {
    try {
      // Remove the outer braces and split by comma
      final cleanString = sessionString.replaceAll('{', '').replaceAll('}', '');
      final pairs = cleanString.split(', ');
      final Map<String, dynamic> result = {};

      for (final pair in pairs) {
        final parts = pair.split(': ');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim();

          // Convert values to appropriate types
          if (key == 'score' ||
              key == 'correctAnswers' ||
              key == 'maxStreak' ||
              key == 'hintsUsed' ||
              key == 'livesRemaining' ||
              key == 'experiencePoints') {
            result[key] = int.tryParse(value) ?? 0;
          } else if (key == 'playerRank') {
            result[key] = double.tryParse(value) ?? 0.0;
          } else {
            result[key] = value.replaceAll("'", "").replaceAll('"', '');
          }
        }
      }

      return result;
    } catch (e) {
      print('Error parsing story session string: $e');
      return {};
    }
  }

  // Convert map back to story session string format
  String _convertMapToStorySessionString(Map<dynamic, dynamic> sessionData) {
    try {
      final List<String> pairs = [];

      for (var entry in sessionData.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        String valueString;
        if (value is String) {
          valueString = "'$value'";
        } else {
          valueString = value.toString();
        }

        pairs.add('$key: $valueString');
      }

      return '{${pairs.join(', ')}}';
    } catch (e) {
      print('Error converting map to story session string: $e');
      return '{}';
    }
  }

  // Set up real-time Firebase listeners
  void _setupRealtimeListeners() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No authenticated user - skipping listener setup');
        return;
      }

      // Check if we already have listeners for this user
      if (_currentListenerUid == user.uid) {
        print('Listeners already set up for user: ${user.uid}');
        return;
      }

      // Clear any existing listeners first
      clearUserData();

      print('Setting up Firebase listeners for user: ${user.uid}');

      // Listen to user data changes
      _userDataListener = _database.child('users').child(user.uid).onValue.listen((event) {
        if (event.snapshot.exists) {
          final userData = event.snapshot.value as Map<dynamic, dynamic>;
          print('Real-time user data update received for user: ${user.uid}');

          // Update local cache
          _cachedUserData = Map<String, dynamic>.from(userData);
          _lastUserDataSync = DateTime.now();

          // Optionally trigger UI updates or other actions
          _handleRealtimeUserDataUpdate(userData);
        }
      });

      // Listen to leaderboard changes
      _leaderboardListener = _database.child('leaderboard').child(user.uid).onValue.listen((event) {
        if (event.snapshot.exists) {
          final leaderboardData = event.snapshot.value as Map<dynamic, dynamic>;
          print('Real-time leaderboard update received for user: ${user.uid}');

          // Update local cache
          _cachedLeaderboardData = [Map<String, dynamic>.from(leaderboardData)];
          _lastLeaderboardSync = DateTime.now();

          // Optionally trigger UI updates
          _handleRealtimeLeaderboardUpdate(leaderboardData);
        }
      });

      // Track current user for listeners
      _currentListenerUid = user.uid;
      print('Real-time Firebase listeners set up successfully for user: ${user.uid}');
    } catch (e) {
      print('Error setting up real-time listeners: $e');
    }
  }

  // Handle real-time user data updates
  void _handleRealtimeUserDataUpdate(Map<dynamic, dynamic> userData) {
    try {
      // You can add custom logic here to handle real-time updates
      // For example, update UI, show notifications, etc.
      print('Handling real-time user data update: ${userData.keys}');

      // Check if moji points or coins changed
      if (userData.containsKey('mojiPoints')) {
        print('Moji points updated to: ${userData['mojiPoints']}');
      }
      if (userData.containsKey('mojiCoins')) {
        print('Moji coins updated to: ${userData['mojiCoins']}');
      }
    } catch (e) {
      print('Error handling real-time user data update: $e');
    }
  }

  // Handle real-time leaderboard updates
  void _handleRealtimeLeaderboardUpdate(Map<dynamic, dynamic> leaderboardData) {
    try {
      // You can add custom logic here to handle leaderboard updates
      print('Handling real-time leaderboard update: ${leaderboardData.keys}');
    } catch (e) {
      print('Error handling real-time leaderboard update: $e');
    }
  }

  // Get comprehensive user statistics (same as displayed in user stats screen)
  Future<Map<String, dynamic>> _getUserStatistics(SharedPreferences prefs) async {
    try {
      final Map<String, dynamic> stats = {};

      // 1. Total Points (calculated from all sources)
      stats['totalPoints'] = await _getTotalPoints(prefs);

      // 2. Character Mastery Levels
      final progressService = ProgressService();
      await progressService.initialize();
      stats['hiraganaMastery'] = progressService.getMasteryLevel('hiragana');
      stats['katakanaMastery'] = progressService.getMasteryLevel('katakana');
      stats['overallMastery'] = progressService.getOverallMasteryLevel();

      // 3. Quiz Statistics
      stats['quizStatistics'] = await _getQuizStatistics(prefs);

      // 4. Story Statistics
      stats['storyStatistics'] = await _getStoryStatistics(prefs);

      // 5. Streak Analytics
      stats['streakAnalytics'] = await _getStreakAnalytics();

      // 6. Daily Progress Statistics
      stats['dailyProgressStats'] = await _getDailyProgressStats(prefs);

      // 7. Challenge Statistics
      stats['challengeStatistics'] = await _getChallengeStatistics(prefs);

      // 8. Review Statistics
      stats['reviewStatistics'] = await _getReviewStatistics(prefs);

      // 9. Achievement Statistics
      stats['achievementStatistics'] = await _getAchievementStatistics(prefs);

      return stats;
    } catch (e) {
      print('Error getting user statistics: $e');
      return {};
    }
  }

  // Get quiz statistics (same logic as user stats screen)
  Future<Map<String, dynamic>> _getQuizStatistics(SharedPreferences prefs) async {
    try {
      final allKeys = prefs.getKeys();
      final quizResultKeys = allKeys.where((key) => key.startsWith('quiz_result_')).toList();

      if (quizResultKeys.isEmpty) {
        return {
          'totalQuizzes': 0,
          'averageScore': 0.0,
          'perfectScores': 0,
          'passedQuizzes': 0,
        };
      }

      int totalQuizzes = 0;
      double totalScore = 0.0;
      int perfectScores = 0;
      int passedQuizzes = 0;

      for (final key in quizResultKeys) {
        try {
          final resultString = prefs.getString(key);
          if (resultString != null) {
            final result = jsonDecode(resultString);
            final passed = result['passed'] ?? false;
            final percentage = result['percentage'] ?? 0.0;

            if (passed) {
              totalQuizzes++;
              totalScore += percentage;
              passedQuizzes++;

              if (percentage == 100.0) {
                perfectScores++;
              }
            }
          }
        } catch (e) {
          continue;
        }
      }

      final averageScore = totalQuizzes > 0 ? totalScore / totalQuizzes : 0.0;

      return {
        'totalQuizzes': totalQuizzes,
        'averageScore': averageScore,
        'perfectScores': perfectScores,
        'passedQuizzes': passedQuizzes,
      };
    } catch (e) {
      return {
        'totalQuizzes': 0,
        'averageScore': 0.0,
        'perfectScores': 0,
        'passedQuizzes': 0,
      };
    }
  }

  // Get story statistics (same logic as user stats screen)
  Future<Map<String, dynamic>> _getStoryStatistics(SharedPreferences prefs) async {
    try {
      final totalStoryPoints = prefs.getInt('story_total_points') ?? 0;
      final allKeys = prefs.getKeys();
      final storySessionKeys = allKeys.where((key) => key.startsWith('story_session_')).toList();
      final sessionCount = storySessionKeys.length;

      double averageScore = 0.0;
      if (sessionCount > 0) {
        averageScore = totalStoryPoints / sessionCount;
      }

      return {
        'totalPoints': totalStoryPoints,
        'sessionCount': sessionCount,
        'averageScore': averageScore,
      };
    } catch (e) {
      return {
        'totalPoints': 0,
        'sessionCount': 0,
        'averageScore': 0.0,
      };
    }
  }

  // Get streak analytics
  Future<Map<String, dynamic>> _getStreakAnalytics() async {
    try {
      final streakService = StreakAnalyticsService();
      final stats = await streakService.getStreakStatistics();
      final overallPercentage = stats['overallPercentage'] ?? 0.0;
      final performanceLevel = streakService.getStreakPerformanceLevel(overallPercentage);
      final performanceColor = streakService.getStreakPerformanceColor(overallPercentage);

      return {
        ...stats,
        'performanceLevel': performanceLevel,
        'performanceColor': performanceColor,
      };
    } catch (e) {
      return {
        'overallPercentage': 0.0,
        'challengePercentage': 0.0,
        'reviewPercentage': 0.0,
        'performanceLevel': 'Needs Improvement',
        'performanceColor': 0xFFF44336,
      };
    }
  }

  // Get daily progress statistics
  Future<Map<String, dynamic>> _getDailyProgressStats(SharedPreferences prefs) async {
    try {
      final dailyPointsService = DailyPointsService();
      final lastClaimTime = await dailyPointsService.getLastClaimTime();
      final streakBonusMultiplier = await dailyPointsService.getStreakBonusMultiplier();
      final dailyGoal = prefs.getInt('daily_goal') ?? 30;
      final minutesStudied = prefs.getInt('study_minutes') ?? 0;

      return {
        'lastClaimTime': lastClaimTime?.toIso8601String(),
        'streakBonusMultiplier': streakBonusMultiplier,
        'dailyGoal': dailyGoal,
        'minutesStudied': minutesStudied,
        'dailyProgressPercentage':
            minutesStudied > 0 ? (minutesStudied / dailyGoal).clamp(0.0, 1.0) * 100 : 0.0,
      };
    } catch (e) {
      return {
        'lastClaimTime': null,
        'streakBonusMultiplier': 1.0,
        'dailyGoal': 30,
        'minutesStudied': 0,
        'dailyProgressPercentage': 0.0,
      };
    }
  }

  // Get challenge statistics
  Future<Map<String, dynamic>> _getChallengeStatistics(SharedPreferences prefs) async {
    try {
      final challengeService = ChallengeProgressService();
      final totalPoints = await challengeService.getTotalPoints();
      final allKeys = prefs.getKeys();

      int totalChallenges = 0;
      int completedChallenges = 0;
      final completedTopics = <String>{};

      for (final key in allKeys) {
        if (key.startsWith('completed_challenges_')) {
          final topicId = key.replaceFirst('completed_challenges_', '');
          final completedList = prefs.getStringList(key) ?? [];
          totalChallenges += completedList.length;
          completedChallenges += completedList.length;
          if (completedList.isNotEmpty) {
            completedTopics.add(topicId);
          }
        }
      }

      return {
        'totalPoints': totalPoints,
        'totalChallenges': totalChallenges,
        'completedChallenges': completedChallenges,
        'completedTopics': completedTopics.length,
        'completionRate': totalChallenges > 0 ? (completedChallenges / totalChallenges) * 100 : 0.0,
      };
    } catch (e) {
      return {
        'totalPoints': 0,
        'totalChallenges': 0,
        'completedChallenges': 0,
        'completedTopics': 0,
        'completionRate': 0.0,
      };
    }
  }

  // Get review statistics
  Future<Map<String, dynamic>> _getReviewStatistics(SharedPreferences prefs) async {
    try {
      final reviewService = ReviewProgressService();
      final totalPoints = await reviewService.getTotalReviewPoints();
      final allKeys = prefs.getKeys();

      int totalReviews = 0;
      int completedReviews = 0;
      final completedCategories = <String>{};

      for (final key in allKeys) {
        if (key.startsWith('review_completed_')) {
          final categoryId = key.replaceFirst('review_completed_', '');
          final isCompleted = prefs.getBool(key) ?? false;
          totalReviews++;
          if (isCompleted) {
            completedReviews++;
            completedCategories.add(categoryId);
          }
        }
      }

      return {
        'totalPoints': totalPoints,
        'totalReviews': totalReviews,
        'completedReviews': completedReviews,
        'completedCategories': completedCategories.length,
        'completionRate': totalReviews > 0 ? (completedReviews / totalReviews) * 100 : 0.0,
      };
    } catch (e) {
      return {
        'totalPoints': 0,
        'totalReviews': 0,
        'completedReviews': 0,
        'completedCategories': 0,
        'completionRate': 0.0,
      };
    }
  }

  // Get achievement statistics
  Future<Map<String, dynamic>> _getAchievementStatistics(SharedPreferences prefs) async {
    try {
      // Calculate achievements based on progress milestones
      final progressService = ProgressService();
      await progressService.initialize();
      final userProgress = progressService.getUserProgress();

      final achievements = <String>[];

      // Level-based achievements
      if (userProgress.level >= 5) achievements.add('Level 5 Reached');
      if (userProgress.level >= 10) achievements.add('Level 10 Reached');
      if (userProgress.level >= 25) achievements.add('Level 25 Reached');

      // Streak-based achievements
      if (userProgress.currentStreak >= 7) achievements.add('7 Day Streak');
      if (userProgress.currentStreak >= 30) achievements.add('30 Day Streak');
      if (userProgress.longestStreak >= 100) achievements.add('100 Day Streak Master');

      // XP-based achievements
      if (userProgress.totalXp >= 1000) achievements.add('1000 XP Earned');
      if (userProgress.totalXp >= 5000) achievements.add('5000 XP Earned');
      if (userProgress.totalXp >= 10000) achievements.add('10000 XP Master');

      // Mastery-based achievements
      final hiraganaMastery = userProgress.getMasteryLevel('hiragana');
      final katakanaMastery = userProgress.getMasteryLevel('katakana');
      if (hiraganaMastery >= 0.8) achievements.add('Hiragana Master');
      if (katakanaMastery >= 0.8) achievements.add('Katakana Master');
      if (userProgress.getOverallMasteryLevel() >= 0.9) achievements.add('Overall Master');

      return {
        'totalAchievements': achievements.length,
        'recentAchievements': achievements,
        'hasRecentAchievements': achievements.isNotEmpty,
      };
    } catch (e) {
      return {
        'totalAchievements': 0,
        'recentAchievements': [],
        'hasRecentAchievements': false,
      };
    }
  }

  // Get real-time user data from Firebase
  Future<Map<String, dynamic>?> getRealtimeUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Check cache first
      if (_cachedUserData != null && _lastUserDataSync != null) {
        final cacheAge = DateTime.now().difference(_lastUserDataSync!);
        if (cacheAge < _cacheExpiry) {
          print('Returning cached user data (age: ${cacheAge.inSeconds}s)');
          return _cachedUserData!;
        }
      }

      // Fetch fresh data from Firebase
      final snapshot = await _database.child('users').child(user.uid).get();
      if (snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);

        // Update cache
        _cachedUserData = userData;
        _lastUserDataSync = DateTime.now();

        print('Fetched fresh user data from Firebase');
        return userData;
      }

      return null;
    } catch (e) {
      print('Error getting real-time user data: $e');
      return null;
    }
  }

  // Get real-time leaderboard data from Firebase
  Future<Map<String, dynamic>?> getRealtimeLeaderboardData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Check cache first
      if (_cachedLeaderboardData != null && _lastLeaderboardSync != null) {
        final cacheAge = DateTime.now().difference(_lastLeaderboardSync!);
        if (cacheAge < _cacheExpiry) {
          print('Returning cached leaderboard data (age: ${cacheAge.inSeconds}s)');
          return _cachedLeaderboardData!.isNotEmpty ? _cachedLeaderboardData!.first : null;
        }
      }

      // Fetch fresh data from Firebase
      final snapshot = await _database.child('leaderboard').child(user.uid).get();
      if (snapshot.exists) {
        final leaderboardData = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);

        // Update cache
        _cachedLeaderboardData = [leaderboardData];
        _lastLeaderboardSync = DateTime.now();

        print('Fetched fresh leaderboard data from Firebase');
        return leaderboardData;
      }

      return null;
    } catch (e) {
      print('Error getting real-time leaderboard data: $e');
      return null;
    }
  }

  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _userDataListener?.cancel();
    _leaderboardListener?.cancel();
  }
}
