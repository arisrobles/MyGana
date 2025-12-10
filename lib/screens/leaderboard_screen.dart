import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/leaderboard_model.dart';
import 'package:nihongo_japanese_app/services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  LeaderboardData? _leaderboardData;
  Stream<LeaderboardData>? _leaderboardStream;

  @override
  void initState() {
    super.initState();
    _initializeLeaderboard();
  }

  void _initializeLeaderboard() {
    // Start with loading cached data
    _loadLeaderboard();
    
    // Set up real-time stream with error handling
    try {
      _leaderboardStream = _leaderboardService.watchLeaderboard();
      _leaderboardStream!.listen(
        (data) {
          if (mounted) {
            setState(() {
              _leaderboardData = data;
              _isLoading = false;
              _hasError = false;
              _errorMessage = null;
            });
          }
        },
        onError: (error) {
          print('Leaderboard stream error: $error');
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = error.toString();
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Error setting up leaderboard stream: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      print('Loading leaderboard data...');
      final data = await _leaderboardService.getLeaderboard();
      print('Leaderboard data loaded: ${data.entries.length} entries');
      if (mounted) {
      setState(() {
        _leaderboardData = data;
        _isLoading = false;
      });
      }
    } catch (e) {
      print('Error loading leaderboard: $e');
      if (mounted) {
      setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        _isLoading = false;
      });
      }
    }
  }

  Future<void> _refreshLeaderboard() async {
    try {
      final data = await _leaderboardService.refreshFromFirebase();
      if (mounted) {
        setState(() {
          _leaderboardData = data;
          _hasError = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1419) : const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Leaderboard',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
              size: 20,
            ),
            onPressed: _refreshLeaderboard,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(isDarkMode, primaryColor)
          : _hasError
              ? _buildErrorState(isDarkMode, primaryColor)
          : _leaderboardData == null
                  ? _buildEmptyState(isDarkMode, primaryColor)
              : RefreshIndicator(
                      onRefresh: _refreshLeaderboard,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(context, isDarkMode, primaryColor),
                            const SizedBox(height: 20),
                        _buildTopThree(context, isDarkMode, primaryColor),
                            const SizedBox(height: 20),
                        _buildLeaderboardList(context, isDarkMode, primaryColor),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading rankings...',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 24,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load rankings',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _loadLeaderboard,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.leaderboard_outlined,
                size: 24,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No rankings available',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _loadLeaderboard,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, bool isDarkMode, Color primaryColor) {
    final currentUser = _leaderboardData!.currentUserEntry;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1D29) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
              children: [
                Container(
              width: 48,
              height: 48,
                  decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ],
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
                  Row(
                    children: [
                      Text(
                        'Your Rank',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Connection status indicator
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _leaderboardData!.entries.isNotEmpty 
                              ? Colors.green 
                              : Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_leaderboardData!.entries.isNotEmpty 
                                  ? Colors.green 
                                  : Colors.orange).withOpacity(0.7),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: (_leaderboardData!.entries.isNotEmpty 
                                  ? Colors.green 
                                  : Colors.orange).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${currentUser?.rank ?? 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            currentUser?.rankBadgeIcon ?? '⭐',
                        style: const TextStyle(fontSize: 14),
                          ),
                      const SizedBox(width: 4),
                          Text(
                            currentUser?.rankBadge ?? 'Rookie',
                            style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Level ${currentUser?.level ?? 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                    Text(
                      '${currentUser?.totalXp ?? 0} XP',
                      style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopThree(BuildContext context, bool isDarkMode, Color primaryColor) {
    final topThree = _leaderboardData!.entries.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: primaryColor,
              size: 18,
            ),
            const SizedBox(width: 6),
        Text(
          'Top Performers',
          style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (topThree.length > 1) ...[
              Expanded(
                child: _buildPodiumCard(
                  context,
                  isDarkMode,
                  topThree[1],
                  2,
                  const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (topThree.isNotEmpty) ...[
              Expanded(
                child: _buildPodiumCard(
                  context,
                  isDarkMode,
                  topThree[0],
                  1,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (topThree.length > 2) ...[
              Expanded(
                child: _buildPodiumCard(
                  context,
                  isDarkMode,
                  topThree[2],
                  3,
                  const Color(0xFFCD7F32),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPodiumCard(
    BuildContext context,
    bool isDarkMode,
    LeaderboardEntry entry,
    int position,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1D29) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: position == 1 
              ? color.withOpacity(0.8) 
              : (isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
          width: position == 1 ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Position indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Center(
              child: position == 1
                  ? const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Username
          Text(
            entry.username,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDarkMode ? Colors.white : Colors.grey[800],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Level and XP
          Text(
            'Level ${entry.level}',
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${entry.totalXp} XP',
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Rank badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.rankBadgeIcon,
                  style: const TextStyle(fontSize: 10),
              ),
                const SizedBox(width: 2),
              Text(
                entry.rankBadge,
                style: TextStyle(
                    fontSize: 9,
                    color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.list_alt_rounded,
              color: primaryColor,
              size: 18,
            ),
            const SizedBox(width: 6),
        Text(
              'All Rankings',
          style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _leaderboardData!.entries.length,
          itemBuilder: (context, index) {
            final entry = _leaderboardData!.entries[index];
            return _buildLeaderboardItem(context, isDarkMode, entry, index + 1);
          },
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    bool isDarkMode,
    LeaderboardEntry entry,
    int rank,
  ) {
    final primaryColor = Theme.of(context).primaryColor;
    final isCurrentUser = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? primaryColor.withOpacity(0.12)
            : (isDarkMode ? const Color(0xFF1A1D29) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser 
              ? primaryColor.withOpacity(0.5) 
              : (isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
          width: isCurrentUser ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          if (isCurrentUser)
            BoxShadow(
              color: primaryColor.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getRankColor(rank).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getRankColor(rank).withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getRankColor(rank).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: _getRankColor(rank).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _getRankColor(rank),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar placeholder
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCurrentUser 
                  ? primaryColor.withOpacity(0.2) 
                  : (isDarkMode ? Colors.grey[600] : Colors.grey[300]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCurrentUser 
                    ? primaryColor.withOpacity(0.7) 
                    : (isDarkMode ? Colors.grey[500]! : Colors.grey[400]!),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                if (isCurrentUser)
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
              ],
            ),
            child: Icon(
              Icons.person_rounded,
              color: isCurrentUser 
                  ? primaryColor 
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[500]),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lv.${entry.level}',
                        style: TextStyle(
                          fontSize: 10,
                          color: primaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        '${entry.totalXp} XP',
                        style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF3B82F6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      entry.rankBadgeIcon,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      entry.rankBadge,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.access_time_rounded,
                      size: 10,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      entry.timeSinceActive,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Streak indicator
          if (entry.streak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orange,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.streak}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey[400]!;
    if (rank == 3) return Colors.orange[700]!;
    return Colors.grey[600]!;
  }

  @override
  void dispose() {
    // Stream will be automatically disposed when the widget is disposed
    super.dispose();
  }
}

