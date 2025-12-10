import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/challenge_screen.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';

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

class ChallengeTopicScreen extends StatefulWidget {
  const ChallengeTopicScreen({super.key});

  @override
  State<ChallengeTopicScreen> createState() => _ChallengeTopicScreenState();
}

class _ChallengeTopicScreenState extends State<ChallengeTopicScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ChallengeProgressService _progressService = ChallengeProgressService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<ChallengeTopic> _filterTopicsByLevel(List<ChallengeTopic> topics, String level) {
    return topics.where((topic) => topic.id.contains(level)).toList();
  }

  Widget _buildSectionHeader(String title, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isFirst ? 16 : 32, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.8),
                  Theme.of(context).primaryColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsList(List<ChallengeTopic> topics, int baseIndex) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        final delay = (baseIndex + index) * 0.2;
        
        return FutureBuilder<Map<String, dynamic>>(
          future: _getTopicProgress(topic.id),
          builder: (context, snapshot) {
            final progress = snapshot.data ?? {
              'completedChallenges': 0,
              'score': 0,
              'streak': 0,
            };
            
            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      (delay * 0.5).clamp(0.0, 1.0),
                      ((delay * 0.5) + 0.4).clamp(0.0, 1.0),
                      curve: Curves.easeOutBack,
                    ),
                  ),
                );

                return Transform.translate(
                  offset: Offset(0, 50 * (1 - animation.value)),
                  child: Opacity(
                    opacity: animation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Hero(
                tag: 'topic-${topic.id}',
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shadowColor: topic.color.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () async {
                      // Save recent activity before navigating
                      await _progressService.saveRecentActivity(
                        topic.id,
                        'challenge',
                      );
                      
                      if (!mounted) return;
                      
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => ChallengeScreen(
                            initialChallengeId: '${topic.id}-1',
                            topicId: topic.id,
                            topicColor: topic.color,
                          ),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOutCubic;
                            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                            var offsetAnimation = animation.drive(tween);
                            return SlideTransition(position: offsetAnimation, child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            topic.color.withOpacity(0.1),
                            topic.color.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        topic.color.withOpacity(0.2),
                                        topic.color.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: topic.color.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    topic.icon,
                                    color: topic.color,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        topic.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        topic.description,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: topic.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios,
                                    color: topic.color,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: progress['completedChallenges'] / topic.totalChallenges,
                                          minHeight: 8,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(topic.color),
                                        ),
                                      ),
                                      if (progress['completedChallenges'] > 0)
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: ShaderMask(
                                              shaderCallback: (bounds) {
                                                return LinearGradient(
                                                  colors: [
                                                    topic.color.withOpacity(0.5),
                                                    topic.color,
                                                  ],
                                                ).createShader(bounds);
                                              },
                                              child: Container(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: topic.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: topic.color.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    '${progress['completedChallenges']}/${topic.totalChallenges}',
                                    style: TextStyle(
                                      color: topic.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (progress['score'] > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.amber.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.stars, size: 16, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${progress['score']}',
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (progress['streak'] > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '${progress['streak']}x',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            '🔥',
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getTopicProgress(String topicId) async {
    final completedChallenges = await _progressService.getCompletedChallengesForTopic(topicId);
    final score = await _progressService.getTopicScore(topicId);
    final streak = await _progressService.getTopicStreak(topicId);
    
    return {
      'completedChallenges': completedChallenges.length,
      'score': score,
      'streak': streak,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Japanese Learning'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseService().getChallengeTopics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final topics = snapshot.data?.map((map) => ChallengeTopic.fromMap(map)).toList() ?? [];

          if (topics.isEmpty) {
            return const Center(
              child: Text('No challenge topics available'),
            );
          }

          // Filter topics by level
          final basicTopics = _filterTopicsByLevel(topics, 'basic');
          final intermediateTopics = _filterTopicsByLevel(topics, 'inter');
          final advancedTopics = _filterTopicsByLevel(topics, 'adv');

          // Start the animation when data is loaded
          _animationController.forward();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Basic', isFirst: true),
                _buildTopicsList(basicTopics, 0),
                _buildSectionHeader('Intermediate'),
                _buildTopicsList(intermediateTopics, basicTopics.length),
                _buildSectionHeader('Advanced'),
                _buildTopicsList(advancedTopics, basicTopics.length + intermediateTopics.length),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
} 