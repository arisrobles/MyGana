import 'package:flutter/material.dart';
// Removed app bar/theme actions for minimal mobile view
import 'admin_quiz_screen.dart';

class AdminQuizManagementScreen extends StatelessWidget {
  const AdminQuizManagementScreen({super.key});

  final List<String> levels = const ['Beginner', 'Intermediate', 'Advanced'];

  // Theme icon logic removed with the app bar

  Color _getLevelColor(String level, BuildContext context) {
    switch (level) {
      case 'Beginner':
        return Colors.green;
      case 'Intermediate':
        return Colors.orange;
      case 'Advanced':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Beginner':
        return Icons.school;
      case 'Intermediate':
        return Icons.auto_stories;
      case 'Advanced':
        return Icons.psychology;
      default:
        return Icons.book;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 1200),
          margin: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : isTablet ? 24 : 16,
          ),
          child: ListView.builder(
            padding: EdgeInsets.only(
              top: isDesktop ? 40 : isTablet ? 28 : 16,
              bottom: isDesktop ? 32 : isTablet ? 24 : 16,
            ),
            itemCount: levels.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  margin: EdgeInsets.only(bottom: isDesktop ? 40 : isTablet ? 32 : 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.quiz,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quiz Management',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isDesktop ? 32 : isTablet ? 28 : 24,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Select a level to manage quiz categories and quizzes',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              final levelIndex = index - 1;
              final level = levels[levelIndex];
              final cardColor = _getLevelColor(level, context);
              final levelIcon = _getLevelIcon(level);

              return Container(
                margin: EdgeInsets.only(bottom: isDesktop ? 24 : isTablet ? 20 : 16),
                child: Hero(
                  tag: 'admin_quiz_level_card_$level',
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cardColor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminQuizLevelScreen(
                                level: level,
                                cardColor: cardColor,
                                icon: levelIcon,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 28 : 24),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      cardColor,
                                      cardColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cardColor.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  levelIcon,
                                  color: Colors.white,
                                  size: isDesktop ? 40 : isTablet ? 36 : 32,
                                ),
                              ),
                              SizedBox(width: isDesktop ? 28 : isTablet ? 24 : 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      level,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
                                        color: cardColor,
                                      ),
                                    ),
                                    SizedBox(height: isDesktop ? 12 : isTablet ? 10 : 8),
                                    Text(
                                      'Manage quizzes for $level level students',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey[600],
                                        fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                                      ),
                                    ),
                                    SizedBox(height: isDesktop ? 20 : isTablet ? 16 : 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: cardColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.arrow_forward,
                                            color: cardColor,
                                            size: isDesktop ? 20 : isTablet ? 18 : 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Tap to manage',
                                            style: TextStyle(
                                              color: cardColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: isDesktop ? 14 : isTablet ? 12 : 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: cardColor,
                                  size: isDesktop ? 24 : isTablet ? 20 : 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AdminQuizLevelScreen extends StatelessWidget {
  final String level;
  final Color cardColor;
  final IconData icon;

  const AdminQuizLevelScreen({
    super.key,
    required this.level,
    required this.cardColor,
    required this.icon,
  });

  final List<String> categories = const [
    'Hiragana',
    'Katakana',
    'Kanji',
    'Grammar',
    'Vocabulary',
    'Listening',
    'Reading',
    'Writing',
    'Culture',
    'General'
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;
    final crossAxisCount = isDesktop ? 3 : isTablet ? 2 : 1;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Quiz Management - $level'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardColor,
                cardColor.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cardColor.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 1200),
          margin: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : isTablet ? 24 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(
                  top: isDesktop ? 120 : isTablet ? 100 : 80,
                  bottom: isDesktop ? 32 : isTablet ? 24 : 16,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cardColor,
                                cardColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quiz Categories - $level',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
                                  color: cardColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select a category to manage quizzes',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: isDesktop ? 24 : isTablet ? 20 : 16,
                    mainAxisSpacing: isDesktop ? 24 : isTablet ? 20 : 16,
                    childAspectRatio: isDesktop ? 1.2 : isTablet ? 1.1 : 1.0,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Hero(
                      tag: 'admin_quiz_category_card_${level}_$category',
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.9),
                                Colors.white.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cardColor.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminQuizScreen(
                                    level: level,
                                    category: category,
                                    cardColor: cardColor,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isDesktop ? 20 : isTablet ? 16 : 12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          cardColor,
                                          cardColor.withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cardColor.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: Colors.white,
                                      size: isDesktop ? 40 : isTablet ? 36 : 32,
                                    ),
                                  ),
                                  SizedBox(height: isDesktop ? 20 : isTablet ? 16 : 12),
                                  Text(
                                    category,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                                      color: cardColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: isDesktop ? 12 : isTablet ? 8 : 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: cardColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Manage $category quizzes',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                        fontSize: isDesktop ? 14 : isTablet ? 12 : 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Hiragana':
        return Icons.abc;
      case 'Katakana':
        return Icons.text_fields;
      case 'Kanji':
        return Icons.text_format;
      case 'Grammar':
        return Icons.rule;
      case 'Vocabulary':
        return Icons.book;
      case 'Listening':
        return Icons.hearing;
      case 'Reading':
        return Icons.menu_book;
      case 'Writing':
        return Icons.edit;
      case 'Culture':
        return Icons.celebration;
      case 'General':
        return Icons.quiz;
      default:
        return Icons.category;
    }
  }
}
