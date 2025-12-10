import 'package:flutter/material.dart';

enum SpinRewardType {
  kanji,
  lesson,
  theme,
  badge,
  booster,
  premium,
  vocabulary,
  powerup,
  points
}

class SpinReward {
  final String name;
  final SpinRewardType type;
  final String description;
  final Color color;
  final String iconName;
  final String? japaneseText;

  SpinReward({
    required this.name,
    required this.type,
    required this.description,
    required this.color,
    required this.iconName,
    this.japaneseText,
  });
  
  IconData get icon {
    switch (iconName) {
      case 'star_rounded':
        return Icons.star_rounded;
      case 'stars_rounded':
        return Icons.stars_rounded;
      case 'auto_awesome_rounded':
        return Icons.auto_awesome_rounded;
      case 'card_giftcard_rounded':
        return Icons.card_giftcard_rounded;
      case 'confirmation_number_rounded':
        return Icons.confirmation_number_rounded;
      case 'monetization_on_rounded':
        return Icons.monetization_on_rounded;
      case 'payments_rounded':
        return Icons.payments_rounded;
      case 'speed_rounded':
        return Icons.speed_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
} 