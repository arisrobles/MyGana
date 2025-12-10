import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ModuleViewerScreen extends StatefulWidget {
  final String title;
  final String base64Data; // Base64 encoded PDF data
  final Color? appBarColor;

  const ModuleViewerScreen({
    super.key,
    required this.title,
    required this.base64Data,
    this.appBarColor,
  });

  @override
  State<ModuleViewerScreen> createState() => _ModuleViewerScreenState();
}

class _ModuleViewerScreenState extends State<ModuleViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Create data URI for base64 PDF
    final dataUri = 'data:application/pdf;base64,${widget.base64Data}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            // If data URI doesn't work, try alternative approach
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.dataFromString(
        '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { margin: 0; padding: 0; overflow: hidden; }
            iframe { width: 100%; height: 100vh; border: none; }
          </style>
        </head>
        <body>
          <iframe src="$dataUri"></iframe>
        </body>
        </html>
        ''',
        mimeType: 'text/html',
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.appBarColor,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
