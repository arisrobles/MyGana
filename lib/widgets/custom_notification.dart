import 'package:flutter/material.dart';
import 'dart:async';

class CustomNotification extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;

  const CustomNotification({
    super.key,
    required this.message,
    this.icon = Icons.notifications,
    this.color = Colors.green,
    this.duration = const Duration(seconds: 3),
  });

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.notifications,
    Color color = Colors.green,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Declare the variable first
    late final OverlayEntry overlayEntry;

    // Then initialize it
    overlayEntry = OverlayEntry(
      builder: (context) => CustomNotification(
        message: message,
        icon: icon,
        color: color,
        duration: duration,
      ),
    );

    // Insert the overlay
    Overlay.of(context).insert(overlayEntry);

    // Remove after duration
    Timer(duration, () {
      overlayEntry.remove();
    });
  }

  @override
  State<CustomNotification> createState() => _CustomNotificationState();
}

class _CustomNotificationState extends State<CustomNotification> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<double>(begin: -100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    // Start exit animation before the duration ends
    Future.delayed(widget.duration - const Duration(milliseconds: 500), () {
      if (mounted) {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: Colors.white),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

