import 'package:shared_preferences/shared_preferences.dart';

class DailyPointsService {
  static const String _lastClaimKey = 'last_daily_claim';
  static const String _streakKey = 'daily_points_streak';
// Base points for daily claim
  
  // Get the last claim timestamp
  Future<DateTime?> getLastClaimTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaimMillis = prefs.getInt(_lastClaimKey);
    return lastClaimMillis != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastClaimMillis)
        : null;
  }
  
  // Check if user can claim daily points
  Future<bool> canClaimDailyPoints() async {
    final lastClaimTime = await getLastClaimTime();
    if (lastClaimTime == null) return true;
    
    final now = DateTime.now();
    final timeSinceLastClaim = now.difference(lastClaimTime);
    return timeSinceLastClaim.inHours >= 24;
  }
  
  // Get time until next claim is available
  Future<Duration> getTimeUntilNextClaim() async {
    final lastClaim = await getLastClaimTime();
    if (lastClaim == null) return Duration.zero;
    
    final now = DateTime.now();
    final nextClaim = lastClaim.add(const Duration(hours: 24));
    return nextClaim.difference(now);
  }
  
  // Get current streak
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }
  
  // Claim daily points
  Future<void> claimDailyPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastClaimTime = await getLastClaimTime();
    
    // Update streak
    if (lastClaimTime != null) {
      final timeSinceLastClaim = now.difference(lastClaimTime);
      final currentStreak = await getCurrentStreak();
      
      if (timeSinceLastClaim.inHours <= 48) { // Within 48 hours
        await prefs.setInt(_streakKey, currentStreak + 1);
      } else {
        await prefs.setInt(_streakKey, 1); // Reset streak
      }
    } else {
      await prefs.setInt(_streakKey, 1); // First claim
    }
    
    // Update last claim time
    await prefs.setInt(_lastClaimKey, now.millisecondsSinceEpoch);
  }
  
  // Get streak bonus multiplier
  Future<double> getStreakBonusMultiplier() async {
    final streak = await getCurrentStreak();
    if (streak >= 3) return 2.0; // 2x multiplier for 3+ day streak
    if (streak >= 2) return 1.5; // 1.5x multiplier for 2 day streak
    return 1.0; // No multiplier for 0-1 day streak
  }
} 