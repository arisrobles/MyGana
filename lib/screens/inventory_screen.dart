import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/inventory_item.dart';
import 'package:nihongo_japanese_app/services/inventory_service.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:nihongo_japanese_app/screens/lessons_screen.dart';
import 'dart:async';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  
  final InventoryService _inventoryService = InventoryService();
  List<InventoryItem> _inventoryItems = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasActiveSpeedBoost = false;
  int _speedBoostRemainingTime = 0;
  Timer? _speedBoostTimer;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  // Sound effects
  static const String _useItemSound = 'sounds/use_item.mp3';
  static const String _openItemSound = 'sounds/open_item.mp3';
  static const String _boostActiveSound = 'sounds/boost_active.mp3';

  final List<String> _categories = [
    'All',
    'Boosters',
    'Power-ups',
    'Tickets',
    'Special',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInventory();
    _checkActiveSpeedBoost();
  }

  void _initializeControllers() {
    _tabController = TabController(length: _categories.length, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadInventory() async {
    if (_isRefreshing) return;
    
    setState(() => _isLoading = true);
    try {
      final items = await _inventoryService.loadInventory();
      if (mounted) {
        setState(() {
          _inventoryItems = items;
          _isLoading = false;
        });
        _scaleController.forward();
      }
    } catch (e) {
      debugPrint('Error loading inventory: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load inventory. Please try again.');
      }
    }
  }

  Future<void> _refreshInventory() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    try {
      final items = await _inventoryService.loadInventory();
      if (mounted) {
        setState(() {
          _inventoryItems = items;
          _isRefreshing = false;
        });
        _showSuccessSnackBar('Inventory refreshed successfully!');
      }
    } catch (e) {
      debugPrint('Error refreshing inventory: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
        _showErrorSnackBar('Failed to refresh inventory.');
      }
    }
  }

  Future<void> _playSound(String soundAsset) async {
    try {
      await _audioPlayer.play(AssetSource(soundAsset));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> _checkActiveSpeedBoost() async {
    final multiplier = _inventoryService.getXpMultiplier();
    final remainingTime = _inventoryService.getSpeedBoostRemainingTime();
    
    if (mounted) {
      setState(() {
        _hasActiveSpeedBoost = multiplier > 1;
        _speedBoostRemainingTime = remainingTime;
      });
    }

    if (_hasActiveSpeedBoost) {
      _speedBoostTimer?.cancel();
      _speedBoostTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final remainingTime = _inventoryService.getSpeedBoostRemainingTime();
        if (remainingTime <= 0) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _hasActiveSpeedBoost = false;
              _speedBoostRemainingTime = 0;
            });
            _showInfoSnackBar('Speed boost has expired!');
          }
        } else if (mounted) {
          setState(() {
            _speedBoostRemainingTime = remainingTime;
          });
        }
      });
    }
  }

  Future<void> _useItem(InventoryItem item, int count) async {
    try {
      final normalizedItem = item.copyWith(name: _inventoryService.normalizeName(item.name));
      await _inventoryService.useItem(normalizedItem, count);
      
      // Haptic and audio feedback
      HapticFeedback.mediumImpact();
      await _playSound(_useItemSound);
      
      // Reload data
      await _loadInventory();
      await _checkActiveSpeedBoost();

      if (mounted) {
        String effectMessage = '';
        Color effectColor = Colors.green;
        IconData effectIcon = Icons.check_circle;
        
        if (normalizedItem.name == 'Speed Boost') {
          effectMessage = 'XP multiplier is now active!';
          effectColor = Colors.green;
          effectIcon = Icons.speed_rounded;
          await _playSound(_boostActiveSound);
        } else if (normalizedItem.name == 'Lesson Ticket') {
          effectMessage = 'New lesson pack unlocked!';
          effectColor = Colors.blue;
          effectIcon = Icons.school_rounded;
        } else if (normalizedItem.name == 'Kanji Pack') {
          effectMessage = 'New kanji characters unlocked!';
          effectColor = Colors.purple;
          effectIcon = Icons.translate_rounded;
        }

        _showEnhancedSnackBar(
          'Used $count ${normalizedItem.name}${count > 1 ? 's' : ''}',
          effectMessage,
          effectColor,
          effectIcon,
        );

        // Navigate to LessonsScreen when a Lesson Ticket is used
        if (normalizedItem.name == 'Lesson Ticket') {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LessonsScreen()),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error using item: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to use item. Please try again.');
      }
    }
  }

  void _showEnhancedSnackBar(String title, String effectMessage, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (effectMessage.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    effectMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<InventoryItem> _getItemsByCategory(String category) {
    debugPrint('Filtering items for category: $category');

    final normalizedItems = _getNormalizedItems();
    
    // Apply search filter first
    List<InventoryItem> searchFiltered = normalizedItems;
    if (_searchQuery.isNotEmpty) {
      searchFiltered = normalizedItems.where((item) {
        final normalizedName = _inventoryService.normalizeName(item.name).toLowerCase();
        return normalizedName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Then apply category filter
    final filteredItems = searchFiltered.where((item) {
      if (category == 'All') return true;
      return item.type == category;
    }).toList();

    debugPrint('Found ${filteredItems.length} items in category $category');
    return filteredItems;
  }

  List<InventoryItem> _getNormalizedItems() {
    final Map<String, InventoryItem> uniqueItems = {};
    final Map<String, int> itemCounts = {};

    for (var item in _inventoryItems) {
      if (item.isUsed) continue;

      final normalizedName = _inventoryService.normalizeName(item.name);
      final key = '${normalizedName}_${item.type}';

      if (!uniqueItems.containsKey(key)) {
        uniqueItems[key] = item.copyWith(name: normalizedName);
        itemCounts[key] = item.count;
      } else {
        itemCounts[key] = (itemCounts[key] ?? 0) + item.count;
      }
    }

    final List<InventoryItem> result = [];
    uniqueItems.forEach((key, item) {
      final count = itemCounts[key] ?? 1;
      final itemWithCount = item.copyWith(count: count);
      result.add(itemWithCount);
    });

    return result;
  }

  void _showItemDetails(InventoryItem item) {
    _playSound(_openItemSound);
    HapticFeedback.lightImpact();

    final normalizedName = _inventoryService.normalizeName(item.name);
    String displayName = normalizedName;
    if (normalizedName.contains('Points')) {
      displayName = normalizedName.replaceAll('Points', 'Moji Points');
    } else if (normalizedName.contains('Coins')) {
      displayName = normalizedName.replaceAll('Coins', 'Moji Coins');
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: item.color.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(
              color: item.color.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon with rotation
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 2000),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          item.color.withOpacity(0.1),
                          item.color.withOpacity(0.3),
                          item.color.withOpacity(0.1),
                        ],
                        stops: [0, value, 1],
                        transform: GradientRotation(value * 3 * 3.14),
                      ),
                    ),
                    child: Transform.rotate(
                      angle: value * 0.1,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  item.getIconData(),
                  color: item.color,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              
              // Item name with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    item.color,
                    item.color.withOpacity(0.7),
                    item.color,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  transform: const GradientRotation(3.14 / 4),
                ).createShader(bounds),
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.color.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              if (normalizedName == 'Lesson Ticket' || normalizedName == 'Kanji Pack')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Effect applied during purchase',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              
              // Item details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Obtained: ${_formatDate(item.obtainedDate)}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Quantity: ${item.count}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  void _showUseItemDialog(InventoryItem item) {
    int useCount = 1;

    final normalizedName = _inventoryService.normalizeName(item.name);
    String displayName = normalizedName;
    if (normalizedName.contains('Points')) {
      displayName = normalizedName.replaceAll('Points', 'Moji Points');
    } else if (normalizedName.contains('Coins')) {
      displayName = normalizedName.replaceAll('Coins', 'Moji Coins');
    }

    String effectDescription = '';
    IconData effectIcon = Icons.info_outline;
    Color effectColor = Colors.blue;

    switch (normalizedName) {
      case 'Speed Boost':
        effectDescription = 'Doubles your XP gain for 1 hour';
        effectIcon = Icons.speed_rounded;
        effectColor = Colors.green;
        break;
      case 'Power Surge':
        effectDescription = 'Instantly completes a challenge';
        effectIcon = Icons.flash_on_rounded;
        effectColor = Colors.orange;
        break;
      case 'Lesson Ticket':
        effectDescription = 'Unlocks a special lesson pack';
        effectIcon = Icons.school_rounded;
        effectColor = Colors.teal;
        break;
      case 'Kanji Pack':
        effectDescription = 'Unlocks new kanji characters';
        effectIcon = Icons.translate_rounded;
        effectColor = Colors.purple;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: item.color.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.getIconData(),
                    color: item.color,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Use $displayName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: effectColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(effectIcon, color: effectColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          effectDescription,
                          style: TextStyle(
                            color: effectColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'How many would you like to use?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.color.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 32,
                        color: useCount > 1 ? item.color : Colors.grey,
                        onPressed: useCount > 1
                            ? () => setState(() => useCount--)
                            : null,
                      ),
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(
                          '$useCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 32,
                        color: useCount < item.count ? item.color : Colors.grey,
                        onPressed: useCount < item.count
                            ? () => setState(() => useCount++)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Available: ${item.count}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _useItem(item, useCount);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Use'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: item.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _speedBoostTimer?.cancel();
    _tabController.dispose();
    _audioPlayer.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeController,
              child: const Text(
                'My Inventory',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'TheLastShuriken'
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isRefreshing ? 0.8 : 1.0,
                  child: Icon(
                    _isRefreshing ? Icons.hourglass_empty : Icons.refresh_rounded,
                    color: _isRefreshing ? Colors.grey : null,
                  ),
                );
              },
            ),
            onPressed: _isRefreshing ? null : _refreshInventory,
            tooltip: 'Refresh Inventory',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorWeight: 4,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: isDarkMode ? Colors.white : Colors.black,
          labelColor: isDarkMode ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          dividerColor: Colors.transparent,
          tabs: _categories.map((category) {
            return Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getCategoryIcon(category),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        category,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your inventory...',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshInventory,
                  color: primaryColor,
                  child: Column(
                    children: [
                      _buildSpeedBoostIndicator(),
                      _buildSearchBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: _categories.map((category) {
                            final items = _getItemsByCategory(category);
                            return _buildCategoryView(items, category, isDarkMode);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _slideController.value)),
          child: Opacity(
            opacity: _slideController.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _isSearching ? Icons.search : Icons.search_outlined,
                    color: _isSearching ? Theme.of(context).primaryColor : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _isSearching = value.isNotEmpty;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (_isSearching)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _isSearching = false;
                        });
                      },
                      iconSize: 20,
                      color: Colors.grey[600],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryView(List<InventoryItem> items, String category, bool isDarkMode) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * _fadeController.value),
                  child: Icon(
                    _getEmptyIcon(category),
                    size: 80,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeController,
                  child: Text(
                    _searchQuery.isNotEmpty 
                        ? 'No items found for "$_searchQuery"'
                        : 'No ${category.toLowerCase()}s found',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeController,
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'Try adjusting your search terms'
                        : 'Complete challenges or visit the shop to earn more items!',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 100)),
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
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () => _showItemDetails(item),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDarkMode ? const Color(0xFF1E2235) : Colors.white,
                      isDarkMode ? const Color(0xFF1E2235) : Colors.white,
                      item.color.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: item.color.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        item.getIconData(),
                        color: item.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _inventoryService.normalizeName(item.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Obtained: ${_formatDate(item.obtainedDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: item.color.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: item.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Quantity: ${item.count}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: item.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showUseItemDialog(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: item.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text('Use'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedBoostIndicator() {
    if (!_hasActiveSpeedBoost) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * _scaleController.value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade400,
                  Colors.green.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.8, end: 1.2),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: const Icon(
                        Icons.speed_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Speed Boost Active!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '2x XP multiplier',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDuration(_speedBoostRemainingTime),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    '2x',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  IconData _getEmptyIcon(String category) {
    switch (category) {
      case 'Boosters':
        return Icons.speed_rounded;
      case 'Power-ups':
        return Icons.flash_on_rounded;
      case 'Tickets':
        return Icons.confirmation_number_rounded;
      case 'Special':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'All':
        return const Icon(Icons.grid_view_rounded, size: 18);
      case 'Boosters':
        return const Icon(Icons.speed_rounded, size: 18);
      case 'Power-ups':
        return const Icon(Icons.flash_on_rounded, size: 18);
      case 'Tickets':
        return const Icon(Icons.confirmation_number_rounded, size: 18);
      case 'Special':
        return const Icon(Icons.card_giftcard_rounded, size: 18);
      default:
        return const Icon(Icons.category_rounded, size: 18);
    }
  }
}