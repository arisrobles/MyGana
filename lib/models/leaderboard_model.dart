class LeaderboardEntry {
  final String userId;
  final String username;
  final String avatarUrl;
  final int level;
  final int totalXp;
  final int rank;
  final String rankBadge;
  final DateTime lastActive;
  final int streak;
  final List<String> recentAchievements;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.level,
    required this.totalXp,
    required this.rank,
    required this.rankBadge,
    required this.lastActive,
    required this.streak,
    required this.recentAchievements,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['userId'] ?? '',
      username: json['username'] ?? 'Anonymous',
      avatarUrl: json['avatarUrl'] ?? '',
      level: json['level'] ?? 1,
      totalXp: json['totalXp'] ?? 0,
      rank: json['rank'] ?? 1,
      rankBadge: json['rankBadge'] ?? 'Bronze',
      lastActive: json['lastActive'] != null ? DateTime.parse(json['lastActive']) : DateTime.now(),
      streak: json['streak'] ?? 0,
      recentAchievements: List<String>.from(json['recentAchievements'] ?? []),
      isCurrentUser: json['isCurrentUser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'level': level,
      'totalXp': totalXp,
      'rank': rank,
      'rankBadge': rankBadge,
      'lastActive': lastActive.toIso8601String(),
      'streak': streak,
      'recentAchievements': recentAchievements,
      'isCurrentUser': isCurrentUser,
    };
  }

  // Get rank badge color
  String get rankBadgeColor {
    switch (rankBadge.toLowerCase()) {
      case 'diamond':
        return '#00FFFF'; // Cyan
      case 'platinum':
        return '#E5E4E2'; // Platinum
      case 'gold':
        return '#FFD700'; // Gold
      case 'silver':
        return '#C0C0C0'; // Silver
      case 'bronze':
        return '#CD7F32'; // Bronze
      default:
        return '#8B4513'; // Brown
    }
  }

  // Get rank badge icon
  String get rankBadgeIcon {
    switch (rankBadge.toLowerCase()) {
      case 'diamond':
        return '💎';
      case 'platinum':
        return '🏆';
      case 'gold':
        return '🥇';
      case 'silver':
        return '🥈';
      case 'bronze':
        return '🥉';
      default:
        return '⭐';
    }
  }

  // Calculate rank badge based on level
  static String calculateRankBadge(int level) {
    if (level >= 50) return 'Diamond';
    if (level >= 25) return 'Platinum';
    if (level >= 15) return 'Gold';
    if (level >= 8) return 'Silver';
    if (level >= 3) return 'Bronze';
    return 'Rookie';
  }

  // Get time since last active
  String get timeSinceActive {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Copy with method for creating modified instances
  LeaderboardEntry copyWith({
    String? userId,
    String? username,
    String? avatarUrl,
    int? level,
    int? totalXp,
    int? rank,
    String? rankBadge,
    DateTime? lastActive,
    int? streak,
    List<String>? recentAchievements,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      level: level ?? this.level,
      totalXp: totalXp ?? this.totalXp,
      rank: rank ?? this.rank,
      rankBadge: rankBadge ?? this.rankBadge,
      lastActive: lastActive ?? this.lastActive,
      streak: streak ?? this.streak,
      recentAchievements: recentAchievements ?? this.recentAchievements,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}

class LeaderboardData {
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;
  final int totalUsers;
  final DateTime lastUpdated;

  LeaderboardData({
    required this.entries,
    this.currentUserEntry,
    required this.totalUsers,
    required this.lastUpdated,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    return LeaderboardData(
      entries: (json['entries'] as List).map((entry) => LeaderboardEntry.fromJson(entry)).toList(),
      currentUserEntry: json['currentUserEntry'] != null
          ? LeaderboardEntry.fromJson(json['currentUserEntry'])
          : null,
      totalUsers: json['totalUsers'] ?? 0,
      lastUpdated:
          json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'currentUserEntry': currentUserEntry?.toJson(),
      'totalUsers': totalUsers,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
