class ReviewCategory {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String color;

  ReviewCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
    };
  }

  factory ReviewCategory.fromMap(Map<String, dynamic> map) {
    return ReviewCategory(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      icon: map['icon'],
      color: map['color'],
    );
  }
}

class ReviewCategories {
  static List<Map<String, dynamic>> getCategories() {
    return [
      {
        'id': 'greetings',
        'name': 'Greetings',
        'description': 'Basic Japanese greetings and introductions',
        'icon': 'greetings',
        'color': '#4CAF50',
      },
      {
        'id': 'basic_nouns',
        'name': 'Basic Nouns',
        'description': 'Common everyday objects and places',
        'icon': 'basic_nouns',
        'color': '#2196F3',
      },
      {
        'id': 'basic_verbs',
        'name': 'Basic Verbs',
        'description': 'Essential Japanese verbs',
        'icon': 'basic_verbs',
        'color': '#FF9800',
      },
      {
        'id': 'basic_adjectives',
        'name': 'Basic Adjectives',
        'description': 'Common descriptive words',
        'icon': 'basic_adjectives',
        'color': '#9C27B0',
      },
      {
        'id': 'time_expressions',
        'name': 'Time Expressions',
        'description': 'Words related to time and dates',
        'icon': 'time_expressions',
        'color': '#E91E63',
      },
    ];
  }
} 