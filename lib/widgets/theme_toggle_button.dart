import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool isCompact;

  const ThemeToggleButton({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: GestureDetector(
        onTap: () {
          themeProvider.toggleDarkLightTheme(); // updated
        },
        child: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
          color: Colors.white,
          size: isCompact ? 20 : 24,
        ),
      ),
    );
  }
}
