import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:nihongo_japanese_app/models/inventory_item.dart';
import 'package:nihongo_japanese_app/models/spin_reward.dart';
import 'package:nihongo_japanese_app/screens/currency_conversion_modal.dart';
import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/coin_service.dart';
import 'package:nihongo_japanese_app/services/currency_conversion_service.dart';
import 'package:nihongo_japanese_app/services/daily_points_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/inventory_service.dart';
import 'package:nihongo_japanese_app/services/review_progress_service.dart';
import 'package:nihongo_japanese_app/services/spin_reward_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpinningWheel extends StatefulWidget {
  final List<SpinReward> rewards;
  final Function(SpinReward) onSpinEnd;
  final Function() onSpinStart;
  final bool enabled;

  const SpinningWheel({
    super.key,
    required this.rewards,
    required this.onSpinEnd,
    required this.onSpinStart,
    required this.enabled,
  });

  @override
  State<SpinningWheel> createState() => _SpinningWheelState();
}

class _SpinningWheelState extends State<SpinningWheel> {
  StreamController<int> controller = StreamController<int>();
  bool _isSpinning = false;
  final _random = math.Random();
  int? _selectedIndex;

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  void spin() {
    if (_isSpinning || !widget.enabled) return;

    widget.onSpinStart();
    setState(() => _isSpinning = true);

    // Generate a random index
    _selectedIndex = _random.nextInt(widget.rewards.length);
    controller.add(_selectedIndex!);

    // Set a timer to show the reward after animation completes
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _selectedIndex != null) {
        setState(() => _isSpinning = false);
        widget.onSpinEnd(widget.rewards[_selectedIndex!]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? spin : null,
      child: SizedBox(
        height: 300,
        width: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.amber.withOpacity(0.3),
                    Colors.amber.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.4, 0.8, 1.0],
                ),
              ),
            ),
            // Fortune wheel
            FortuneWheel(
              selected: controller.stream,
              animateFirst: false,
              duration: const Duration(seconds: 5),
              indicators: const [
                FortuneIndicator(
                  alignment: Alignment.topCenter,
                  child: TriangleIndicator(
                    color: Colors.red,
                    width: 40,
                    height: 40,
                  ),
                ),
              ],
              physics: CircularPanPhysics(
                duration: const Duration(seconds: 5),
                curve: Curves.decelerate,
              ),
              onFling: () {
                if (widget.enabled && !_isSpinning) {
                  spin();
                }
              },
              items: [
                for (var reward in widget.rewards)
                  FortuneItem(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
                        children: [
                          Flexible(
                            child: Text(
                              _getRewardValue(reward),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis, // Add this to handle text overflow
                            ),
                          ),
                          const SizedBox(width: 4), // Reduced spacing
                          Icon(
                            reward.icon,
                            color: Colors.white,
                            size: 24, // Reduced size
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    style: FortuneItemStyle(
                      color: reward.color,
                      borderColor: Colors.white,
                      borderWidth: 3,
                    ),
                  ),
              ],
            ),
            // Center decoration
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF5F5F5)],
                ),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.amber,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRewardValue(SpinReward reward) {
    if (reward.name.contains('Points')) {
      return reward.name.split(' ')[0]; // Returns "50", "100", or "200"
    } else if (reward.name.contains('Coins')) {
      return reward.name.split(' ')[0]; // Returns "50" or "100"
    } else {
      return ''; // No text for other rewards
    }
  }
}

class DailyPointsScreen extends StatefulWidget {
  const DailyPointsScreen({super.key});

  @override
  State<DailyPointsScreen> createState() => _DailyPointsScreenState();
}

class _DailyPointsScreenState extends State<DailyPointsScreen> with TickerProviderStateMixin {
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Timer _countdownTimer;
  final bool _isClaiming = false;
  bool _canClaim = false;
  final bool _isDevMode = true;
  DateTime _nextClaimTime = DateTime.now();
  int _streakCount = 0;
  int _spinsRemaining = 3;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Gift claiming
  bool _hasUnclaimedGifts = false;
  int _unclaimedGiftsCount = 0;
  bool _isOpeningGift = false;
  late AnimationController _giftAnimationController;
  late Animation<double> _giftScaleAnimation;
  late Animation<double> _giftRotateAnimation;

  // Reward claiming state
  bool _isClaimingReward = false;

  // Sound effects
  static const String _claimSound = 'sounds/achievement.wav';
  static const String _spinSound = 'sounds/spin_wheel.mp3';
  static const String _winSound = 'sounds/win.mp3';
  static const String _streakSound = 'sounds/streak.wav';
  static const String _giftOpenSound = 'sounds/complete.wav';

  // Services
  final SpinRewardService _spinRewardService = SpinRewardService();
  final InventoryService _inventoryService = InventoryService();

  late List<SpinReward> _spinRewards;

  @override
  void initState() {
    super.initState();
    _spinRewards = _spinRewardService.getSpinRewards();
    _loadSavedState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _giftAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _giftScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _giftAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _giftRotateAnimation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(
        parent: _giftAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadCurrentStreak();
    _updateClaimStatus();
    _startCountdownTimer();
    _checkForUnclaimedGifts();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpinDate = prefs.getString('last_spin_date');
    final today = DateTime.now().toIso8601String().split('T')[0];

    setState(() {
      if (lastSpinDate == today) {
        _spinsRemaining = prefs.getInt('spins_remaining') ?? 3;
      } else {
        _spinsRemaining = 3;
        prefs.setString('last_spin_date', today);
        prefs.setInt('spins_remaining', 3);
      }
    });
  }

  Future<void> _playSound(String soundAsset) async {
    try {
      await _audioPlayer.play(AssetSource(soundAsset));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> _handleSpin() async {
    if (_spinsRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No spins remaining today. Come back tomorrow!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Play spin sound
    _playSound(_spinSound);

    // We'll update the spins count after the spin is complete
    // This ensures the last spin works correctly
  }

  Future<void> _handleSpinEnd(SpinReward reward) async {
    // Update spins remaining after the spin is complete
    setState(() {
      _spinsRemaining--;
    });

    // Save the updated spins count
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('spins_remaining', _spinsRemaining);

    // Show appropriate dialog based on reward type
    if (reward.name == 'Surprise Gift') {
      _showSurpriseGiftDialog();
    } else {
      _showRewardDialog(reward);
    }
  }

  void _showSurpriseGiftDialog() {
    _playSound(_winSound);

    // List of possible surprise gifts
    final surpriseGifts = [
      SpinReward(
        name: 'Kanji Pack',
        type: SpinRewardType.kanji,
        description: 'Unlock a special set of kanji characters!',
        color: Colors.deepPurple.shade500,
        iconName: 'auto_awesome_rounded',
        japaneseText: '漢字',
      ),
      SpinReward(
        name: 'Vocabulary Bundle',
        type: SpinRewardType.vocabulary,
        description: 'Get a collection of useful Japanese vocabulary!',
        color: Colors.blue.shade500,
        iconName: 'auto_awesome_rounded',
        japaneseText: '単語',
      ),
      SpinReward(
        name: 'Power Boost',
        type: SpinRewardType.powerup,
        description: 'Double your learning speed for 1 hour!',
        color: Colors.green.shade500,
        iconName: 'speed_rounded',
        japaneseText: 'パワーアップ',
      ),
      SpinReward(
        name: '10 Moji Coins',
        type: SpinRewardType.points,
        description: 'A special bonus of 10 Moji Coins!',
        color: Colors.amber.shade500,
        iconName: 'monetization_on_rounded',
        japaneseText: 'コイン',
      ),
      SpinReward(
        name: 'Premium Theme',
        type: SpinRewardType.theme,
        description: 'Unlock a beautiful premium theme for the app!',
        color: Colors.pink.shade500,
        iconName: 'palette_rounded',
        japaneseText: 'テーマ',
      ),
      SpinReward(
        name: 'Learning Streak',
        type: SpinRewardType.booster,
        description: 'Get a 3-day learning streak bonus!',
        color: Colors.orange.shade500,
        iconName: 'local_fire_department_rounded',
        japaneseText: 'ストリーク',
      ),
      SpinReward(
        name: '20 Moji Coins',
        type: SpinRewardType.points,
        description: 'A generous bonus of 20 Moji Coins!',
        color: Colors.indigo.shade500,
        iconName: 'monetization_on_rounded',
        japaneseText: 'コイン',
      ),
      SpinReward(
        name: 'Grammar Master',
        type: SpinRewardType.lesson,
        description: 'Unlock a special grammar lesson pack!',
        color: Colors.teal.shade500,
        iconName: 'school_rounded',
        japaneseText: '文法',
      ),
      SpinReward(
        name: 'Pronunciation Guide',
        type: SpinRewardType.lesson,
        description: 'Get access to advanced pronunciation lessons!',
        color: Colors.cyan.shade500,
        iconName: 'record_voice_over_rounded',
        japaneseText: '発音',
      ),
      SpinReward(
        name: 'Writing Practice',
        type: SpinRewardType.lesson,
        description: 'Unlock special writing practice exercises!',
        color: Colors.brown.shade500,
        iconName: 'edit_rounded',
        japaneseText: '書き方',
      ),
      SpinReward(
        name: 'Listening Skills',
        type: SpinRewardType.lesson,
        description: 'Get access to advanced listening exercises!',
        color: Colors.deepOrange.shade500,
        iconName: 'hearing_rounded',
        japaneseText: 'リスニング',
      ),
      SpinReward(
        name: '15 Moji Coins',
        type: SpinRewardType.points,
        description: 'A special bonus of 15 Moji Coins!',
        color: Colors.lightBlue.shade500,
        iconName: 'monetization_on_rounded',
        japaneseText: 'コイン',
      ),
    ];

    // Randomly select a surprise gift
    final random = math.Random();
    final selectedGift = surpriseGifts[random.nextInt(surpriseGifts.length)];

    // Show the surprise gift dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85, // Constrain width
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(
              color: Colors.purple.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Surprise text with animation
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: const Text(
                  'Surprise!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                    shadows: [
                      Shadow(
                        color: Colors.purple,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Gift icon with animated background
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1000),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          selectedGift.color.withOpacity(0.1),
                          selectedGift.color.withOpacity(0.3),
                          selectedGift.color.withOpacity(0.1),
                        ],
                        stops: [0, value, 1],
                        transform: GradientRotation(value * 3 * 3.14),
                      ),
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  selectedGift.icon,
                  color: selectedGift.color,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              // Gift name with shimmer effect
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    selectedGift.color,
                    selectedGift.color.withOpacity(0.7),
                    selectedGift.color,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  transform: const GradientRotation(3.14 / 4),
                ).createShader(bounds),
                child: Text(
                  selectedGift.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center, // Center text
                ),
              ),
              const SizedBox(height: 16),
              // Description with animated border
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selectedGift.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selectedGift.color.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  selectedGift.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              // Claim button with gradient
              ElevatedButton(
                onPressed: _isClaimingReward
                    ? null
                    : () async {
                        setState(() {
                          _isClaimingReward = true;
                        });

                        // Close the modal immediately to prevent multiple clicks
                        Navigator.of(dialogContext).pop();

                        debugPrint('Claim button pressed for gift: ${selectedGift.name}');
                        debugPrint('Gift type: ${selectedGift.type}');
                        debugPrint(
                            'Contains Moji Coins: ${selectedGift.name.contains('Moji Coins')}');
                        debugPrint('Contains Coins: ${selectedGift.name.contains('Coins')}');

                        try {
                          // Handle Moji Coins specially
                          if (selectedGift.name.contains('Moji Coins') ||
                              selectedGift.name.contains('Coins')) {
                            debugPrint('Calling _addPointsFromReward for Moji Coins');
                            await _addPointsFromReward(selectedGift);
                          } else if (selectedGift.type == SpinRewardType.points) {
                            debugPrint('Calling _addPointsFromReward for points');
                            await _addPointsFromReward(selectedGift);
                          } else {
                            debugPrint('Calling _addRewardToInventory for other rewards');
                            await _addRewardToInventory(selectedGift);
                          }
                        } catch (e) {
                          debugPrint('Error processing gift: $e');
                        } finally {
                          // Reset claiming state
                          if (mounted) {
                            setState(() {
                              _isClaimingReward = false;
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  backgroundColor: selectedGift.color,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: selectedGift.color.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isClaimingReward)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Icon(
                        selectedGift.type == SpinRewardType.points
                            ? Icons.star_rounded
                            : Icons.card_giftcard_rounded,
                        size: 24,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isClaimingReward ? 'Claiming...' : 'Claim Gift',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

  Future<void> _loadCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _streakCount = prefs.getInt('current_streak') ?? 0;
    });
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Update next claim time
        _updateClaimStatus();

        // Force rebuild to update the spin reset timer
        // This will trigger the FutureBuilder in _buildSpinningWheelSection
      });
    });
  }

  Future<void> _updateClaimStatus() async {
    final dailyPointsService = DailyPointsService();
    final canClaim = await dailyPointsService.canClaimDailyPoints();
    final lastClaimTime = await dailyPointsService.getLastClaimTime();
    final streak = await dailyPointsService.getCurrentStreak();

    setState(() {
      _canClaim = canClaim;
      _streakCount = streak;
      if (lastClaimTime != null) {
        _nextClaimTime = lastClaimTime.add(const Duration(hours: 24));
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _giftAnimationController.dispose();
    _countdownTimer.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      await _updateClaimStatus();
      await _loadSavedState();
      await _checkForUnclaimedGifts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetClaimTimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_daily_claim');
    await prefs.remove('daily_points_streak');

    setState(() {
      _canClaim = true;
      _nextClaimTime = DateTime.now();
      _streakCount = 0;
    });
  }

  Future<void> _resetSpins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('spins_remaining', 3);
    setState(() {
      _spinsRemaining = 3;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spins reset successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _checkForUnclaimedGifts() async {
    final prefs = await SharedPreferences.getInstance();
    final lastGiftCheck = prefs.getString('last_gift_check');
    final today = DateTime.now().toIso8601String().split('T')[0];

    // For demo purposes, randomly generate unclaimed gifts
    // In a real app, this would check a server for actual gifts
    if (lastGiftCheck != today) {
      final random = math.Random();
      final hasGifts = random.nextBool();
      final giftCount = hasGifts ? random.nextInt(3) + 1 : 0;

      setState(() {
        _hasUnclaimedGifts = hasGifts;
        _unclaimedGiftsCount = giftCount;
      });

      await prefs.setString('last_gift_check', today);
      await prefs.setBool('has_unclaimed_gifts', hasGifts);
      await prefs.setInt('unclaimed_gifts_count', giftCount);
    } else {
      setState(() {
        _hasUnclaimedGifts = prefs.getBool('has_unclaimed_gifts') ?? false;
        _unclaimedGiftsCount = prefs.getInt('unclaimed_gifts_count') ?? 0;
      });
    }
  }

  Future<void> _openGift() async {
    if (_isOpeningGift || !_hasUnclaimedGifts) return;

    setState(() {
      _isOpeningGift = true;
    });

    _giftAnimationController.forward().then((_) {
      _giftAnimationController.reverse();
    });

    _playSound(_giftOpenSound);

    // Simulate gift opening delay
    await Future.delayed(const Duration(milliseconds: 1500));

    // Generate random reward
    final random = math.Random();
    final rewardTypes = [
      SpinRewardType.kanji,
      SpinRewardType.vocabulary,
      SpinRewardType.booster,
      SpinRewardType.powerup,
    ];

    final rewardType = rewardTypes[random.nextInt(rewardTypes.length)];
    final reward = _getRandomRewardByType(rewardType);

    // Update unclaimed gifts count
    setState(() {
      _unclaimedGiftsCount--;
      _hasUnclaimedGifts = _unclaimedGiftsCount > 0;
      _isOpeningGift = false;
    });

    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_unclaimed_gifts', _hasUnclaimedGifts);
    await prefs.setInt('unclaimed_gifts_count', _unclaimedGiftsCount);

    // Show reward dialog
    _showRewardDialog(reward);
  }

  SpinReward _getRandomRewardByType(SpinRewardType type) {
    final rewardsOfType = _spinRewards.where((r) => r.type == type).toList();
    final random = math.Random();
    return rewardsOfType[random.nextInt(rewardsOfType.length)];
  }

  void _showRewardDialog(SpinReward reward) {
    _playSound(_winSound);

    // Show an engaging reward dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85, // Constrain width
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: reward.color.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(
              color: reward.color.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reward Icon with animated background
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1000),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          reward.color.withOpacity(0.1),
                          reward.color.withOpacity(0.3),
                          reward.color.withOpacity(0.1),
                        ],
                        stops: [0, value, 1],
                        transform: GradientRotation(value * 3 * 3.14),
                      ),
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  reward.icon,
                  color: reward.color,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              // Animated congratulations text
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: reward.color,
                    shadows: [
                      Shadow(
                        color: reward.color.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Reward name with shimmer effect
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    reward.color,
                    reward.color.withOpacity(0.7),
                    reward.color,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  transform: const GradientRotation(3.14 / 4),
                ).createShader(bounds),
                child: Text(
                  reward.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center, // Center text
                ),
              ),
              const SizedBox(height: 16),
              // Description with animated border
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: reward.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: reward.color.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  reward.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              // Tip section with icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      color: reward.color,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getRewardTip(reward.type),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Claim button with gradient
              ElevatedButton(
                onPressed: _isClaimingReward
                    ? null
                    : () async {
                        setState(() {
                          _isClaimingReward = true;
                        });

                        // Close the modal immediately to prevent multiple clicks
                        Navigator.of(dialogContext).pop();

                        debugPrint('Claim button pressed for reward: ${reward.name}');
                        debugPrint('Reward type: ${reward.type}');
                        debugPrint('Contains Moji Coins: ${reward.name.contains('Moji Coins')}');
                        debugPrint('Contains Coins: ${reward.name.contains('Coins')}');

                        try {
                          if (reward.type == SpinRewardType.points) {
                            debugPrint('Calling _addPointsFromReward for points');
                            await _addPointsFromReward(reward);
                          } else {
                            debugPrint('Calling _addRewardToInventory for other rewards');
                            await _addRewardToInventory(reward);
                          }
                        } catch (e) {
                          debugPrint('Error processing reward: $e');
                        } finally {
                          // Reset claiming state
                          if (mounted) {
                            setState(() {
                              _isClaimingReward = false;
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  backgroundColor: reward.color,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: reward.color.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isClaimingReward)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Icon(
                        reward.type == SpinRewardType.points
                            ? Icons.star_rounded
                            : Icons.card_giftcard_rounded,
                        size: 24,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isClaimingReward ? 'Claiming...' : 'Claim Reward',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

  String _getRewardTip(SpinRewardType type) {
    return _spinRewardService.getRewardTip(type);
  }

  String _getCountdownText() {
    if (_canClaim) return 'Ready to claim!';

    final now = DateTime.now();
    final difference = _nextClaimTime.difference(now);

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width >= 360 && screenSize.width < 600;

    // Calculate responsive dimensions
    final horizontalPadding = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 16.0
            : 24.0;
    final verticalPadding = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 16.0
            : 24.0;
    final cardSpacing = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 16.0
            : 24.0;
    final iconSize = isSmallScreen
        ? 20.0
        : isMediumScreen
            ? 24.0
            : 28.0;
    final titleFontSize = isSmallScreen
        ? 18.0
        : isMediumScreen
            ? 20.0
            : 24.0;
    final subtitleFontSize = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 14.0
            : 16.0;
    final wheelSize = isSmallScreen
        ? 250.0
        : isMediumScreen
            ? 300.0
            : 350.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daily Rewards',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            fontFamily: "TheLastShuriken",
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_hasUnclaimedGifts)
            Stack(
              children: [
                IconButton(
                  icon: AnimatedBuilder(
                    animation: _giftAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isOpeningGift ? _giftScaleAnimation.value : 1.0,
                        child: Transform.rotate(
                          angle: _isOpeningGift ? _giftRotateAnimation.value : 0,
                          child: Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.amber,
                            size: iconSize,
                          ),
                        ),
                      );
                    },
                  ),
                  onPressed: _openGift,
                  tooltip: 'Open Gift',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unclaimedGiftsCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 8 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          if (_isDevMode) ...[
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: iconSize),
              onPressed: _resetClaimTimer,
              tooltip: 'Reset Timer (Dev Mode)',
            ),
            IconButton(
              icon: Icon(Icons.casino_rounded, size: iconSize),
              onPressed: _resetSpins,
              tooltip: 'Reset Spins (Dev Mode)',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshData,
        color: primaryColor,
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
                // Animated header with confetti effect
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
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.celebration_rounded,
                            color: primaryColor,
                            size: iconSize,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rewards',
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              Text(
                                'Claim your rewards and spin to win!',
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

                // Timer section with animation
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
                  child: _buildTimerSection(context, isDarkMode, isSmallScreen, isMediumScreen),
                ),
                SizedBox(height: cardSpacing),

                // Streak section with animation
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
                  child: _buildStreakSection(context, isDarkMode, isSmallScreen, isMediumScreen),
                ),
                SizedBox(height: cardSpacing * 1.5),

                // Spinning wheel section with animation
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
                  child: _buildSpinningWheelSection(context, isDarkMode, wheelSize),
                ),
                SizedBox(height: cardSpacing * 1.5),

                // Total points section with animation
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
                  child:
                      _buildTotalPointsSection(context, isDarkMode, isSmallScreen, isMediumScreen),
                ),
                SizedBox(height: cardSpacing * 1.5),

                // Bottom tip with animation
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
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          color: Colors.amber,
                          size: iconSize,
                        ),
                        SizedBox(width: isSmallScreen ? 12 : 16),
                        Expanded(
                          child: Text(
                            'Come back daily to maintain your streak and earn more rewards!',
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildTimerSection(
      BuildContext context, bool isDarkMode, bool isSmallScreen, bool isMediumScreen) {
    final iconSize = isSmallScreen
        ? 20.0
        : isMediumScreen
            ? 24.0
            : 28.0;
    final titleFontSize = isSmallScreen
        ? 16.0
        : isMediumScreen
            ? 18.0
            : 20.0;
    final subtitleFontSize = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 14.0
            : 16.0;
    final padding = isSmallScreen
        ? 16.0
        : isMediumScreen
            ? 20.0
            : 24.0;

    return Container(
      margin: EdgeInsets.only(top: isSmallScreen ? 12 : 16),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Tooltip(
                  message: _canClaim
                      ? 'Claim your daily Moji Points now!'
                      : 'Time until your next daily Moji Points are available',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _canClaim ? 'Daily Moji Points Ready!' : 'Next Moji Points In:',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_canClaim) ...[
                            SizedBox(width: isSmallScreen ? 4 : 8),
                            Icon(
                              Icons.timer_outlined,
                              color: Colors.white.withOpacity(0.8),
                              size: iconSize * 0.8,
                            ),
                          ],
                        ],
                      ),
                      if (!_canClaim) ...[
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTimeUnitForDaily(_getCountdownText().split(':')[0], 'HOURS',
                                isDarkMode, isSmallScreen),
                            _buildTimeSeparatorForDaily(isDarkMode, isSmallScreen),
                            _buildTimeUnitForDaily(_getCountdownText().split(':')[1], 'MINUTES',
                                isDarkMode, isSmallScreen),
                            _buildTimeSeparatorForDaily(isDarkMode, isSmallScreen),
                            _buildTimeUnitForDaily(_getCountdownText().split(':')[2], 'SECONDS',
                                isDarkMode, isSmallScreen),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Stack(
                children: [
                  _canClaim
                      ? AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isClaiming ? _scaleAnimation.value : 1.0,
                              child: Transform.rotate(
                                angle: _isClaiming ? _rotateAnimation.value : 0,
                                child: child,
                              ),
                            );
                          },
                          child: ElevatedButton(
                            onPressed: () => _handleDailyPointsClaim(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).primaryColor,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 24,
                                vertical: isSmallScreen ? 8 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.stars_rounded,
                                  size: iconSize * 0.8,
                                ),
                                SizedBox(width: isSmallScreen ? 4 : 8),
                                const Text(
                                  'Claim',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: math.pi / 2 * _animationController.value,
                              child: Icon(
                                Icons.hourglass_empty,
                                size: iconSize * 2,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ],
          ),
          if (_canClaim) ...[
            SizedBox(height: isSmallScreen ? 8 : 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: iconSize * 0.8,
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Flexible(
                  child: Text(
                    'Your daily Moji Points are waiting!',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeUnitForDaily(String value, String label, bool isDarkMode, bool isSmallScreen) {
    final fontSize = isSmallScreen ? 16.0 : 20.0; // Reduced font size
    final labelFontSize = isSmallScreen ? 8.0 : 10.0;
    final padding = isSmallScreen ? 6.0 : 8.0; // Reduced padding

    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0.8, end: 1.0),
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: padding / 2,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8), // Smaller radius
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 2 : 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeSeparatorForDaily(bool isDarkMode, bool isSmallScreen) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0.8, end: 1.0),
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4), // Reduced padding
            child: Text(
              ':',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 20, // Reduced font size
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.8),
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakSection(
      BuildContext context, bool isDarkMode, bool isSmallScreen, bool isMediumScreen) {
    final iconSize = isSmallScreen
        ? 20.0
        : isMediumScreen
            ? 24.0
            : 28.0;
    final titleFontSize = isSmallScreen
        ? 14.0
        : isMediumScreen
            ? 16.0
            : 18.0;
    final subtitleFontSize = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 14.0
            : 16.0;
    final padding = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 16.0
            : 20.0;

    return Tooltip(
      message: 'Maintain your daily streak to earn bonus Moji Points!',
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orange,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Current Streak: $_streakCount days',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 4 : 8),
                          Icon(
                            Icons.info_outline,
                            size: iconSize * 0.8,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        _getStreakMessage(),
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis, // Handle text overflow
                        maxLines: 2, // Allow up to 2 lines
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            LinearProgressIndicator(
              value: _streakCount >= 3 ? 1.0 : _streakCount / 3,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _streakCount >= 3 ? Colors.orange : Colors.orange.withOpacity(0.5),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 day',
                  style: TextStyle(
                    fontSize: subtitleFontSize * 0.8,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '2x bonus at 3 days',
                  style: TextStyle(
                    fontSize: subtitleFontSize * 0.8,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStreakMessage() {
    if (_streakCount >= 3) {
      return '2x Moji Points bonus active! Keep it up!';
    } else if (_streakCount >= 2) {
      return '1.5x Moji Points bonus active! One more day for 2x!';
    } else if (_streakCount == 1) {
      return 'Come back tomorrow for a 1.5x bonus!';
    } else {
      return 'Start a streak to earn bonus Moji Points!';
    }
  }

  Widget _buildSpinningWheelSection(BuildContext context, bool isDarkMode, double wheelSize) {
    final iconSize = wheelSize * 0.08;
    final titleFontSize = wheelSize * 0.08;
    final subtitleFontSize = wheelSize * 0.05;
    final padding = wheelSize * 0.08;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Spin the wheel to win exciting rewards!',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Spin & Win',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(width: padding * 0.5),
                          Icon(
                            Icons.info_outline,
                            size: iconSize * 0.8,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                      SizedBox(height: padding * 0.5),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: padding * 0.75,
                          vertical: padding * 0.375,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: iconSize * 0.8,
                              color: Colors.amber,
                            ),
                            SizedBox(width: padding * 0.25),
                            Text(
                              '$_spinsRemaining spins left',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: subtitleFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(padding * 0.5),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: Theme.of(context).primaryColor,
                  size: iconSize,
                ),
              ),
            ],
          ),
          SizedBox(height: padding * 1.5),
          if (_spinsRemaining > 0)
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1500),
              tween: Tween<double>(begin: 0.95, end: 1.05),
              curve: Curves.easeInOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: SizedBox(
                height: wheelSize,
                width: wheelSize,
                child: SpinningWheel(
                  rewards: _spinRewards,
                  onSpinEnd: (reward) {
                    _handleSpinEnd(reward);
                  },
                  onSpinStart: () {
                    _handleSpin();
                  },
                  enabled: _spinsRemaining > 0,
                ),
              ),
            )
          else
            SizedBox(
              height: wheelSize,
              width: wheelSize,
              child: SpinningWheel(
                rewards: _spinRewards,
                onSpinEnd: (reward) {
                  _handleSpinEnd(reward);
                },
                onSpinStart: () {
                  _handleSpin();
                },
                enabled: _spinsRemaining > 0,
              ),
            ),
          SizedBox(height: padding),
          if (_spinsRemaining > 0)
            Container(
              padding: EdgeInsets.symmetric(
                vertical: padding * 0.75,
                horizontal: padding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: Theme.of(context).primaryColor,
                    size: iconSize * 0.8,
                  ),
                  SizedBox(width: padding * 0.5),
                  Text(
                    'Tap the wheel to try your luck!',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: subtitleFontSize,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildSpinResetTimer(context, isDarkMode, wheelSize),
        ],
      ),
    );
  }

  Future<String> _getNextSpinResetTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpinDate = prefs.getString('last_spin_date');
    final today = DateTime.now().toIso8601String().split('T')[0];

    // If last spin date is today, calculate time until tomorrow
    if (lastSpinDate == today) {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final difference = tomorrow.difference(now);

      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;

      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      // If last spin date is not today, spins should be available now
      return '00:00:00';
    }
  }

  Widget _buildTimeUnit(String value, String label, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced padding
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2D42) : Colors.white,
        borderRadius: BorderRadius.circular(8), // Smaller radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.amber.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18, // Smaller font size
              fontWeight: FontWeight.bold,
              color: Colors.amber[700],
              shadows: [
                Shadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Text(
            label,
            style: TextStyle(
              fontSize: 8, // Smaller font size
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeparator(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4), // Reduced padding
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 18, // Smaller font size
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildTotalPointsSection(
      BuildContext context, bool isDarkMode, bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1500),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Total Moji Points Earned',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<int>(
            future: Future.wait([
              // Challenge points from ChallengeProgressService
              ChallengeProgressService().getTotalPoints(),
              // Review points from ReviewProgressService
              ReviewProgressService().getTotalReviewPoints(),
              // Story points from SharedPreferences (if any)
              SharedPreferences.getInstance()
                  .then((prefs) => prefs.getInt('story_total_points') ?? 0),
              // Quiz points from SharedPreferences (if any)
              SharedPreferences.getInstance()
                  .then((prefs) => prefs.getInt('quiz_total_points') ?? 0),
              // Daily points from DailyPointsService
              DailyPointsService().getLastClaimTime().then((lastClaim) async {
                if (lastClaim == null) return 0;
                final multiplier = await DailyPointsService().getStreakBonusMultiplier();
                return (100 * multiplier).round(); // Daily points amount
              }),
            ]).then(
                (results) => results.fold<int>(0, (sum, points) => sum + points)), // Sum all points
            builder: (context, snapshot) {
              final totalPoints = snapshot.data ?? 0;

              return Column(
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween<double>(begin: 0.0, end: totalPoints.toDouble()),
                    builder: (context, double value, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              shadows: [
                                Shadow(
                                  color: Colors.amber.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Moji Points',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 1500),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: const Icon(
                            Icons.trending_up_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Keep learning to earn more Points!',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Add conversion section
                  FutureBuilder<bool>(
                    future: CurrencyConversionService().canConvertToday(),
                    builder: (context, snapshot) {
                      final conversionService = CurrencyConversionService();
                      final minPoints = conversionService.getMinimumPointsForConversion();

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TweenAnimationBuilder(
                                      duration: const Duration(milliseconds: 1500),
                                      tween: Tween<double>(begin: 0.0, end: 1.0),
                                      builder: (context, double value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: child,
                                        );
                                      },
                                      child: Image.asset(
                                        'assets/images/coin.png',
                                        width: 20,
                                        height: 20,
                                        color: Colors.amber,
                                        colorBlendMode: BlendMode.modulate,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Convert Moji Points to Moji Coins',
                                        style: TextStyle(
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Exchange rate: 700 Moji Points = 1 Moji Coin',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                if (totalPoints >= minPoints) ...[
                                  const SizedBox(height: 16),
                                  TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 1500),
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    builder: (context, double value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: child,
                                      );
                                    },
                                    child: ElevatedButton(
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => CurrencyConversionModal(
                                            onConversionComplete: () {
                                              setState(() {
                                                _refreshData();
                                              });
                                            },
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                        shadowColor: Colors.blue.withOpacity(0.3),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/images/coin.png',
                                            width: 20,
                                            height: 20,
                                            color: Colors.amber,
                                            colorBlendMode: BlendMode.modulate,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Convert Points',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Need at least $minPoints Moji Points',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleDailyPointsClaim(BuildContext context) async {
    try {
      final dailyPointsService = DailyPointsService();
      final multiplier = await dailyPointsService.getStreakBonusMultiplier();
      await dailyPointsService.claimDailyPoints();

      // Base points for daily claim
      const basePoints = 100;
      final totalPoints = (basePoints * multiplier).round();

      // Update streak
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_streak', _streakCount + 1);

      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setBool('claimed_today_$today', true);

      _playSound(_claimSound);
      if (multiplier > 1) {
        _playSound(_streakSound);
      }

      // Update UI state
      setState(() {
        _streakCount++;
      });

      // Show success snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '+$totalPoints Moji Points${multiplier > 1 ? ' (${(multiplier * 100).toInt()}% bonus)' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Update UI state
      setState(() {
        _updateClaimStatus();
        _startCountdownTimer();
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim rewards: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Update the _addPointsFromReward method to properly handle Moji Coins
  Future<void> _addPointsFromReward(SpinReward reward) async {
    debugPrint('Adding points from reward: ${reward.name}');
    debugPrint('Reward type: ${reward.type}');
    debugPrint('Reward contains Moji Coins: ${reward.name.contains('Moji Coins')}');
    debugPrint('Reward contains Coins: ${reward.name.contains('Coins')}');

    // Special handling for Moji Coins
    if (reward.name.contains('Moji Coins') || reward.name.contains('Coins')) {
      debugPrint('Processing Moji Coins reward');
      // Extract the coin amount from the reward name
      int coinAmount = 0;
      final regex = RegExp(r'(\d+)');
      final match = regex.firstMatch(reward.name);
      if (match != null) {
        coinAmount = int.parse(match.group(1) ?? '0');
      }

      debugPrint('Extracted coin amount: $coinAmount');

      // Add coins directly to user's balance using CoinService
      final coinService = CoinService();
      await coinService.addCoins(coinAmount);
      debugPrint('Successfully added $coinAmount coins via CoinService');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Image.asset(
                  'assets/images/coin.png',
                  width: 24,
                  height: 24,
                  color: Colors.amber,
                  colorBlendMode: BlendMode.modulate,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '+$coinAmount Moji Coins added!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Play success sound
      _playSound(_winSound);
      return;
    }

    // Regular points handling (unchanged)
    int pointsToAdd = 0;
    if (reward.name.contains('50')) {
      pointsToAdd = 50;
    } else if (reward.name.contains('100')) {
      pointsToAdd = 100;
    } else if (reward.name.contains('200')) {
      pointsToAdd = 200;
    }

    // Add points to total
    final prefs = await SharedPreferences.getInstance();
    final currentPoints = prefs.getInt('total_points') ?? 0;
    final newTotalPoints = currentPoints + pointsToAdd;
    await prefs.setInt('total_points', newTotalPoints);

    // Sync to Firebase
    final firebaseSync = FirebaseUserSyncService();
    await firebaseSync.syncMojiPoints(newTotalPoints);

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '+$pointsToAdd Moji Points added!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    // Play success sound
    _playSound(_winSound);
  }

  Future<void> _addRewardToInventory(SpinReward reward) async {
    debugPrint('Adding reward to inventory: ${reward.name}');

    // Special handling for Moji Coins
    if (reward.name.contains('Moji Coins') || reward.name.contains('Coins')) {
      // Extract the coin amount from the reward name using regex
      int coinAmount = 0;
      final regex = RegExp(r'(\d+)');
      final match = regex.firstMatch(reward.name);
      if (match != null) {
        coinAmount = int.parse(match.group(1) ?? '0');
      }

      // Add coins directly to user's balance using CoinService
      final coinService = CoinService();
      await coinService.addCoins(coinAmount);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Image.asset(
                  'assets/images/coin.png',
                  width: 24,
                  height: 24,
                  color: Colors.amber,
                  colorBlendMode: BlendMode.modulate,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '+$coinAmount Moji Coins added!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Play success sound
      _playSound(_winSound);
      return;
    }

    // Handle points rewards
    if (reward.type == SpinRewardType.points) {
      await _addPointsFromReward(reward);
      return;
    }

    // Map SpinRewardType to the correct category name (matching shop categories)
    String category;
    switch (reward.type) {
      case SpinRewardType.booster:
        category = 'Boosters';
        break;
      case SpinRewardType.powerup:
        category = 'Power-ups';
        break;
      case SpinRewardType.lesson:
        category = 'Tickets';
        break;
      case SpinRewardType.kanji:
        category = 'Tickets'; // Match shop category for Kanji Pack
        break;
      case SpinRewardType.vocabulary:
        category = 'Tickets'; // Match shop category for Lesson Ticket
        break;
      case SpinRewardType.premium:
      case SpinRewardType.theme:
      case SpinRewardType.badge:
        category = 'Special';
        break;
      default:
        category = 'Special';
    }

    // Create a new inventory item with normalized name
    final normalizedName = _inventoryService.normalizeName(reward.name);
    debugPrint(
        'Creating inventory item with: originalName=${reward.name}, normalizedName=$normalizedName, iconName=${reward.iconName}, type=${reward.type}');

    final newItem = InventoryItem(
      name: normalizedName, // Use normalized name directly
      description: reward.description,
      iconName: reward.iconName,
      color: reward.color,
      obtainedDate: DateTime.now(),
      isUsed: false,
      type: category,
    );

    debugPrint(
        'Created inventory item: ${newItem.name} (${newItem.type}) with icon: ${newItem.iconName}');

    try {
      // Add the item to inventory
      await _inventoryService.addItem(newItem);
      debugPrint('Successfully added item to inventory');

      // Verify the item was added
      final items = await _inventoryService.loadInventory();
      debugPrint('Current inventory items: ${items.length}');

      // Count how many of this item exist (using normalized name for comparison)
      final itemCount = items
          .where((item) =>
              _inventoryService.normalizeName(item.name) == normalizedName &&
              item.type == newItem.type &&
              !item.isUsed)
          .length;

      debugPrint('There are now $itemCount ${normalizedName}(s) in inventory');

      // Debug: Print current inventory state
      await _inventoryService.debugPrintInventory();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${reward.name} added to your inventory!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding item to inventory: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reward to inventory: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSpinResetTimer(BuildContext context, bool isDarkMode, double wheelSize) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2D42) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.amber.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_rounded,
                color: Colors.amber[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Next Spins Available In',
                  style: TextStyle(
                    color: Colors.amber[700],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: _getNextSpinResetTime(),
            builder: (context, snapshot) {
              final resetTime = snapshot.data ?? '00:00:00';
              final timeParts = resetTime.split(':');

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeUnit(timeParts[0], 'HOURS', isDarkMode),
                  _buildTimeSeparator(isDarkMode),
                  _buildTimeUnit(timeParts[1], 'MINUTES', isDarkMode),
                  _buildTimeSeparator(isDarkMode),
                  _buildTimeUnit(timeParts[2], 'SECONDS', isDarkMode),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: Colors.amber[700],
                ),
                const SizedBox(width: 8),
                Text(
                  '3 new spins coming soon!',
                  style: TextStyle(
                    color: Colors.amber[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
