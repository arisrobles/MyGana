import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'package:nihongo_japanese_app/models/japanese_character.dart';
import 'package:nihongo_japanese_app/models/user_progress.dart';
import 'package:nihongo_japanese_app/services/openai_vision_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:nihongo_japanese_app/services/simple_character_recognition_service.dart';

class CharacterDrawingBoard extends StatefulWidget {
  final JapaneseCharacter character;
  final bool showStrokeOrder;
  final bool showHints;
  final Function(bool)? onExpandStateChanged;
  final bool initialExpandedState;
  final bool showSvgGuideline;
  final bool enableRecognition;
  final bool enableRealTimeRecognition;
  final Function(RecognitionResult)? onRecognitionComplete;
  final VoidCallback? onExitToSelection;

  const CharacterDrawingBoard({
    super.key,
    required this.character,
    this.showStrokeOrder = true,
    this.showHints = true,
    this.onExpandStateChanged,
    this.initialExpandedState = true,
    this.showSvgGuideline = true,
    this.enableRecognition = true,
    this.enableRealTimeRecognition = true,
    this.onRecognitionComplete,
    this.onExitToSelection,
  });

  @override
  State<CharacterDrawingBoard> createState() => _CharacterDrawingBoardState();
}

class _CharacterDrawingBoardState extends State<CharacterDrawingBoard>
    with SingleTickerProviderStateMixin {
  List<List<Offset>> _userStrokes = [];
  List<Offset> _currentStroke = [];
  bool _isDrawing = false;

  // Current stroke hint
  final int _currentStrokeHint = 0;
  final bool _showingHint = false;
  final bool _showStrokeDirections = false;

  late AnimationController _animationController;

  // Grid for alignment
  bool _showGrid = true;
  bool _showSvgGuideline = true;

  // Drawing settings - enhanced for better user experience
  final Color _strokeColor = Colors.deepPurple;
  final double _minBrushWidth = 4.0; // Slightly thicker for better visibility
  final double _maxBrushWidth = 16.0; // More dynamic range
  double _brushScale = 1.0; // User-adjustable brush size multiplier

  // Drawing mode
  final bool _isGuidedMode = true;

  // Painter controller
  // late PainterController _painterController;

  // Recognition and feedback
  final ProgressService _progressService = ProgressService();
  RecognitionResult? _lastRecognitionResult;
  RecognitionResult? _realTimeResult;
  bool _isRecognizing = false;
  bool _showRecognitionResult = false;
  bool _showRealTimeFeedback = false;
  bool _showDetailedFeedback = false;
  String? _lastMarkLabel; // Excellent, Goods, Failed
  bool _lastMarkPassing = false;
  String? _lastHandwrittenImageBase64;
  String? _lastReferenceImageBase64;
  late ConfettiController _confettiController;

  // Real-time recognition timer (disabled for manual checking)
  // Timer? _recognitionTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      }
    });

    // Initialize painter controller
    // _painterController = PainterController();

    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    // Initialize progress service
    _progressService.initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // _painterController.dispose();
    _confettiController.dispose();
    // Timer removed - using manual check only
    super.dispose();
  }

  void _clearDrawing() {
    setState(() {
      _userStrokes = [];
      _currentStroke = [];
      _isDrawing = false;
      _showRecognitionResult = false;
      _showRealTimeFeedback = false;
      _lastRecognitionResult = null;
      _realTimeResult = null;

      // Clear painter
      // _painterController.clear();
    });

    // No automatic recognition - manual check only
  }

  // Real-time recognition methods disabled - using manual check only
  /*
  void _triggerRealTimeRecognition() {
    if (!widget.enableRealTimeRecognition || _userStrokes.isEmpty) return;

    // Cancel previous timer
    // Timer removed - using manual check only

    // Set a longer delay to avoid too frequent recognition and improve performance
    // Timer assignment removed - using manual check only
      if (_userStrokes.isNotEmpty && mounted) {
        await _performRealTimeRecognition();
      }
    });
  }

  Future<void> _performRealTimeRecognition() async {
    if (_userStrokes.isEmpty) return;

    try {
      final result = await CharacterRecognitionService.recognizeCharacter(
        _userStrokes,
        widget.character,
      );

      setState(() {
        _realTimeResult = result;
        _showRealTimeFeedback = true;
      });

      // Auto-hide real-time feedback after 3 seconds for better user experience
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showRealTimeFeedback = false;
          });
        }
      });
    }
  }
  */

  Future<void> _testApi() async {
    try {
      debugPrint('🧪 Testing recognition service...');

      final isWorking = await OpenAIVisionService.testApiKey();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isWorking
                  ? '✅ Recognition service is working!'
                  : '❌ Recognition service unavailable!',
            ),
            backgroundColor: isWorking ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Service test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Service test error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _checkCharacter() async {
    if (!widget.enableRecognition || _userStrokes.isEmpty) return;

    setState(() {
      _isRecognizing = true;
    });

    try {
      final resultWithImages = await CharacterRecognitionService.recognizeCharacterWithImages(
        _userStrokes,
        widget.character,
      );

      setState(() {
        _lastRecognitionResult = resultWithImages.recognitionResult;
        _lastHandwrittenImageBase64 = resultWithImages.handwrittenImageBase64;
        _lastReferenceImageBase64 = resultWithImages.referenceImageBase64;
        _showRecognitionResult = true;
        _isRecognizing = false;
        // Compute mark label and pass/fail
        _lastMarkLabel = _computeMarkLabel(_lastRecognitionResult?.accuracyScore ?? 0.0);
        _lastMarkPassing = _lastMarkLabel == 'Excellent' || _lastMarkLabel == 'Goods';
      });

      // Update progress only for passing marks
      if (_lastMarkPassing) {
        await _updateProgress(resultWithImages.recognitionResult);
      }

      // Show confetti for correct recognition
      if (resultWithImages.recognitionResult.isCorrect) {
        _confettiController.play();
        // Add success haptic feedback
        HapticFeedback.mediumImpact();
      } else {
        // Add gentle feedback for incorrect attempt
        HapticFeedback.lightImpact();
      }

      // Notify parent widget
      widget.onRecognitionComplete?.call(resultWithImages.recognitionResult);

      // Keep results visible permanently - no auto-hide
    } catch (e) {
      setState(() {
        _isRecognizing = false;
      });
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recognition failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _computeMarkLabel(double accuracyPercent) {
    // accuracyPercent expected 0-100
    if (accuracyPercent >= 90.0) return 'Excellent';
    if (accuracyPercent >= 70.0) return 'Goods';
    return 'Failed';
  }

  Future<void> _updateProgress(RecognitionResult result) async {
    try {
      final double accuracyScore = (result.accuracyScore ?? 0.0);
      final evaluation = StrokeEvaluation(
        strokeCountScore: result.isCorrect ? 100.0 : 50.0,
        strokeOrderScore: result.isCorrect ? 100.0 : 50.0,
        positionScore: result.accuracyScore ?? 0.0,
        directionScore: result.accuracyScore ?? 0.0,
        overallScore: result.accuracyScore ?? 0.0,
        evaluatedAt: DateTime.now(),
      );

      await _progressService.updateCharacterMastery(
        widget.character,
        accuracyScore,
        evaluation,
      );
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double toolbarScale = _toolbarScale(context);
    final double horizontalPad = (8.0 * toolbarScale).clamp(4.0, 8.0);
    final double verticalPad = (6.0 * toolbarScale).clamp(3.0, 6.0);
    final double gap = (4.0 * toolbarScale).clamp(2.0, 4.0);
    final double bottomOffset = math.max(8.0, 16.0 * toolbarScale);

    return Stack(
      children: [
        // Background grid
        if (_showGrid)
          CustomPaint(
            painter: GridPainter(
              color: colorScheme.onSurface.withAlpha((0.1 * 255).round()),
              centerColor: colorScheme.primary.withAlpha((0.2 * 255).round()),
            ),
            child: Container(),
          ),

        // SVG guideline for tracing
        if (_showSvgGuideline && widget.character.fullSvgPath != null) _buildSvgGuideline(),

        // Stroke order guide (if stroke data becomes available)
        if (widget.showStrokeOrder && widget.character.strokeOrder.isNotEmpty && _isGuidedMode)
          CustomPaint(
            painter: StrokeOrderPainter(
              strokes: widget.character.strokeOrder,
              currentStroke: _currentStrokeHint,
              showAllStrokes: _showingHint,
              color: colorScheme.primary.withAlpha((0.3 * 255).round()),
            ),
            child: Container(),
          ),

        // User's drawing using Painter
        GestureDetector(
          onPanStart: (details) {
            final size = context.size!;

            // Add haptic feedback for better user experience
            HapticFeedback.lightImpact();

            setState(() {
              _isDrawing = true;
              _currentStroke = [
                Offset(
                  details.localPosition.dx / size.width,
                  details.localPosition.dy / size.height,
                ),
              ];
            });
          },
          onPanUpdate: (details) {
            if (_isDrawing) {
              final size = context.size!;
              final currentPoint = details.localPosition;

              setState(() {
              // Create a new list so the painter detects the change and repaints
              final updated = List<Offset>.from(_currentStroke)
                ..add(
                  Offset(
                    currentPoint.dx / size.width,
                    currentPoint.dy / size.height,
                  ),
                );
              _currentStroke = updated;
              });
            }
          },
          onPanEnd: (details) {
            setState(() {
              _isDrawing = false;
              if (_currentStroke.isNotEmpty) {
                _userStrokes.add(List.from(_currentStroke));
                _currentStroke = [];

                // No automatic recognition - user will manually check
              }
            });
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: BrushDrawingPainter(
                strokes: _userStrokes,
                currentStroke: _currentStroke,
                strokeColor: _strokeColor,
                minStrokeWidth: _minBrushWidth * _brushScale,
                maxStrokeWidth: _maxBrushWidth * _brushScale,
              ),
              child: Container(),
            ),
          ),
        ),

        // Stroke direction hint
        if (widget.showHints && _showStrokeDirections && widget.character.strokeDirections != null)
          _buildStrokeDirectionHint(),

        // Real-time feedback overlay
        if (_showRealTimeFeedback && _realTimeResult != null) _buildRealTimeFeedbackOverlay(),

        // Recognition result overlay
        if (_showRecognitionResult && _lastRecognitionResult != null)
          _buildRecognitionResultOverlay(),

        // Recognition loading overlay
        if (_isRecognizing) _buildRecognitionLoadingOverlay(),

        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: math.pi / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 20,
            minBlastForce: 10,
            gravity: 0.1,
          ),
        ),

        // Drawing tools - compact version for fullscreen
        Positioned(
          bottom: bottomOffset,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
              decoration: BoxDecoration(
                color: colorScheme.surface.withAlpha((0.85 * 255).round()),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.15 * 255).round()),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactToolButton(
                      icon: Icons.brush,
                      isActive: true,
                      onPressed: _showBrushSizeDialog,
                      tooltip: 'Brush',
                    ),
                    SizedBox(width: gap),
                    _buildCompactToolButton(
                      icon: Icons.undo,
                      onPressed: (_currentStroke.isNotEmpty || _userStrokes.isNotEmpty)
                          ? () {
                              if (_currentStroke.isNotEmpty) {
                                setState(() {
                                  _currentStroke = <Offset>[]; // new instance for instant repaint
                                });
                              } else if (_userStrokes.isNotEmpty) {
                                setState(() {
                                  // Create a new list reference so the painter repaints immediately
                                  final copied = List<List<Offset>>.from(_userStrokes);
                                  copied.removeLast();
                                  _userStrokes = copied;
                                });
                              }
                              HapticFeedback.selectionClick();
                            }
                          : null,
                      isActive: _currentStroke.isNotEmpty || _userStrokes.isNotEmpty,
                      tooltip: 'Undo',
                    ),
                    SizedBox(width: gap),
                    _buildCompactToolButton(
                      icon: Icons.delete,
                      onPressed: _clearDrawing,
                      tooltip: 'Clear',
                    ),
                    SizedBox(width: gap),
                    _buildCompactToolButton(
                      icon: Icons.grid_on,
                      isActive: _showGrid,
                      onPressed: _toggleGrid,
                      tooltip: 'Toggle Grid',
                    ),
                    SizedBox(width: gap),
                    _buildCompactToolButton(
                      icon: Icons.format_shapes,
                      isActive: _showSvgGuideline,
                      onPressed: _toggleSvgGuideline,
                      tooltip: 'Toggle Guideline',
                    ),
                    if (widget.enableRecognition) ...[
                      SizedBox(width: gap),
                      _buildCompactToolButton(
                        icon: Icons.check_circle,
                        onPressed: _userStrokes.isNotEmpty ? _checkCharacter : null,
                        isActive: _userStrokes.isNotEmpty,
                        tooltip: 'Check Character',
                        color: _userStrokes.isNotEmpty ? Colors.green : null,
                      ),
                      SizedBox(width: gap),
                      _buildCompactToolButton(
                        icon: Icons.api,
                        onPressed: _testApi,
                        tooltip: 'Test Recognition Service',
                        color: Colors.blue,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactToolButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isActive = false,
    String? tooltip,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double scale = _toolbarScale(context);
    final double iconSize = (18.0 * scale).clamp(9.0, 16.0);
    final double padding = (8.0 * scale).clamp(2.0, 6.0);
    final double minSize = (36.0 * scale).clamp(22.0, 32.0);

    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: math.max(0.5, 1.5 * scale)),
        decoration: BoxDecoration(
          color: isActive
              ? color ?? colorScheme.primary
              : colorScheme.surface.withAlpha((0.5 * 255).round()),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            icon,
            color: isActive ? colorScheme.onPrimary : color ?? colorScheme.onSurface,
            size: iconSize,
          ),
          onPressed: onPressed,
          padding: EdgeInsets.all(padding),
          constraints: BoxConstraints(
            minWidth: minSize,
            minHeight: minSize,
          ),
          splashRadius: math.max(12.0, (minSize / 2) - 2),
        ),
      ),
    );
  }

  double _toolbarScale(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width <= 320) return 0.6; // very small phones
    if (width <= 360) return 0.75; // small phones
    if (width <= 400) return 0.85; // compact width
    return 1.0; // default
  }

  void _showBrushSizeDialog() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        double tempScale = _brushScale;
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Brush Size', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Small'),
                      Expanded(
                        child: Slider(
                          value: tempScale,
                          onChanged: (v) {
                            setStateDialog(() {
                              tempScale = v;
                            });
                            // Live update preview
                            setState(() {
                              _brushScale = v;
                            });
                          },
                          min: 0.4,
                          max: 1.6,
                          divisions: 12,
                          label: '${(tempScale * 100).round()}%',
                          activeColor: theme.colorScheme.primary,
                        ),
                      ),
                      const Text('Large'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          // Revert to previous scale if user cancels
                          setState(() {
                            _brushScale = tempScale;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRealTimeFeedbackOverlay() {
    final result = _realTimeResult!;

    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: result.isCorrect ? Colors.green.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  result.isCorrect ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Confidence: ${((result.confidence ?? 0.0) * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecognitionResultOverlay() {
    final result = _lastRecognitionResult!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Reserve space so the overlay doesn't get covered by the bottom toolbar
    final double scale = _toolbarScale(context);
    final double minSize = (36.0 * scale).clamp(22.0, 32.0);
    final double vPad = (6.0 * scale).clamp(3.0, 6.0);
    final double reservedBottom = minSize + (vPad * 2) + 36; // toolbar height + extra spacing

    // Display results inline at the top of the drawing board
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: EdgeInsets.fromLTRB(8, 8, 8, reservedBottom),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: result.isCorrect ? Colors.green : Colors.orange,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Overall result row (always visible, compact)
            Row(
              children: [
                Icon(
                  _lastMarkPassing ? Icons.emoji_events : Icons.error_outline,
                  color: _lastMarkPassing ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _lastMarkLabel ?? (result.isCorrect ? 'Goods' : 'Failed'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _lastMarkPassing ? Colors.green : Colors.red,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action buttons: Retake always, Exit only if passing
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _clearDrawing();
                        setState(() {
                          _showRecognitionResult = false;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retake'),
                    ),
                    if (_lastMarkPassing)
                      TextButton.icon(
                        onPressed: () {
                          // Notify parent that recognition completed with passing mark
                          final r = _lastRecognitionResult;
                          if (r != null) {
                            widget.onRecognitionComplete?.call(r);
                          }
                          // Ask parent to exit to selection
                          widget.onExitToSelection?.call();
                        },
                        icon: const Icon(Icons.exit_to_app, size: 16),
                        label: const Text('Exit'),
                      ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 10),
            // Main result row - responsive layout
            Row(
              children: [
                // Left side - Result status and character (flexible)
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      // Result icon
                      Icon(
                        result.isCorrect ? Icons.check_circle : Icons.info,
                        size: 20,
                        color: result.isCorrect ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),

                      // Result text and character
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _lastMarkLabel ?? (result.isCorrect ? 'Goods' : 'Failed'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _lastMarkPassing ? Colors.green : Colors.red,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Target: ${widget.character.character}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Center - Scores (flexible)
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      // Confidence score
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Conf: ${((result.confidence ?? 0.0) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Accuracy score
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Acc: ${(result.accuracyScore ?? 0.0).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right side - Details toggle only
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showDetailedFeedback = !_showDetailedFeedback;
                    });
                  },
                  icon: Icon(_showDetailedFeedback ? Icons.expand_less : Icons.expand_more),
                  tooltip: 'Toggle Details',
                  iconSize: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),

            // Detailed feedback section (expandable)
            if (_showDetailedFeedback) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  // Cap height to avoid overlapping the toolbar
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + reservedBottom * 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Uploaded images section
                      if (_lastHandwrittenImageBase64 != null ||
                          _lastReferenceImageBase64 != null) ...[
                        Text(
                          '📤 Images Being Analyzed:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Handwritten image
                            if (_lastHandwrittenImageBase64 != null) ...[
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Your Drawing',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: Image.memory(
                                          base64Decode(_lastHandwrittenImageBase64!),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_lastHandwrittenImageBase64 != null &&
                                _lastReferenceImageBase64 != null)
                              const SizedBox(width: 8),
                            // Reference image
                            if (_lastReferenceImageBase64 != null) ...[
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Reference',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.blue.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: Image.memory(
                                          base64Decode(_lastReferenceImageBase64!),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Detailed scores breakdown
                      Row(
                        children: [
                          Expanded(
                            child: _buildScoreCard('Shape', result.shapeScore, Colors.purple),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildScoreCard('Stroke', result.strokeScore, Colors.orange),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                _buildScoreCard('Proportion', result.proportionScore, Colors.teal),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildScoreCard('Quality', result.qualityScore, Colors.indigo),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Main feedback
                      Text(
                        result.feedback,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, double? score, Color color) {
    final safeScore = score ?? 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${safeScore.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Checking your character...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrokeDirectionHint() {
    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((0.7 * 255).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.character.strokeDirections![_currentStrokeHint - 1],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  void _toggleSvgGuideline() {
    setState(() {
      _showSvgGuideline = !_showSvgGuideline;
    });
  }

  Widget _buildSvgGuideline() {
    if (widget.character.fullSvgPath == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Center(
        child: RepaintBoundary(
          child: SvgPicture.asset(
            widget.character.fullSvgPath!,
            color: Colors.grey.withOpacity(0.3),
            width: 280,
            height: 280,
            fit: BoxFit.contain,
            placeholderBuilder: (context) => Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  final Color centerColor;

  GridPainter({
    this.color = Colors.grey,
    this.centerColor = Colors.red,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw horizontal lines
    for (int i = 1; i < 10; i++) {
      final y = size.height * (i / 10);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw vertical lines
    for (int i = 1; i < 10; i++) {
      final x = size.width * (i / 10);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw center lines with different color
    final centerPaint = Paint()
      ..color = centerColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Horizontal center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );

    // Vertical center line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.centerColor != centerColor;
  }
}

class StrokeOrderPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final int currentStroke;
  final bool showAllStrokes;
  final Color color;

  StrokeOrderPainter({
    required this.strokes,
    required this.currentStroke,
    required this.showAllStrokes,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      final path = Path();
      if (stroke.isEmpty) continue;

      path.moveTo(
        stroke.first.dx * size.width,
        stroke.first.dy * size.height,
      );

      for (int j = 1; j < stroke.length; j++) {
        path.lineTo(
          stroke[j].dx * size.width,
          stroke[j].dy * size.height,
        );
      }

      if (i == currentStroke && showAllStrokes) {
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(StrokeOrderPainter oldDelegate) {
    return oldDelegate.currentStroke != currentStroke ||
        oldDelegate.showAllStrokes != showAllStrokes ||
        oldDelegate.color != color;
  }
}

class BrushDrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final double minStrokeWidth;
  final double maxStrokeWidth;

  BrushDrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColor,
    required this.minStrokeWidth,
    required this.maxStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      _drawBrushStroke(canvas, size, stroke);
    }

    // Draw current stroke with real-time feedback
    if (currentStroke.isNotEmpty) {
      _drawBrushStroke(canvas, size, currentStroke);
    }
  }

  void _drawBrushStroke(Canvas canvas, Size size, List<Offset> stroke) {
    if (stroke.length < 2) return;

    for (int i = 1; i < stroke.length; i++) {
      final p0 = stroke[i - 1];
      final p1 = stroke[i];

      // Calculate stroke width based on speed (simulating brush pressure)
      double speed = 1.0;
      if (i > 1) {
        final prevPoint = stroke[i - 2];
        final distance = (p0 - prevPoint).distance;
        speed = math.min(math.max(distance * 15, 0.3), 3.0); // More responsive
      }

      // Calculate brush width - thicker when slower, thinner when faster
      final brushWidth = maxStrokeWidth - ((maxStrokeWidth - minStrokeWidth) * (speed - 0.3) / 2.7);

      // Create a path for this segment
      final path = Path();

      // Use quadratic bezier for smoother lines if we have enough points
      if (i > 1 && i < stroke.length - 1) {
        // Calculate control points for smoother curve
        final controlPoint1 = Offset(
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );

        path.moveTo(
          p0.dx * size.width,
          p0.dy * size.height,
        );

        path.quadraticBezierTo(
          controlPoint1.dx * size.width,
          controlPoint1.dy * size.height,
          p1.dx * size.width,
          p1.dy * size.height,
        );
      } else {
        // Simple line for start/end segments
        path.moveTo(
          p0.dx * size.width,
          p0.dy * size.height,
        );

        path.lineTo(
          p1.dx * size.width,
          p1.dy * size.height,
        );
      }

      // Create brush-like paint with enhanced visual feedback
      final paint = Paint()
        ..color = strokeColor
        ..strokeWidth = brushWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high; // Better quality rendering

      // Draw the path
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(BrushDrawingPainter oldDelegate) {
    // Repaint when any relevant input changes
    return !identical(oldDelegate.strokes, strokes) ||
        !listEquals(oldDelegate.currentStroke, currentStroke) ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.minStrokeWidth != minStrokeWidth ||
        oldDelegate.maxStrokeWidth != maxStrokeWidth;
  }
}
