import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/daily_points_screen.dart';
import 'package:nihongo_japanese_app/screens/home_screen.dart';
import 'package:nihongo_japanese_app/screens/inventory_screen.dart';
import 'package:nihongo_japanese_app/screens/review_screen.dart';
import 'package:nihongo_japanese_app/services/daily_points_service.dart';
import 'package:nihongo_japanese_app/widgets/sync_status_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  bool _hasUnclaimedRewards = false;
  int _unclaimedRewardsCount = 0;

  // Navigation history stack
  final List<int> _navigationHistory = [0]; // Start with home tab

  void navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
      // Add to navigation history
      _navigationHistory.add(index);
    });
  }

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _screens.addAll([
      HomeScreen(onNavigate: navigateTo),
      const ReviewScreen(),
      const DailyPointsScreen(),
      const InventoryScreen(),
    ]);

    _checkForUnclaimedRewards();
  }

  Future<void> _checkForUnclaimedRewards() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final hasClaimedToday = prefs.getBool('claimed_today_$today') ?? false;
    final canClaim = await DailyPointsService().canClaimDailyPoints();
    final spinsRemaining = prefs.getInt('spins_remaining') ?? 3;
    final hasUnclaimedGifts = prefs.getBool('has_unclaimed_gifts') ?? false;
    final unclaimedGiftsCount = prefs.getInt('unclaimed_gifts_count') ?? 0;

    setState(() {
      _hasUnclaimedRewards =
          (!hasClaimedToday && canClaim) || (spinsRemaining > 0) || hasUnclaimedGifts;
      _unclaimedRewardsCount = unclaimedGiftsCount;
    });
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => TweenAnimationBuilder(
            duration: const Duration(milliseconds: 300),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: 0.5 + (0.5 * value),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: AlertDialog(
              backgroundColor: Theme.of(context).dialogBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.exit_to_app_rounded,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Exit App',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to close the app?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return WillPopScope(
      onWillPop: () async {
        // If we have more than one item in history, go back to previous screen
        if (_navigationHistory.length > 1) {
          setState(() {
            // Remove current screen from history
            _navigationHistory.removeLast();
            // Set to previous screen
            _selectedIndex = _navigationHistory.last;
          });
          return false;
        }

        // If we're on the home tab, show exit dialog
        return _showExitDialog();
      },
      child: Scaffold(
        body: Column(
          children: [
            const SyncStatusBanner(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _screens[_selectedIndex],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1C2E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                  // Add to navigation history
                  _navigationHistory.add(index);
                });
                if (index == 2) {
                  // Refresh rewards data when navigating to rewards tab
                  _checkForUnclaimedRewards();
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: primaryColor,
              unselectedItemColor: Colors.grey.shade600,
              selectedFontSize: 13,
              unselectedFontSize: 11,
              showUnselectedLabels: true,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          _selectedIndex == 0 ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.home_outlined,
                      color: _selectedIndex == 0 ? primaryColor : Colors.grey.shade600,
                    ),
                  ),
                  activeIcon: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.home,
                      color: primaryColor,
                    ),
                  ),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          _selectedIndex == 1 ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.flip_camera_ios_outlined,
                      color: _selectedIndex == 1 ? primaryColor : Colors.grey.shade600,
                    ),
                  ),
                  activeIcon: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.flip_camera_ios,
                      color: primaryColor,
                    ),
                  ),
                  label: 'Review',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedIndex == 2
                              ? primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _hasUnclaimedRewards && _selectedIndex != 2
                                  ? 1.0 + (_animationController.value * 0.1)
                                  : 1.0,
                              child: Icon(
                                Icons.card_giftcard_outlined,
                                color: _selectedIndex == 2 ? primaryColor : Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                      ),
                      if (_hasUnclaimedRewards && _selectedIndex != 2)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? const Color(0xFF1A1C2E) : Colors.white,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unclaimedRewardsCount > 0 ? '$_unclaimedRewardsCount' : '!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          color: primaryColor,
                        ),
                      ),
                      if (_hasUnclaimedRewards)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? const Color(0xFF1A1C2E) : Colors.white,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unclaimedRewardsCount > 0 ? '$_unclaimedRewardsCount' : '!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Rewards',
                ),
                BottomNavigationBarItem(
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          _selectedIndex == 3 ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: _selectedIndex == 3 ? primaryColor : Colors.grey.shade600,
                    ),
                  ),
                  activeIcon: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      color: primaryColor,
                    ),
                  ),
                  label: 'Inventory',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
