import 'package:flutter/material.dart';

class InventoryItem {
  final String name;
  final String description;
  final String iconName;
  final Color color;
  final DateTime obtainedDate;
  final bool isUsed;
  final String type;
  final int count;

  InventoryItem({
    required this.name,
    required this.description,
    required this.iconName,
    required this.color,
    required this.obtainedDate,
    required this.isUsed,
    required this.type,
    this.count = 1,
  });

  InventoryItem copyWith({
    String? name,
    String? description,
    String? iconName,
    Color? color,
    DateTime? obtainedDate,
    bool? isUsed,
    String? type,
    int? count,
  }) {
    return InventoryItem(
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      obtainedDate: obtainedDate ?? this.obtainedDate,
      isUsed: isUsed ?? this.isUsed,
      type: type ?? this.type,
      count: count ?? this.count,
    );
  }

  IconData getIconData() {
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
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      case 'celebration_rounded':
        return Icons.celebration_rounded;
      case 'diamond_rounded':
        return Icons.diamond_rounded;
      case 'palette_rounded':
        return Icons.palette_rounded;
      case 'school_rounded':
        return Icons.school_rounded;
      case 'record_voice_over_rounded':
        return Icons.record_voice_over_rounded;
      case 'edit_rounded':
        return Icons.edit_rounded;
      case 'hearing_rounded':
        return Icons.hearing_rounded;
      case 'toll_rounded':
        return Icons.toll_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'iconName': iconName,
      'color': color.value,
      'obtainedDate': obtainedDate.toIso8601String(),
      'isUsed': isUsed,
      'type': type,
      'count': count,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name'],
      description: json['description'],
      iconName: json['iconName'],
      color: Color(json['color']),
      obtainedDate: DateTime.parse(json['obtainedDate']),
      isUsed: json['isUsed'],
      type: json['type'],
      count: json['count'] ?? 1,
    );
  }
}