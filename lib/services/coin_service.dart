import 'package:flutter/foundation.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoinService {
  // Singleton pattern
  static final CoinService _instance = CoinService._internal();

  factory CoinService() {
    return _instance;
  }

  CoinService._internal();

  // Key for storing coins in SharedPreferences
  static const String _coinsKey = 'moji_coins';

  // Default coin amount
  static const int _defaultCoins = 1000;

  // Reset service (useful when user changes)
  void reset() {
    print('CoinService reset for user change');
  }

  // Get current coin balance
  Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_coinsKey) ?? _defaultCoins;
  }

  // Update coin balance
  Future<void> updateCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt(_coinsKey) ?? _defaultCoins;
    final newTotal = currentCoins + amount;
    await prefs.setInt(_coinsKey, newTotal);

    // Sync to Firebase
    final firebaseSync = FirebaseUserSyncService();
    await firebaseSync.syncMojiCoins(newTotal);
  }

  // Set coin balance to a specific amount
  Future<void> setCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coinsKey, amount);

    // Sync to Firebase
    final firebaseSync = FirebaseUserSyncService();
    await firebaseSync.syncMojiCoins(amount);
  }

  // Spend coins (returns true if successful, false if not enough coins)
  Future<bool> spendCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt(_coinsKey) ?? _defaultCoins;

    if (currentCoins >= amount) {
      final newTotal = currentCoins - amount;
      await prefs.setInt(_coinsKey, newTotal);

      // Sync to Firebase
      final firebaseSync = FirebaseUserSyncService();
      await firebaseSync.syncMojiCoins(newTotal);

      return true;
    }

    return false;
  }

  // Add coins to balance
  Future<void> addCoins(int amount) async {
    debugPrint('CoinService.addCoins called with amount: $amount');
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt(_coinsKey) ?? _defaultCoins;
    debugPrint('Current coins before adding: $currentCoins');
    final newTotal = currentCoins + amount;
    await prefs.setInt(_coinsKey, newTotal);
    debugPrint('New total coins: $newTotal');

    // Sync to Firebase
    final firebaseSync = FirebaseUserSyncService();
    await firebaseSync.syncMojiCoins(newTotal);
  }

  // Deduct coins (same as spendCoins for consistency)
  Future<bool> deductCoins(int amount) async {
    return await spendCoins(amount);
  }
}
