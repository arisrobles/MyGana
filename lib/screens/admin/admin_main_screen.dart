import 'package:flutter/material.dart';

import 'admin_class_list_screen.dart';
import 'admin_leaderboard_screen.dart';
import 'admin_levels_screen.dart';
import 'admin_quiz_management_screen.dart';

class AdminMainScreen extends StatefulWidget {
  final int? initialTabIndex;

  const AdminMainScreen({super.key, this.initialTabIndex});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex != null) {
      _currentIndex = widget.initialTabIndex!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for arguments passed from navigation
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && args >= 0 && args < 4) {
      _currentIndex = args;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    final pages = <Widget>[
      const AdminLevelsScreen(), // Dashboard
      const AdminQuizManagementScreen(),
      const AdminClassListScreen(),
      const AdminLeaderboardScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Container(
            key: ValueKey(_currentIndex),
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 1200),
            margin: EdgeInsets.symmetric(
              horizontal: isDesktop
                  ? 32
                  : isTablet
                      ? 24
                      : 0,
            ),
            child: pages[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedIconTheme: const IconThemeData(size: 24),
            unselectedIconTheme: const IconThemeData(size: 22),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.quiz_outlined),
                activeIcon: Icon(Icons.quiz),
                label: 'Quizzes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group_outlined),
                activeIcon: Icon(Icons.group),
                label: 'Classes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_outlined),
                activeIcon: Icon(Icons.emoji_events),
                label: 'Leaderboard',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
