import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:nihongo_japanese_app/models/japanese_character.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class CharacterStrokeAnimation extends StatefulWidget {
  final JapaneseCharacter character;

  const CharacterStrokeAnimation({
    super.key,
    required this.character,
  });

  @override
  State<CharacterStrokeAnimation> createState() => _CharacterStrokeAnimationState();
}

class _CharacterStrokeAnimationState extends State<CharacterStrokeAnimation> {
  // Initialize controller once
  final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000)); // Transparent background initially
    
  String? _svgDataUrl;
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    // Don't initialize controller here, just load initial data
    _loadSvgForWebView(); 
  }

  @override
  void didUpdateWidget(CharacterStrokeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.character != widget.character.character) {
      // Just load the new SVG data for the existing controller
      _loadSvgForWebView();
    }
  }

  // Renamed function to clarify its purpose
  Future<void> _loadSvgForWebView() async {
    setState(() {
      _isLoading = true; // Start loading
      _svgDataUrl = null; // Clear previous URL
    });
    
    developer.log('Loading SVG for WebView: ${widget.character.fullSvgPath}');
    if (widget.character.fullSvgPath == null) {
      developer.log('No SVG path for character: ${widget.character.character}');
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final String svgContent = await rootBundle.loadString(widget.character.fullSvgPath!);
      developer.log('Successfully loaded SVG content for ${widget.character.character}, length: ${svgContent.length}');

      final String base64Svg = base64Encode(utf8.encode(svgContent));
      final dataUrl = 'data:image/svg+xml;base64,$base64Svg';
      
      // Load the new data URL into the *existing* controller
      await _controller.loadRequest(Uri.parse(dataUrl));
      developer.log('WebView controller loaded new data URL.');

      // Update state *after* loading request is initiated
      setState(() {
        _svgDataUrl = dataUrl; 
        _isLoading = false; // Finish loading
      });

    } catch (e) {
      developer.log('Error loading SVG asset for WebView: $e', error: e);
      setState(() {
        _isLoading = false; // Finish loading even on error
        _svgDataUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building CharacterStrokeAnimation. IsLoading: $_isLoading, SVG URL available: ${_svgDataUrl != null}');
    
    // Show loading indicator while loading or if URL is still null
    if (_isLoading || _svgDataUrl == null) {
      developer.log('Showing loading indicator.');
      return const Center(
        child: CircularProgressIndicator(), // Use a progress indicator
      );
    }

    developer.log('Rendering WebViewWidget for character: ${widget.character.character}');
    // Wrap WebView in a Stack to add an overlay button
    return Stack(
      // Ensure the Stack allows hit testing on its children
      fit: StackFit.expand, 
      children: [
        WebViewWidget(controller: _controller),
        
        // Reload button in the top-right corner
        Positioned(
          top: 8,
          right: 8,
          child: Container(
             decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              color: Theme.of(context).colorScheme.primary,
              tooltip: 'Replay Animation',
              onPressed: () {
                developer.log('Reloading WebView to restart animation');
                _controller.reload();
              },
            ),
          ),
        ),
      ],
    );
  }
}

