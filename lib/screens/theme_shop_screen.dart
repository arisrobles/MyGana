import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nihongo_japanese_app/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nihongo_japanese_app/services/coin_service.dart';
import 'dart:math' as math;

// Move enum to top level
enum ThemeFilter { all, purchased, available, wishlist }

class ThemeShopScreen extends StatefulWidget {
  const ThemeShopScreen({super.key});

  @override
  State<ThemeShopScreen> createState() => _ThemeShopScreenState();
}

// Update the _ThemeShopScreenState class to add new properties for enhanced functionality
class _ThemeShopScreenState extends State<ThemeShopScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Set<AppThemeMode> _flippedThemes = {};

  // List of premium themes to display in the shop
  final List<AppThemeMode> _premiumThemes = [
    AppThemeMode.system,
    AppThemeMode.light,
    AppThemeMode.dark,
    AppThemeMode.sakura,
    AppThemeMode.matcha,
    AppThemeMode.sunset,
    AppThemeMode.ocean,
    AppThemeMode.lavender,
    AppThemeMode.autumn,
    AppThemeMode.fuji,
    AppThemeMode.blueLight,
  ];

  // Theme prices map
  final Map<AppThemeMode, int> _themePrices = {
    AppThemeMode.sakura: 250,
    AppThemeMode.matcha: 200,
    AppThemeMode.sunset: 200,
    AppThemeMode.ocean: 300,
    AppThemeMode.lavender: 250,
    AppThemeMode.autumn: 200,
    AppThemeMode.fuji: 350,
    AppThemeMode.blueLight: 150,
    AppThemeMode.system: 0,
    AppThemeMode.light: 0,
    AppThemeMode.dark: 0,
  };

  // Theme categories
  final Map<String, List<AppThemeMode>> _themeCategories = {
    'Featured': [AppThemeMode.sakura, AppThemeMode.ocean, AppThemeMode.fuji],
    'New': [AppThemeMode.blueLight, AppThemeMode.lavender],
    'Popular': [AppThemeMode.sunset, AppThemeMode.matcha, AppThemeMode.autumn],
    'Basic': [AppThemeMode.system, AppThemeMode.light, AppThemeMode.dark],
    'Owned': [], // This will be populated in initState
  };

  // Filter options
  String _searchQuery = '';

  // Track which themes the user has viewed for animations
  final Set<AppThemeMode> _viewedThemes = {};

  // Track purchased themes
  Set<AppThemeMode> _purchasedThemes = {};

  // Track wishlist themes
  Set<AppThemeMode> _wishlistThemes = {};

  // User's coin balance
  int _userCoins = 0;

  // For confetti effect when selecting a theme
  bool _showConfetti = false;
  AppThemeMode? _selectedThemeForConfetti;

  // For theme comparison
  final List<AppThemeMode> _comparisonThemes = [];
  bool _isComparisonMode = false;

  // For theme ratings
  final Map<AppThemeMode, double> _themeRatings = {
    AppThemeMode.sakura: 4.8,
    AppThemeMode.matcha: 4.5,
    AppThemeMode.sunset: 4.7,
    AppThemeMode.ocean: 4.9,
    AppThemeMode.lavender: 4.6,
    AppThemeMode.autumn: 4.4,
    AppThemeMode.fuji: 4.9,
    AppThemeMode.blueLight: 4.3,
    AppThemeMode.system: 4.0,
    AppThemeMode.light: 4.2,
    AppThemeMode.dark: 4.7,
  };

  // For fullscreen preview
  bool _isFullScreenPreview = false;
  AppThemeMode? _previewTheme;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animationController.forward();

    // Add one more tab for "Owned" themes
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      // No filter reset needed since we removed filters
    });

    // Load user data
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveViewedThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final viewedThemesString =
        _viewedThemes.map((theme) => theme.toString()).toList();

    await prefs.setStringList('viewed_themes', viewedThemesString);
  }

  void _markThemeAsViewed(AppThemeMode theme) {
    if (!_viewedThemes.contains(theme)) {
      setState(() {
        _viewedThemes.add(theme);
      });
      _saveViewedThemes();
    }
  }

  List<AppThemeMode> _getFilteredThemes() {
    List<AppThemeMode> filteredThemes = _premiumThemes;

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      filteredThemes = filteredThemes.where((theme) {
        final name = themeProvider.getThemeName(theme).toLowerCase();
        final description =
            themeProvider.getThemeDescription(theme).toLowerCase();
        return name.contains(_searchQuery) ||
            description.contains(_searchQuery);
      }).toList();
    }

    return filteredThemes;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isLargeScreen = screenSize.width > 900;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // If in fullscreen preview mode, show the preview
    if (_isFullScreenPreview && _previewTheme != null) {
      return _buildFullScreenPreview(context, _previewTheme!);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: _buildBackgroundPattern(context, themeProvider),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(context),
                _buildCoinBalance(context),

                // Tab bar for categories
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: !isLargeScreen,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Owned'), // New tab for owned themes
                      Tab(text: 'Featured'),
                      Tab(text: 'New'),
                      Tab(text: 'Popular'),
                      Tab(text: 'Basic'),
                    ],
                  ),
                ),

                // Comparison bar (shows when in comparison mode)
                if (_isComparisonMode) _buildComparisonBar(context),

                // Tab view content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // All themes
                      _buildThemeGrid(context, themeProvider, isTablet,
                          _getFilteredThemes()),

                      // Owned themes - new tab
                      _buildThemeGrid(
                          context,
                          themeProvider,
                          isTablet,
                          _getFilteredThemes()
                              .where(
                                  (theme) => _purchasedThemes.contains(theme))
                              .toList()),

                      // Featured themes
                      _buildThemeGrid(
                          context,
                          themeProvider,
                          isTablet,
                          _getFilteredThemes()
                              .where((theme) =>
                                  _themeCategories['Featured']!.contains(theme))
                              .toList()),

                      // New themes
                      _buildThemeGrid(
                          context,
                          themeProvider,
                          isTablet,
                          _getFilteredThemes()
                              .where((theme) =>
                                  _themeCategories['New']!.contains(theme))
                              .toList()),

                      // Popular themes
                      _buildThemeGrid(
                          context,
                          themeProvider,
                          isTablet,
                          _getFilteredThemes()
                              .where((theme) =>
                                  _themeCategories['Popular']!.contains(theme))
                              .toList()),

                      // Basic themes
                      _buildThemeGrid(
                          context,
                          themeProvider,
                          isTablet,
                          _getFilteredThemes()
                              .where((theme) =>
                                  _themeCategories['Basic']!.contains(theme))
                              .toList()),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Confetti overlay when selecting a theme
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ConfettiPainter(
                    colors: _getThemeColors(_selectedThemeForConfetti),
                  ),
                ),
              ),
            ),

          // Comparison floating action button
          if (!_isComparisonMode && _comparisonThemes.isNotEmpty)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _isComparisonMode = true;
                  });
                },
                icon: const Icon(Icons.compare_arrows),
                label: Text('Compare (${_comparisonThemes.length})'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullScreenPreview(BuildContext context, AppThemeMode theme) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = _getThemePrimaryColor(theme);
    final secondaryColor = _getThemeSecondaryColor(theme);

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            _isFullScreenPreview = false;
            _previewTheme = null;
          });
        },
        child: Stack(
          children: [
            // Theme background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    secondaryColor,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Theme-specific pattern
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ThemePreviewPainter(
                        theme: theme,
                        color: Colors.white.withAlpha(40),
                      ),
                    ),
                  ),

                  // Theme preview content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Theme icon with animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 1.0, end: 1.2),
                          duration: const Duration(milliseconds: 2000),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Icon(
                                themeProvider.getThemeIcon(theme),
                                color: Colors.white,
                                size: 120,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),

                        // Theme name
                        Text(
                          themeProvider.getThemeName(theme),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: "TheLastShuriken"),
                        ),
                        const SizedBox(height: 2),

                        // Theme description
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            themeProvider.getThemeDescription(theme),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isFullScreenPreview = false;
                                  _previewTheme = null;
                                });
                              },
                              icon: const Icon(Icons.arrow_back),
                              label: const Text(
                                'Back to Shop',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                final isPurchased =
                                    _purchasedThemes.contains(theme);
                                final price = _themePrices[theme] ?? 0;

                                setState(() {
                                  _isFullScreenPreview = false;
                                  _previewTheme = null;
                                });

                                if (isPurchased) {
                                  themeProvider.setAppTheme(theme);

                                  // Show confetti effect
                                  setState(() {
                                    _showConfetti = true;
                                    _selectedThemeForConfetti = theme;
                                  });

                                  Future.delayed(const Duration(seconds: 2),
                                      () {
                                    if (mounted) {
                                      setState(() {
                                        _showConfetti = false;
                                      });
                                    }
                                  });
                                } else {
                                  _showPurchaseDialog(
                                      context, theme, price, primaryColor);
                                }
                              },
                              icon: Icon(_purchasedThemes.contains(theme)
                                  ? Icons.check
                                  : Icons.shopping_cart),
                              label: Text(
                                _purchasedThemes.contains(theme)
                                    ? 'Apply Theme'
                                    : 'Purchase',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
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

            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () {
                  setState(() {
                    _isFullScreenPreview = false;
                    _previewTheme = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color:
            isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search themes...',
                hintStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
        ],
      ),
    );
  }

  Widget _buildCoinBalance(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/coin.png',
            width: 24,
            height: 24,
            color: Colors.amber,
            colorBlendMode: BlendMode.modulate,
          ),
          const SizedBox(width: 8),
          Text(
            '$_userCoins Moji Coins',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to coin purchase screen
              // Implementation for navigation to coin purchase will be added later
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Get more coins feature coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            label: const Text(
              'Get More',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getThemeColors(AppThemeMode? theme) {
    if (theme == null) {
      return [Colors.red, Colors.blue, Colors.green, Colors.yellow];
    }

    switch (theme) {
      case AppThemeMode.sakura:
        return [
          const Color(0xFFFF9EB1),
          const Color(0xFFFF6B8B),
          Colors.pink.shade200,
          Colors.white
        ];
      case AppThemeMode.matcha:
        return [
          const Color(0xFF7CB342),
          const Color(0xFF558B2F),
          Colors.green.shade200,
          Colors.lightGreen.shade100
        ];
      case AppThemeMode.sunset:
        return [
          const Color(0xFFFF9800),
          const Color(0xFFFF5722),
          Colors.orange.shade200,
          Colors.yellow.shade200
        ];
      case AppThemeMode.ocean:
        return [
          const Color(0xFF039BE5),
          const Color(0xFF0277BD),
          Colors.blue.shade200,
          Colors.lightBlue.shade100
        ];
      case AppThemeMode.lavender:
        return [
          const Color(0xFF9575CD),
          const Color(0xFF7E57C2),
          Colors.purple.shade200,
          Colors.deepPurple.shade100
        ];
      case AppThemeMode.autumn:
        return [
          const Color(0xFFFF7043),
          const Color(0xFFE64A19),
          Colors.deepOrange.shade200,
          Colors.orange.shade100
        ];
      case AppThemeMode.fuji:
        return [
          const Color(0xFF546E7A),
          const Color(0xFF455A64),
          Colors.blueGrey.shade200,
          Colors.grey.shade300
        ];
      case AppThemeMode.blueLight:
        return [
          const Color(0xFF2196F3),
          const Color(0xFF1976D2),
          Colors.lightBlue.shade200,
          Colors.blue.shade100
        ];
      case AppThemeMode.dark:
        return [
          const Color(0xFF6A5AE0),
          const Color(0xFF7D67FF),
          Colors.deepPurple.shade200,
          Colors.indigo.shade100
        ];
      case AppThemeMode.light:
        return [
          const Color(0xFF6A5AE0),
          const Color(0xFF7D67FF),
          Colors.purple.shade200,
          Colors.indigo.shade100
        ];
      case AppThemeMode.system:
        return [
          Colors.grey.shade400,
          Colors.grey.shade600,
          Colors.grey.shade200,
          Colors.white
        ];
    }
  }

  Widget _buildBackgroundPattern(
      BuildContext context, ThemeProvider themeProvider) {
    // Get theme-specific pattern
    Color patternColor = Theme.of(context).primaryColor.withAlpha(8);

    return CustomPaint(
      painter: BackgroundPatternPainter(
        color: patternColor,
        themeMode: themeProvider.appThemeMode,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final headerStartColor = Theme.of(context).primaryColor;
    final headerEndColor = Theme.of(context).colorScheme.secondary;
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Container(
              width: double.infinity,
              padding:
                  EdgeInsets.fromLTRB(24, 20, 24, screenWidth > 600 ? 24 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    headerStartColor,
                    headerEndColor,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: headerStartColor.withAlpha(76),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Hero(
                        tag: 'back-button',
                        child: Material(
                          color: Colors.transparent,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                      Text(
                        'Theme Shop',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: "TheLastShuriken",
                            ),
                      ),
                      const SizedBox(width: 40), // Balance the header
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeGrid(BuildContext context, ThemeProvider themeProvider,
      bool isTablet, List<AppThemeMode> themes) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Get screen width to determine grid layout
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine number of columns based on screen width
    int crossAxisCount = 2; // Default for phones

    // For very small devices, use 1 column
    if (screenWidth < 360) {
      crossAxisCount = 1;
    }
    // For tablets, use 3 columns
    else if (screenWidth >= 600 && screenWidth < 900) {
      crossAxisCount = 3;
    }
    // For large tablets/desktops, use 4 columns
    else if (screenWidth >= 900) {
      crossAxisCount = 4;
    }

    // Calculate appropriate aspect ratio based on screen size
    // Taller cards for smaller screens, wider cards for larger screens
    double childAspectRatio = 0.75; // Default

    if (screenWidth < 360) {
      childAspectRatio = 0.8; // Slightly less tall on very small screens
    } else if (screenWidth >= 600) {
      childAspectRatio = 0.7; // Taller on tablets
    }

    if (themes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No themes found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Try changing your filter',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDarkMode
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                  ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: themes.length,
        itemBuilder: (context, index) {
          final theme = themes[index];
          final isSelected = themeProvider.appThemeMode == theme;
          final isNew = !_viewedThemes.contains(theme);
          final isPurchased = _purchasedThemes.contains(theme);
          final isWishlisted = _wishlistThemes.contains(theme);
          final price = _themePrices[theme] ?? 0;
          final rating = _themeRatings[theme] ?? 0.0;

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final delayedAnimation = CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  0.1 + (index * 0.05),
                  0.6 + (index * 0.05),
                  curve: Curves.easeOutCubic,
                ),
              );

              return FadeTransition(
                opacity: delayedAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(delayedAnimation),
                  child: _buildEnhancedThemeCard(
                      context,
                      theme,
                      isSelected,
                      isNew,
                      isPurchased,
                      isWishlisted,
                      price,
                      rating,
                      themeProvider),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPurchaseDialog(
      BuildContext context, AppThemeMode theme, int price, Color primaryColor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Purchase ${Provider.of<ThemeProvider>(context, listen: false).getThemeName(theme)}?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This theme costs $price Moji Coins. Do you want to purchase it?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (_userCoins >= price) {
                        // Deduct coins and mark theme as purchased
                        final coinService = CoinService();
                        await coinService.spendCoins(price);

                        final prefs = await SharedPreferences.getInstance();
                        final purchasedThemesString =
                            prefs.getStringList('purchased_themes') ?? [];
                        purchasedThemesString.add(theme.toString());
                        await prefs.setStringList(
                            'purchased_themes', purchasedThemesString);

                        setState(() {
                          _userCoins -= price;
                          _purchasedThemes.add(theme);
                        });

                        if (mounted) {
                          Navigator.of(context).pop();

                          // Show a snackbar to confirm purchase
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${Provider.of<ThemeProvider>(context, listen: false).getThemeName(theme)} theme purchased!'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: primaryColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          Navigator.of(context).pop();

                          // Show a snackbar to indicate insufficient coins
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Insufficient Moji Coins!'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
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
            ],
          ),
        );
      },
    );
  }

  Color _getThemePrimaryColor(AppThemeMode theme) {
    switch (theme) {
      case AppThemeMode.sakura:
        return const Color(0xFFFF85A2);
      case AppThemeMode.matcha:
        return const Color(0xFF7CB342);
      case AppThemeMode.sunset:
        return const Color(0xFFFF9800);
      case AppThemeMode.ocean:
        return const Color(0xFF039BE5);
      case AppThemeMode.lavender:
        return const Color(0xFF9575CD);
      case AppThemeMode.autumn:
        return const Color(0xFFFF7043);
      case AppThemeMode.fuji:
        return const Color(0xFF546E7A);
      case AppThemeMode.blueLight:
        return const Color(0xFF2196F3);
      case AppThemeMode.dark:
        return const Color(0xFF6A5AE0);
      case AppThemeMode.light:
        return const Color(0xFF6A5AE0);
      case AppThemeMode.system:
        return Colors.grey.shade600;
    }
  }

  Color _getThemeSecondaryColor(AppThemeMode theme) {
    switch (theme) {
      case AppThemeMode.sakura:
        return const Color(0xFFFF6B8B);
      case AppThemeMode.matcha:
        return const Color(0xFF558B2F);
      case AppThemeMode.sunset:
        return const Color(0xFFFF5722);
      case AppThemeMode.ocean:
        return const Color(0xFF0277BD);
      case AppThemeMode.lavender:
        return const Color(0xFF7E57C2);
      case AppThemeMode.autumn:
        return const Color(0xFFE64A19);
      case AppThemeMode.fuji:
        return const Color(0xFF455A64);
      case AppThemeMode.blueLight:
        return const Color(0xFF1976D2);
      case AppThemeMode.dark:
        return const Color(0xFF2D2D3F);
      case AppThemeMode.light:
        return const Color(0xFF7D67FF);
      case AppThemeMode.system:
        return Colors.grey.shade800;
    }
  }

  Widget _buildComparisonBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isDarkMode ? Colors.grey.shade800.withOpacity(0.7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comparing ${_comparisonThemes.length} themes',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _comparisonThemes.clear();
                        _isComparisonMode = false;
                      });
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isComparisonMode = false;
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _comparisonThemes.map((theme) {
                final themeProvider =
                    Provider.of<ThemeProvider>(context, listen: false);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getThemePrimaryColor(theme).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        themeProvider.getThemeIcon(theme),
                        color: _getThemePrimaryColor(theme),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        themeProvider.getThemeName(theme),
                        style: TextStyle(
                          color: _getThemePrimaryColor(theme),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _comparisonThemes.remove(theme);
                            if (_comparisonThemes.isEmpty) {
                              _isComparisonMode = false;
                            }
                          });
                        },
                        child: Icon(
                          Icons.close,
                          color: _getThemePrimaryColor(theme),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (_comparisonThemes.length >= 2) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _showComparisonDialog(context);
              },
              icon: const Icon(Icons.compare),
              label: const Text('Compare Themes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showComparisonDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: isTablet ? screenSize.width * 0.8 : double.infinity,
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: screenSize.height * 0.8,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.compare,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Theme Comparison',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Theme previews
                        SizedBox(
                          height: 200,
                          child: Row(
                            children: _comparisonThemes.map((theme) {
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _getThemePrimaryColor(theme),
                                        _getThemeSecondaryColor(theme),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      themeProvider.getThemeIcon(theme),
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Theme names
                        Row(
                          children: _comparisonThemes.map((theme) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Text(
                                      themeProvider.getThemeName(theme),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Price comparison
                        _buildComparisonRow(
                          'Price',
                          _comparisonThemes.map((theme) {
                            final price = _themePrices[theme] ?? 0;
                            return price == 0 ? 'Free' : '$price Moji Coins';
                          }).toList(),
                        ),

                        // Status comparison
                        _buildComparisonRow(
                          'Status',
                          _comparisonThemes.map((theme) {
                            return _purchasedThemes.contains(theme)
                                ? 'Purchased'
                                : 'Available';
                          }).toList(),
                        ),

                        // Description comparison
                        _buildComparisonRow(
                          'Description',
                          _comparisonThemes.map((theme) {
                            return themeProvider.getThemeDescription(theme);
                          }).toList(),
                          isMultiLine: true,
                        ),

                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: _comparisonThemes.map((theme) {
                            final isPurchased =
                                _purchasedThemes.contains(theme);
                            final price = _themePrices[theme] ?? 0;

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (isPurchased) {
                                      themeProvider.setAppTheme(theme);
                                      Navigator.pop(context);

                                      // Show confetti effect
                                      setState(() {
                                        _showConfetti = true;
                                        _selectedThemeForConfetti = theme;
                                      });

                                      Future.delayed(const Duration(seconds: 2),
                                          () {
                                        if (mounted) {
                                          setState(() {
                                            _showConfetti = false;
                                          });
                                        }
                                      });
                                    } else {
                                      Navigator.pop(context);
                                      _showPurchaseDialog(context, theme, price,
                                          _getThemePrimaryColor(theme));
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isPurchased
                                        ? _getThemePrimaryColor(theme)
                                        : Colors.amber,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    isPurchased ? 'Apply' : 'Buy',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, List<String> values,
      {bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: isMultiLine
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: values.map((value) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                    textAlign: isMultiLine ? TextAlign.left : TextAlign.center,
                    maxLines: isMultiLine ? 5 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load viewed themes
    final viewedThemesString = prefs.getStringList('viewed_themes') ?? [];

    // Load purchased themes
    final purchasedThemesString = prefs.getStringList('purchased_themes') ?? [];

    // Load wishlist themes
    final wishlistThemesString = prefs.getStringList('wishlist_themes') ?? [];

    // Load coins using CoinService
    final coinService = CoinService();
    final coins = await coinService.getCoins();

    setState(() {
      _viewedThemes.addAll(viewedThemesString
          .map((themeString) => AppThemeMode.values.firstWhere(
                (mode) => mode.toString() == themeString,
                orElse: () => AppThemeMode.system,
              )));

      _purchasedThemes = Set.from(purchasedThemesString
          .map((themeString) => AppThemeMode.values.firstWhere(
                (mode) => mode.toString() == themeString,
                orElse: () => AppThemeMode.system,
              )));

      _wishlistThemes = Set.from(wishlistThemesString
          .map((themeString) => AppThemeMode.values.firstWhere(
                (mode) => mode.toString() == themeString,
                orElse: () => AppThemeMode.system,
              )));

      // Add free themes to purchased
      _purchasedThemes.add(AppThemeMode.system);
      _purchasedThemes.add(AppThemeMode.light);
      _purchasedThemes.add(AppThemeMode.dark);

      _userCoins = coins;

      // Update the Owned category
      _themeCategories['Owned'] = _purchasedThemes.toList();
    });
  }

  Widget _buildEnhancedThemeCard(
      BuildContext context,
      AppThemeMode theme,
      bool isSelected,
      bool isNew,
      bool isPurchased,
      bool isWishlisted,
      int price,
      double rating,
      ThemeProvider themeProvider) {
    // Get theme colors for preview
    final primaryColor = _getThemePrimaryColor(theme);
    final secondaryColor = _getThemeSecondaryColor(theme);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Check if this theme card is flipped to show description
    final isFlipped = _flippedThemes.contains(theme);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();

        // Show full screen preview on tap
        setState(() {
          _isFullScreenPreview = true;
          _previewTheme = theme;
        });
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();

        if (isPurchased) {
          themeProvider.setAppTheme(theme);
          _markThemeAsViewed(theme);

          // Show confetti effect
          setState(() {
            _showConfetti = true;
            _selectedThemeForConfetti = theme;
          });

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showConfetti = false;
              });
            }
          });

          // Show a snackbar to confirm theme change
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${Provider.of<ThemeProvider>(context, listen: false).getThemeName(theme)} theme applied'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Show purchase dialog
          _showPurchaseDialog(context, theme, price, primaryColor);
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: isSelected ? 1.05 : 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Card(
              elevation: isSelected ? 8 : 4,
              shadowColor: primaryColor.withAlpha(128),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: isSelected
                    ? BorderSide(color: primaryColor, width: 2)
                    : BorderSide.none,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Theme preview
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        // Theme background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor,
                                secondaryColor,
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Theme-specific pattern
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: ThemePreviewPainter(
                                    theme: theme,
                                    color: Colors.white.withAlpha(26),
                                  ),
                                ),
                              ),

                              // Theme icon with pulsing animation
                              Center(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.9, end: 1.1),
                                  duration: const Duration(milliseconds: 1500),
                                  curve: Curves.easeInOut,
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: isSelected ? value : 1.0,
                                      child: Icon(
                                        Provider.of<ThemeProvider>(context,
                                                listen: false)
                                            .getThemeIcon(theme),
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Price tag
                        if (!isPurchased && price > 0)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(179),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/coin.png',
                                    width: 16,
                                    height: 16,
                                    color: Colors.amber,
                                    colorBlendMode: BlendMode.modulate,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$price',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Selected indicator
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                          ),

                        // New badge
                        if (isNew)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Purchased badge
                        if (isPurchased && !isSelected && price > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'OWNED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Free badge
                        if (price == 0 && !isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Compare button
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (_comparisonThemes.contains(theme)) {
                                  _comparisonThemes.remove(theme);
                                } else {
                                  if (_comparisonThemes.length < 3) {
                                    _comparisonThemes.add(theme);
                                  } else {
                                    // Show max comparison message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'You can compare up to 3 themes at once'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _comparisonThemes.contains(theme)
                                    ? primaryColor
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.compare_arrows,
                                color: _comparisonThemes.contains(theme)
                                    ? Colors.white
                                    : primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Theme info - This is where we'll add the flip functionality
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Flip button and theme name/description
                          Row(
                            crossAxisAlignment: CrossAxisAlignment
                                .start, // Align to top for better layout with multiline text
                            children: [
                              // Flip button
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    // Toggle the flip state for this theme
                                    if (_flippedThemes.contains(theme)) {
                                      _flippedThemes.remove(theme);
                                    } else {
                                      _flippedThemes.add(theme);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.assignment_late_outlined,
                                    color: primaryColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Theme name or description based on flip state
                              Expanded(
                                child: LayoutBuilder(
                                    builder: (context, constraints) {
                                  // Calculate available height for text
                                  // This ensures we adapt to the available space
                                  final availableHeight = constraints.maxHeight;

                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (Widget child,
                                        Animation<double> animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.2),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: isFlipped
                                        ? Container(
                                            key:
                                                ValueKey<String>('desc-$theme'),
                                            constraints: BoxConstraints(
                                              maxHeight: availableHeight *
                                                  0.6, // Limit height to prevent overflow
                                            ),
                                            child: Text(
                                              Provider.of<ThemeProvider>(
                                                      context,
                                                      listen: false)
                                                  .getThemeDescription(theme),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                                color: isDarkMode
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines:
                                                  3, // Limit to 3 lines to prevent overflow
                                            ),
                                          )
                                        : Container(
                                            key:
                                                ValueKey<String>('name-$theme'),
                                            constraints: BoxConstraints(
                                              maxHeight: availableHeight *
                                                  0.3, // Limit height to prevent overflow
                                            ),
                                            child: Text(
                                              Provider.of<ThemeProvider>(
                                                      context,
                                                      listen: false)
                                                  .getThemeName(theme),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  fontFamily:
                                                      "TheLastShuriken"),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                  );
                                }),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Action buttons row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Apply/Purchase button
                              Expanded(
                                child: SizedBox(
                                  height: 30, // Adjust height
                                  child: ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      if (isPurchased) {
                                        themeProvider.setAppTheme(theme);
                                        _markThemeAsViewed(theme);
                                        setState(() {
                                          _showConfetti = true;
                                          _selectedThemeForConfetti = theme;
                                        });
                                        Future.delayed(
                                            const Duration(seconds: 2), () {
                                          if (mounted) {
                                            setState(() {
                                              _showConfetti = false;
                                            });
                                          }
                                        });
                                      } else {
                                        _showPurchaseDialog(context, theme,
                                            price, primaryColor);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPurchased
                                          ? primaryColor
                                          : Colors.amber,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: Text(
                                      isPurchased
                                          ? (isSelected ? 'Applied' : 'Apply')
                                          : 'Buy',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Preview button
                              Container(
                                height: 36, // Match button height
                                width: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.remove_red_eye),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _markThemeAsViewed(theme);

                                    // Show full screen preview
                                    setState(() {
                                      _isFullScreenPreview = true;
                                      _previewTheme = theme;
                                    });
                                  },
                                  tooltip: 'Preview',
                                  iconSize:
                                      18, // Smaller icon to fit on small devices
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(), // Remove default padding
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  final Color color;
  final AppThemeMode themeMode;

  BackgroundPatternPainter({required this.color, required this.themeMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Define pattern based on themeMode
    switch (themeMode) {
      case AppThemeMode.sakura:
        _drawSakuraPattern(canvas, size, paint);
        break;
      case AppThemeMode.matcha:
        _drawMatchaPattern(canvas, size, paint);
        break;
      case AppThemeMode.sunset:
        _drawSunsetPattern(canvas, size, paint);
        break;
      case AppThemeMode.ocean:
        _drawOceanPattern(canvas, size, paint);
        break;
      case AppThemeMode.lavender:
        _drawLavenderPattern(canvas, size, paint);
        break;
      case AppThemeMode.autumn:
        _drawAutumnPattern(canvas, size, paint);
        break;
      case AppThemeMode.fuji:
        _drawFujiPattern(canvas, size, paint);
        break;
      case AppThemeMode.blueLight:
        _drawBlueLightPattern(canvas, size, paint);
        break;
      case AppThemeMode.dark:
        _drawDarkPattern(canvas, size, paint);
        break;
      case AppThemeMode.light:
        _drawLightPattern(canvas, size, paint);
        break;
      case AppThemeMode.system:
        _drawSystemPattern(canvas, size, paint);
        break;
    }
  }

  // Pattern drawing methods remain the same
  void _drawSakuraPattern(Canvas canvas, Size size, Paint paint) {
    // Draw sakura flowers
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 8 + 4;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawMatchaPattern(Canvas canvas, Size size, Paint paint) {
    // Draw matcha leaves
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final leafSize = random.nextDouble() * 12 + 6;

      // Draw a simple leaf shape
      final path = Path();
      path.moveTo(x, y);
      path.quadraticBezierTo(
          x + leafSize / 2, y - leafSize / 3, x + leafSize, y);
      path.quadraticBezierTo(x + leafSize / 2, y + leafSize / 3, x, y);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawSunsetPattern(Canvas canvas, Size size, Paint paint) {
    // Draw sun rays
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final rayLength = random.nextDouble() * 30 + 15;
      final angle = random.nextDouble() * math.pi * 2;

      final x2 = x + math.cos(angle) * rayLength;
      final y2 = y + math.sin(angle) * rayLength;

      canvas.drawLine(Offset(x, y), Offset(x2, y2), paint);
    }
  }

  void _drawOceanPattern(Canvas canvas, Size size, Paint paint) {
    // Draw bubbles
    final random = math.Random();
    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 6 + 3;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawLavenderPattern(Canvas canvas, Size size, Paint paint) {
    // Draw lavender sprigs
    final random = math.Random();
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sprigHeight = random.nextDouble() * 20 + 10;

      // Draw a simple sprig line
      canvas.drawLine(Offset(x, y), Offset(x, y - sprigHeight), paint);

      // Add small circles to represent flowers
      for (int j = 0; j < 4; j++) {
        final flowerY = y - sprigHeight * (j + 1) / 5;
        final flowerX = x + random.nextDouble() * 6 - 3;
        final flowerRadius = random.nextDouble() * 2 + 1;
        canvas.drawCircle(Offset(flowerX, flowerY), flowerRadius, paint);
      }
    }
  }

  void _drawAutumnPattern(Canvas canvas, Size size, Paint paint) {
    // Draw falling leaves
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final leafSize = random.nextDouble() * 10 + 5;
      final angle =
          random.nextDouble() * math.pi / 4 - math.pi / 8; // Slight angle

      // Draw a simple leaf shape
      final path = Path();
      path.moveTo(x, y);
      path.lineTo(
          x + leafSize * math.cos(angle), y + leafSize * math.sin(angle));
      path.lineTo(x + leafSize * math.cos(angle + math.pi),
          y + leafSize * math.sin(angle + math.pi));
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawFujiPattern(Canvas canvas, Size size, Paint paint) {
    // Draw small mountain shapes
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final mountainWidth = random.nextDouble() * 20 + 10;
      final mountainHeight = random.nextDouble() * 15 + 8;

      // Draw a simple triangle
      final path = Path();
      path.moveTo(x, y);
      path.lineTo(x + mountainWidth / 2, y - mountainHeight);
      path.lineTo(x + mountainWidth, y);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawBlueLightPattern(Canvas canvas, Size size, Paint paint) {
    // Draw light rays or sparkles
    final random = math.Random();
    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleSize = random.nextDouble() * 5 + 2;

      // Draw a small rectangle to represent a sparkle
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, y), width: sparkleSize, height: sparkleSize),
          paint);
    }
  }

  void _drawDarkPattern(Canvas canvas, Size size, Paint paint) {
    // Draw stars
    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = random.nextDouble() * 3 + 1;

      // Draw a small circle to represent a star
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  void _drawLightPattern(Canvas canvas, Size size, Paint paint) {
    // Draw diamonds
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final diamondSize = random.nextDouble() * 8 + 4;

      // Draw a simple diamond shape
      final path = Path();
      path.moveTo(x, y - diamondSize / 2);
      path.lineTo(x + diamondSize / 2, y);
      path.lineTo(x, y + diamondSize / 2);
      path.lineTo(x - diamondSize / 2, y);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawSystemPattern(Canvas canvas, Size size, Paint paint) {
    // Draw grid
    const spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.themeMode != themeMode;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<Color> colors;

  ConfettiPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random();

    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 5 + 2;
      final color = colors[random.nextInt(colors.length)].withAlpha(200);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ThemePreviewPainter extends CustomPainter {
  final AppThemeMode theme;
  final Color color;

  ThemePreviewPainter({required this.theme, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (theme) {
      case AppThemeMode.sakura:
        _drawSakuraPattern(canvas, size, paint);
        break;
      case AppThemeMode.matcha:
        _drawMatchaPattern(canvas, size, paint);
        break;
      case AppThemeMode.sunset:
        _drawSunsetPattern(canvas, size, paint);
        break;
      case AppThemeMode.ocean:
        _drawOceanPattern(canvas, size, paint);
        break;
      case AppThemeMode.lavender:
        _drawLavenderPattern(canvas, size, paint);
        break;
      case AppThemeMode.autumn:
        _drawAutumnPattern(canvas, size, paint);
        break;
      case AppThemeMode.fuji:
        _drawFujiPattern(canvas, size, paint);
        break;
      case AppThemeMode.blueLight:
        _drawBlueLightPattern(canvas, size, paint);
        break;
      case AppThemeMode.dark:
        _drawDarkPattern(canvas, size, paint);
        break;
      case AppThemeMode.light:
        _drawLightPattern(canvas, size, paint);
        break;
      case AppThemeMode.system:
        _drawSystemPattern(canvas, size, paint);
        break;
    }
  }

  // Pattern drawing methods remain the same
  void _drawSakuraPattern(Canvas canvas, Size size, Paint paint) {
    // Draw small flower petals
    final random = math.Random(0);
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final petalSize = random.nextDouble() * 3 + 2;

      // Draw a simple flower shape
      for (int j = 0; j < 5; j++) {
        final angle = j * (math.pi / 2.5);
        final petalX = x + math.cos(angle) * petalSize;
        final petalY = y + math.sin(angle) * petalSize;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(petalX, petalY),
            width: petalSize,
            height: petalSize * 1.5,
          ),
          paint,
        );
      }
      canvas.drawCircle(Offset(x, y), petalSize / 3, paint);
    }
  }

  void _drawMatchaPattern(Canvas canvas, Size size, Paint paint) {
    // Draw matcha leaves
    final random = math.Random(0);
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final leafSize = random.nextDouble() * 5 + 3;

      // Draw a simple leaf shape
      final path = Path();
      path.moveTo(x, y);
      path.quadraticBezierTo(
          x + leafSize / 2, y - leafSize / 3, x + leafSize, y);
      path.quadraticBezierTo(x + leafSize / 2, y + leafSize / 3, x, y);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawSunsetPattern(Canvas canvas, Size size, Paint paint) {
    // Draw sun rays
    final random = math.Random(0);
    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final rayLength = random.nextDouble() * 10 + 5;
      final angle = random.nextDouble() * math.pi * 2;

      final x2 = x + math.cos(angle) * rayLength;
      final y2 = y + math.sin(angle) * rayLength;

      canvas.drawLine(Offset(x, y), Offset(x2, y2), paint);
    }
  }

  void _drawOceanPattern(Canvas canvas, Size size, Paint paint) {
    // Draw waves
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i / 5);
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x < size.width; x += 10) {
        const waveHeight = 3.0;
        final dy = math.sin(x / 20) * waveHeight;
        path.lineTo(x, y + dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  void _drawLavenderPattern(Canvas canvas, Size size, Paint paint) {
    // Draw lavender flowers
    final random = math.Random(0);
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final flowerSize = random.nextDouble() * 3 + 2;

      // Draw a simple flower
      for (int j = 0; j < 6; j++) {
        final angle = j * (math.pi / 3);
        final petalX = x + math.cos(angle) * flowerSize;
        final petalY = y + math.sin(angle) * flowerSize;
        canvas.drawCircle(Offset(petalX, petalY), flowerSize / 2, paint);
      }
    }
  }

  void _drawAutumnPattern(Canvas canvas, Size size, Paint paint) {
    // Draw autumn leaves
    final random = math.Random(0);
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final leafSize = random.nextDouble() * 4 + 3;

      // Draw a simple leaf
      final path = Path();
      path.moveTo(x, y - leafSize);
      path.quadraticBezierTo(x + leafSize, y, x, y + leafSize);
      path.quadraticBezierTo(x - leafSize, y, x, y - leafSize);
      canvas.drawPath(path, paint);
    }
  }

  void _drawFujiPattern(Canvas canvas, Size size, Paint paint) {
    // Draw mountain shapes
    final random = math.Random(0);
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final mountainWidth = random.nextDouble() * 10 + 5;
      final mountainHeight = random.nextDouble() * 8 + 4;

      // Draw a simple triangle
      final path = Path();
      path.moveTo(x, y);
      path.lineTo(x + mountainWidth / 2, y - mountainHeight);
      path.lineTo(x + mountainWidth, y);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawBlueLightPattern(Canvas canvas, Size size, Paint paint) {
    // Draw light rays
    final random = math.Random(0);
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleSize = random.nextDouble() * 3 + 1;

      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, y), width: sparkleSize, height: sparkleSize),
          paint);
    }
  }

  void _drawDarkPattern(Canvas canvas, Size size, Paint paint) {
    // Draw stars
    final random = math.Random(0);
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = random.nextDouble() * 2 + 1;

      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  void _drawLightPattern(Canvas canvas, Size size, Paint paint) {
    // Draw light patterns
    final random = math.Random(0);
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final diamondSize = random.nextDouble() * 4 + 2;

      final path = Path();
      path.moveTo(x, y - diamondSize / 2);
      path.lineTo(x + diamondSize / 2, y);
      path.lineTo(x, y + diamondSize / 2);
      path.lineTo(x - diamondSize / 2, y);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawSystemPattern(Canvas canvas, Size size, Paint paint) {
    // Draw grid
    const spacing = 10.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ThemePreviewPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.color != color;
  }
}
