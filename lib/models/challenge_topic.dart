import 'package:flutter/material.dart';

class ChallengeTopic {
  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color color;
  final int totalChallenges;
  final int completedChallenges;

  ChallengeTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.totalChallenges,
    required this.completedChallenges,
  });

  factory ChallengeTopic.fromMap(Map<String, dynamic> map) {
    return ChallengeTopic(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      icon: _getIconFromName(map['icon_name'] as String),
      color: _getColorFromString(map['color'] as String),
      totalChallenges: map['total_challenges'] as int,
      completedChallenges: map['completed_challenges'] as int,
    );
  }

  static IconData _getIconFromName(String name) {
    switch (name) {
      case 'brush':
        return Icons.brush;
      case 'translate':
        return Icons.translate;
      case 'book':
        return Icons.book;
      case 'school':
        return Icons.school;
      default:
        return Icons.extension;
    }
  }

  static Color _getColorFromString(String colorString) {
    switch (colorString) {
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'green':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  double get progress => completedChallenges / totalChallenges;
} 