import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/inventory_item.dart';
import 'package:nihongo_japanese_app/models/kanji.dart';
import 'package:nihongo_japanese_app/services/inventory_service.dart';
import 'package:nihongo_japanese_app/services/coin_service.dart';
import 'package:flutter/services.dart';
import 'package:nihongo_japanese_app/screens/lessons_screen.dart';

class ShopService {
  static final List<ShopItem> _shopItems = [
    ShopItem(
      name: 'Speed Boost',
      description: 'Double your learning speed for 1 hour!',
      iconName: 'speed_rounded',
      color: Colors.green.shade500,
      type: 'Boosters',
      price: 100,
      japaneseText: 'スピードブースト',
      effectData: {'duration': 3600}, // 1 hour in seconds
    ),
    ShopItem(
      name: 'Power Surge',
      description: 'Instantly complete a challenge!',
      iconName: 'local_fire_department_rounded',
      color: Colors.blue.shade500,
      type: 'Power-ups',
      price: 150,
      japaneseText: 'パワーサージ',
      effectData: {'challengeId': 'default_challenge'},
    ),
    ShopItem(
      name: 'Lesson Ticket',
      description: 'Unlock a special Business Japanese lesson pack!',
      iconName: 'confirmation_number_rounded',
      color: Colors.teal.shade500,
      type: 'Tickets',
      price: 200,
      japaneseText: 'レッスンチケット',
      effectData: {
        'lessonPack': LessonPack(
          id: 'business_japanese',
          name: 'Business Japanese',
          vocabulary: [
            {'word': '会議', 'reading': 'kaigi', 'meaning': 'meeting'},
            {'word': '提案', 'reading': 'teian', 'meaning': 'proposal'},
          ],
          grammar: ['～させていただきます'],
        ),
      },
    ),
    ShopItem(
      name: 'Kanji Pack',
      description: 'Unlock a set of advanced kanji!',
      iconName: 'auto_awesome_rounded',
      color: Colors.deepPurple.shade500,
      type: 'Tickets',
      price: 250,
      japaneseText: '漢字パック',
      effectData: {
        'kanji': [
          Kanji(
            character: '鑑',
            onYomi: ['kan'],
            kunYomi: ['kagami'],
            meaning: 'appraisal, mirror',
            examples: [
              {'word': '鑑定', 'reading': 'kantei', 'meaning': 'appraisal'},
            ],
          ),
          Kanji(
            character: '繋',
            onYomi: ['kei'],
            kunYomi: ['tsuna-gu'],
            meaning: 'connect',
            examples: [
              {'word': '接続', 'reading': 'setsuzoku', 'meaning': 'connection'},
            ],
          ),
          Kanji(
            character: '謙',
            onYomi: ['ken'],
            kunYomi: [],
            meaning: 'humility',
            examples: [
              {'word': '謙虚', 'reading': 'kenkyo', 'meaning': 'humble'},
            ],
          ),
        ],
      },
    ),
  ];

  List<ShopItem> getShopItems() => _shopItems;

  List<ShopItem> getItemsByCategory(String category) {
    if (category == 'All') return _shopItems;
    return _shopItems.where((item) => item.type == category).toList();
  }
}

class ShopItem {
  final String name;
  final String description;
  final String iconName;
  final Color color;
  final String type;
  final int price;
  final String japaneseText;
  final Map<String, dynamic> effectData;

  ShopItem({
    required this.name,
    required this.description,
    required this.iconName,
    required this.color,
    required this.type,
    required this.price,
    required this.japaneseText,
    required this.effectData,
  });

  IconData get icon => InventoryItem(iconName: iconName, name: name, description: description, color: color, type: type, obtainedDate: DateTime.now(), isUsed: false).getIconData();

  InventoryItem toInventoryItem() {
    return InventoryItem(
      name: name,
      description: description,
      iconName: iconName,
      color: color,
      type: type,
      obtainedDate: DateTime.now(),
      isUsed: false,
      count: 1,
    );
  }
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  final CoinService _coinService = CoinService();
  final ShopService _shopService = ShopService();
  bool _isLoading = false;
  String _selectedCategory = 'All';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<String> _categories = const [
    'All',
    'Boosters',
    'Power-ups',
    'Tickets',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _purchaseItem(ShopItem item) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final success = await _coinService.spendCoins(item.price);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Not enough Moji Coins!'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              action: SnackBarAction(
                label: 'Get Coins',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushNamed(context, '/coin_purchase');
                },
              ),
            ),
          );
        }
        return;
      }

      final inventoryItem = item.toInventoryItem();
      await _inventoryService.addItem(inventoryItem);
      await _inventoryService.applyItemEffect(item, context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Purchased ${item.name} for ${item.price} Moji Coins!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );

        // Navigate to LessonsScreen when a Lesson Ticket is purchased
        if (item.name == 'Lesson Ticket') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LessonsScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error purchasing item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error purchasing item: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPurchaseConfirmation(ShopItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        title: const Text('Confirm Purchase', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Buy ${item.name} for ${item.price} Moji Coins?'),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _coinService.getCoins(),
              builder: (context, snapshot) {
                return Text(
                  'Balance: ${snapshot.data ?? 0} Moji Coins',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchaseItem(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: item.color,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(ShopItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final colorScheme = Theme.of(context).colorScheme;
        
        return StatefulBuilder(
          builder: (context, setState) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.color.withOpacity(0.2),
                        item.color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          item.icon,
                          size: 80,
                          color: item.color,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        item.japaneseText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Effects',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildEffectList(item.effectData, isDarkMode),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Price',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/images/coin.png',
                                        width: 20,
                                        height: 20,
                                        color: Colors.amber,
                                        colorBlendMode: BlendMode.modulate,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${item.price}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showPurchaseConfirmation(item);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: item.color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Purchase',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEffectList(Map<String, dynamic> effectData, bool isDarkMode) {
    final List<Widget> effectWidgets = [];

    effectData.forEach((key, value) {
      String effectText = '';
      if (key == 'duration') {
        final hours = value ~/ 3600;
        effectText = 'Duration: $hours hour${hours > 1 ? 's' : ''}';
      } else if (key == 'challengeId') {
        effectText = 'Effect: Instantly complete a challenge';
      } else if (key == 'lessonPack') {
        effectText = 'Effect: Unlock special lesson pack';
      } else if (key == 'kanji') {
        effectText = 'Effect: Unlock ${(value as List).length} new kanji';
      }

      if (effectText.isNotEmpty) {
        effectWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  effectText,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: effectWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width >= 360 && screenSize.width < 600;
    
    // Calculate responsive dimensions
    final horizontalPadding = isSmallScreen ? 12.0 : isMediumScreen ? 16.0 : 24.0;
    final verticalPadding = isSmallScreen ? 12.0 : isMediumScreen ? 16.0 : 24.0;
    final cardSpacing = isSmallScreen ? 12.0 : isMediumScreen ? 16.0 : 24.0;
    final iconSize = isSmallScreen ? 20.0 : isMediumScreen ? 24.0 : 28.0;
    final titleFontSize = isSmallScreen ? 18.0 : isMediumScreen ? 20.0 : 24.0;
    final subtitleFontSize = isSmallScreen ? 12.0 : isMediumScreen ? 14.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Moji Shop',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            fontFamily: "TheLastShuriken",
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          FutureBuilder<int>(
            future: _coinService.getCoins(),
            builder: (context, snapshot) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/coin.png',
                      width: iconSize * 0.6,
                      height: iconSize * 0.6,
                      color: Colors.amber,
                      colorBlendMode: BlendMode.modulate,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 8),
                    Text(
                      '${snapshot.data ?? 0}',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: colorScheme.primary,
        backgroundColor: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated header with celebration icon
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_cart_rounded,
                            color: colorScheme.primary,
                            size: iconSize,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shop',
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              Text(
                                'Purchase items with your Moji Coins!',
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: cardSpacing),
                
                // Limited offer section with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: isSmallScreen ? 12 : 16),
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade500,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Limited Offer: 20% off Kanji Pack!',
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 4 : 8),
                              Text(
                                'Unlock advanced kanji characters',
                                style: TextStyle(
                                  fontSize: subtitleFontSize * 0.8,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final kanjiPack = _shopService.getShopItems().firstWhere((item) => item.name == 'Kanji Pack');
                            _showItemDetails(kanjiPack);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange.shade600,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Shop Now',
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: cardSpacing),
                
                // Category filters with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4),
                          child: FilterChip(
                            label: Row(
                              children: [
                                _getCategoryIcon(category),
                                SizedBox(width: isSmallScreen ? 2 : 4),
                                Text(
                                  category,
                                  style: TextStyle(fontSize: subtitleFontSize),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: colorScheme.primary.withOpacity(0.1),
                            checkmarkColor: colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? colorScheme.primary
                                  : isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: cardSpacing),
                
                // Items grid with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: _isLoading
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(cardSpacing * 2),
                            child: CircularProgressIndicator(color: colorScheme.primary),
                          ),
                        )
                      : _buildCategoryView(
                          _shopService.getItemsByCategory(_selectedCategory),
                          _selectedCategory,
                          isDarkMode,
                          isSmallScreen,
                          isMediumScreen,
                        ),
                ),
                SizedBox(height: cardSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryView(List<ShopItem> items, String category, bool isDarkMode, bool isSmallScreen, bool isMediumScreen) {
    if (items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(category),
              size: isSmallScreen ? 60 : 80,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              'No ${category.toLowerCase()} available',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Check back later for new items!',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 1 : 2,
        crossAxisSpacing: isSmallScreen ? 12 : 16,
        mainAxisSpacing: isSmallScreen ? 12 : 16,
        childAspectRatio: isSmallScreen ? 1.2 : 0.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 6,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
            child: InkWell(
              onTap: () => _showItemDetails(item),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isDarkMode ? Colors.grey[800]! : Colors.white,
                          Color.fromRGBO(item.color.red, item.color.green, item.color.blue, 0.1),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Color.fromRGBO(item.color.red, item.color.green, item.color.blue, 0.3),
                                borderRadius: const BorderRadius.all(Radius.circular(16)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromRGBO(item.color.red, item.color.green, item.color.blue, 0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                item.icon,
                                color: item.color,
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item.japaneseText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[100],
                                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      border: Border.all(color: Colors.amber[300]!),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.monetization_on,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${item.price}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _showPurchaseConfirmation(item);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: item.color,
                                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                                      ),
                                      child: const Text(
                                        'Buy',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SizedBox(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: item.type == 'Tickets' ? Colors.red : Colors.blue,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            _getBadgeText(item.type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getBadgeText(String type) {
    switch (type) {
      case 'Boosters':
        return 'Boost!';
      case 'Power-ups':
        return 'Power!';
      case 'Tickets':
        return 'Lesson!';
      default:
        return 'New!';
    }
  }

  IconData _getEmptyIcon(String category) {
    switch (category) {
      case 'Boosters':
        return Icons.speed_rounded;
      case 'Power-ups':
        return Icons.local_fire_department_rounded;
      case 'Tickets':
        return Icons.confirmation_number_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'All':
        return const Icon(Icons.grid_view_rounded, size: 20);
      case 'Boosters':
        return const Icon(Icons.speed_rounded, size: 20);
      case 'Power-ups':
        return const Icon(Icons.local_fire_department_rounded, size: 20);
      case 'Tickets':
        return const Icon(Icons.confirmation_number_rounded, size: 20);
      default:
        return const Icon(Icons.category_rounded, size: 20);
    }
  }
}