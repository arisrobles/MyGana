import 'package:flutter/material.dart';

class Progress {
  final int totalLessonsCompleted;
  final int totalLessons;
  final int streak;
  final int dailyGoalMinutes;
  final int minutesStudiedToday;
  final List<LessonProgress> recentLessons;
  final DateTime lastStudyDate;
  final int totalXp;
  final int level;

  Progress({
    required this.totalLessonsCompleted,
    required this.totalLessons,
    required this.streak,
    required this.dailyGoalMinutes,
    required this.minutesStudiedToday,
    required this.recentLessons,
    required this.lastStudyDate,
    required this.totalXp,
    required this.level,
  });

  double get dailyGoalProgress => 
      dailyGoalMinutes > 0 ? (minutesStudiedToday / dailyGoalMinutes).clamp(0.0, 1.0) : 0.0;
  
  double get overallProgress => 
      totalLessons > 0 ? (totalLessonsCompleted / totalLessons).clamp(0.0, 1.0) : 0.0;

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      totalLessonsCompleted: json['totalLessonsCompleted'] ?? 0,
      totalLessons: json['totalLessons'] ?? 100,
      streak: json['streak'] ?? 0,
      dailyGoalMinutes: json['dailyGoalMinutes'] ?? 15,
      minutesStudiedToday: json['minutesStudiedToday'] ?? 0,
      lastStudyDate: json['lastStudyDate'] != null 
          ? DateTime.parse(json['lastStudyDate']) 
          : DateTime.now(),
      recentLessons: json['recentLessons'] != null
          ? List<LessonProgress>.from(
              json['recentLessons'].map((x) => LessonProgress.fromJson(x)))
          : [],
      totalXp: json['totalXp'] ?? 0,
      level: json['level'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalLessonsCompleted': totalLessonsCompleted,
      'totalLessons': totalLessons,
      'streak': streak,
      'dailyGoalMinutes': dailyGoalMinutes,
      'minutesStudiedToday': minutesStudiedToday,
      'lastStudyDate': lastStudyDate.toIso8601String(),
      'recentLessons': recentLessons.map((x) => x.toJson()).toList(),
      'totalXp': totalXp,
      'level': level,
    };
  }

  Progress copyWith({
    int? totalLessonsCompleted,
    int? totalLessons,
    int? streak,
    int? dailyGoalMinutes,
    int? minutesStudiedToday,
    List<LessonProgress>? recentLessons,
    DateTime? lastStudyDate,
    int? totalXp,
    int? level,
  }) {
    return Progress(
      totalLessonsCompleted: totalLessonsCompleted ?? this.totalLessonsCompleted,
      totalLessons: totalLessons ?? this.totalLessons,
      streak: streak ?? this.streak,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      minutesStudiedToday: minutesStudiedToday ?? this.minutesStudiedToday,
      recentLessons: recentLessons ?? this.recentLessons,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
    );
  }
}

class LessonProgress {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final double progress;
  final DateTime lastAccessed;

  LessonProgress({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.progress,
    required this.lastAccessed,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      iconName: json['iconName'] ?? 'translate',
      progress: json['progress']?.toDouble() ?? 0.0,
      lastAccessed: json['lastAccessed'] != null 
          ? DateTime.parse(json['lastAccessed']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconName': iconName,
      'progress': progress,
      'lastAccessed': lastAccessed.toIso8601String(),
    };
  }

  IconData getIcon() {
    switch (iconName) {
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'format_list_numbered':
        return Icons.format_list_numbered;
      case 'translate':
        return Icons.translate;
      case 'school':
        return Icons.school;
      case 'edit':
        return Icons.edit;
      default:
        return Icons.book;
    }
  }
}
