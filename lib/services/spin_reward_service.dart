import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/spin_reward.dart';

class SpinRewardService {
  /// Get the list of available spin rewards
  List<SpinReward> getSpinRewards() {
    return [
      SpinReward(
        name: '50 Moji Points',
        type: SpinRewardType.points,
        description: '50 Moji Points!',
        color: Colors.amber.shade500,
        iconName: 'star_rounded',
        japaneseText: 'ポイント',
      ),
      SpinReward(
        name: '100 Moji Points',
        type: SpinRewardType.points,
        description: '100 Moji Points!',
        color: Colors.orange.shade600,
        iconName: 'stars_rounded',
        japaneseText: 'ポイント',
      ),
      SpinReward(
        name: '200 Moji Points',
        type: SpinRewardType.points,
        description: '200 Moji Points!',
        color: Colors.deepOrange.shade500,
        iconName: 'auto_awesome_rounded',
        japaneseText: 'ポイント',
      ),
      SpinReward(
        name: 'Surprise Gift',
        type: SpinRewardType.premium,
        description: 'A special surprise gift awaits you!',
        color: Colors.purple.shade500,
        iconName: 'card_giftcard_rounded',
        japaneseText: 'プレゼント',
      ),
      SpinReward(
        name: 'Learning Ticket',
        type: SpinRewardType.lesson,
        description: 'Unlock a premium lesson of your choice!',
        color: Colors.teal.shade500,
        iconName: 'confirmation_number_rounded',
        japaneseText: 'チケット',
      ),
      SpinReward(
        name: '1 Moji Coins',
        type: SpinRewardType.points,
        description: '1 Moji Coins!',
        color: Colors.blue.shade500,
        iconName: 'toll_rounded',
        japaneseText: 'コイン',
      ),
      SpinReward(
        name: '5 Moji Coins',
        type: SpinRewardType.points,
        description: 'Add 5 Moji Coins to your balance!',
        color: Colors.indigo.shade500,
        iconName: 'toll_rounded',
        japaneseText: 'コイン',
      ),
      SpinReward(
        name: 'Speed Boost',
        type: SpinRewardType.booster,
        description: 'Learn 2x faster for the next 30 minutes!',
        color: Colors.green.shade500,
        iconName: 'speed_rounded',
        japaneseText: 'ブースター',
      ),
    ];
  }
  
  /// Get a random reward of a specific type
  SpinReward getRandomRewardByType(SpinRewardType type) {
    final rewardsOfType = getSpinRewards().where((r) => r.type == type).toList();
    final random = DateTime.now().millisecondsSinceEpoch % rewardsOfType.length;
    return rewardsOfType[random];
  }
  
  /// Get a random reward of any type
  SpinReward getRandomReward() {
    final allRewards = getSpinRewards();
    final random = DateTime.now().millisecondsSinceEpoch % allRewards.length;
    return allRewards[random];
  }
  
  /// Get the category name for a reward type
  String getRewardCategory(SpinRewardType type) {
    switch (type) {
      case SpinRewardType.booster:
        return 'Boosters';
      case SpinRewardType.powerup:
        return 'Power-ups';
      case SpinRewardType.lesson:
        return 'Tickets';
      case SpinRewardType.premium:
        return 'Special';
      default:
        return 'Special';
    }
  }
  
  /// Get a tip message for a reward type
  String getRewardTip(SpinRewardType type) {
    switch (type) {
      case SpinRewardType.kanji:
        return 'Practice writing these kanji daily for better retention!';
      case SpinRewardType.lesson:
        return 'Take notes and practice with native audio for best results!';
      case SpinRewardType.theme:
        return 'Change themes in settings to activate your new look!';
      case SpinRewardType.vocabulary:
        return 'Use these words in example sentences to remember them better!';
      case SpinRewardType.powerup:
        return 'Perfect time to tackle those challenging lessons!';
      case SpinRewardType.booster:
        return 'Review immediately to maximize your learning streak!';
      case SpinRewardType.premium:
        return 'Explore all features and save your favorites!';
      case SpinRewardType.points:
        return 'Moji Points are automatically added to your total!';
      default:
        return 'Use this reward to enhance your learning experience!';
    }
  }
} 