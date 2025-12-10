import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/daily_points_service.dart';
import 'package:nihongo_japanese_app/services/review_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyConversionService {
  static const String _totalPointsKey = 'total_points';
  static const String _totalCoinsKey = 'total_coins';

  // Conversion rate: 700 Moji Points = 1 Moji Coin
  static const int _defaultConversionRate = 700;
  static const int _minPointsForConversion = 700;

  // Get the current conversion rate
  Future<int> getConversionRate() async {
    return _defaultConversionRate;
  }

  // Get minimum points required for conversion
  int getMinimumPointsForConversion() {
    return _minPointsForConversion;
  }

  // Check if user can convert points today (always true now)
  Future<bool> canConvertToday() async {
    return true; // Always allow conversion
  }

  // Get total available points from all sources
  Future<int> getTotalAvailablePoints() async {
    return await Future.wait([
      // Challenge points from ChallengeProgressService
      ChallengeProgressService().getTotalPoints(),
      // Review points from ReviewProgressService
      ReviewProgressService().getTotalReviewPoints(),
      // Story points from SharedPreferences (if any)
      SharedPreferences.getInstance().then((prefs) => prefs.getInt('story_total_points') ?? 0),
      // Quiz points from SharedPreferences (if any)
      SharedPreferences.getInstance().then((prefs) => prefs.getInt('quiz_total_points') ?? 0),
      // Daily points from DailyPointsService
      DailyPointsService().getLastClaimTime().then((lastClaim) async {
        if (lastClaim == null) return 0;
        final multiplier = await DailyPointsService().getStreakBonusMultiplier();
        return (100 * multiplier).round(); // Daily points amount
      }),
    ]).then((results) => results.fold<int>(0, (sum, points) => sum + points));
  }

  // Convert Moji Points to Moji Coins
  Future<Map<String, int>> convertPointsToCoins(int pointsToConvert) async {
    final prefs = await SharedPreferences.getInstance();

    // Get current points from all sources
    final currentPoints = await getTotalAvailablePoints();
    final currentCoins = prefs.getInt(_totalCoinsKey) ?? 0;

    // Validate conversion
    if (pointsToConvert < _minPointsForConversion) {
      throw Exception('Minimum conversion amount is $_minPointsForConversion Moji Points');
    }

    if (pointsToConvert > currentPoints) {
      throw Exception('Insufficient Moji Points. You have $currentPoints points available.');
    }

    // Calculate coins to add
    final coinsToAdd = (pointsToConvert / _defaultConversionRate).floor();

    // Update points and coins
    // We only update the stored points in SharedPreferences
    final storedPoints = prefs.getInt(_totalPointsKey) ?? 0;
    final newStoredPoints = storedPoints - pointsToConvert;
    final newCoins = currentCoins + coinsToAdd;

    // Save updated values
    await prefs.setInt(_totalPointsKey, newStoredPoints);
    await prefs.setInt(_totalCoinsKey, newCoins);

    // Return conversion details
    return {
      'pointsDeducted': pointsToConvert,
      'coinsAdded': coinsToAdd,
    };
  }
}
