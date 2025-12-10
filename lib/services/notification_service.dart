import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/widgets/custom_notification.dart';

class NotificationService {
  static void showSuccess(BuildContext context, String message) {
    CustomNotification.show(
      context,
      message: message,
      icon: Icons.check_circle,
      color: Colors.green,
    );
  }

  static void showInfo(BuildContext context, String message) {
    CustomNotification.show(
      context,
      message: message,
      icon: Icons.info,
      color: Colors.blue,
    );
  }

  static void showWarning(BuildContext context, String message) {
    CustomNotification.show(
      context,
      message: message,
      icon: Icons.warning,
      color: Colors.orange,
    );
  }

  static void showError(BuildContext context, String message) {
    CustomNotification.show(
      context,
      message: message,
      icon: Icons.error,
      color: Colors.red,
    );
  }

  static void showXpGained(BuildContext context, int xp) {
    CustomNotification.show(
      context,
      message: '+$xp XP gained!',
      icon: Icons.star,
      color: Colors.amber.shade700,
    );
  }

  static void showProgressUpdate(BuildContext context, String message) {
    CustomNotification.show(
      context,
      message: message,
      icon: Icons.trending_up,
      color: Colors.purple,
    );
  }

  static void showGoalCompleted(BuildContext context) {
    CustomNotification.show(
      context,
      message: 'Daily goal completed! Great job!',
      icon: Icons.emoji_events,
      color: Colors.green.shade700,
      duration: const Duration(seconds: 4),
    );
  }

  static void showStreakUpdate(BuildContext context, int streak) {
    CustomNotification.show(
      context,
      message: '$streak day streak! Keep it up! 🔥',
      icon: Icons.local_fire_department,
      color: Colors.deepOrange,
      duration: const Duration(seconds: 4),
    );
  }
}

