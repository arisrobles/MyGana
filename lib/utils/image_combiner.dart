import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Utility class to combine handwritten and reference images into one
class ImageCombiner {
  /// Combine handwritten and reference images into a single comparison image
  static Future<String> createComparisonImage({
    required String handwrittenImageBase64,
    required String referenceImageBase64,
    Size imageSize = const Size(1024, 512), // Wide format for side-by-side
  }) async {
    try {
      // Decode base64 images
      final handwrittenBytes = base64Decode(handwrittenImageBase64);
      final referenceBytes = base64Decode(referenceImageBase64);

      // Create a simple canvas-based approach
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Fill white background
      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, imageSize.width, imageSize.height), backgroundPaint);

      // Load images
      final handwrittenImage = await _loadImageFromBytes(handwrittenBytes);
      final referenceImage = await _loadImageFromBytes(referenceBytes);

      if (handwrittenImage != null && referenceImage != null) {
        // Calculate positions for side-by-side layout
        final imageWidth = (imageSize.width - 60) / 2; // Leave space for margins and labels
        final imageHeight = imageSize.height - 80; // Leave space for labels

        // Draw handwritten image (left side)
        final leftRect = Rect.fromLTWH(20, 50, imageWidth, imageHeight);
        canvas.drawImageRect(
          handwrittenImage,
          Rect.fromLTWH(
              0, 0, handwrittenImage.width.toDouble(), handwrittenImage.height.toDouble()),
          leftRect,
          Paint(),
        );

        // Draw reference image (right side)
        final rightRect = Rect.fromLTWH(imageSize.width / 2 + 10, 50, imageWidth, imageHeight);
        canvas.drawImageRect(
          referenceImage,
          Rect.fromLTWH(0, 0, referenceImage.width.toDouble(), referenceImage.height.toDouble()),
          rightRect,
          Paint(),
        );

        // Add labels
        final textPainter = TextPainter(textDirection: TextDirection.ltr);

        // "Your Drawing" label
        textPainter.text = const TextSpan(
          text: 'Your Drawing',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(leftRect.left, 20));

        // "Reference" label
        textPainter.text = const TextSpan(
          text: 'Reference',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(rightRect.left, 20));

        // Add borders
        final borderPaint = Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawRect(leftRect, borderPaint);

        borderPaint.color = Colors.blue;
        canvas.drawRect(rightRect, borderPaint);
      }

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        imageSize.width.toInt(),
        imageSize.height.toInt(),
      );

      // Convert to bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Convert to base64
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('❌ Error creating comparison image: $e');
      // Fallback: return just the handwritten image
      return handwrittenImageBase64;
    }
  }

  /// Load image from bytes
  static Future<ui.Image?> _loadImageFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('❌ Error loading image from bytes: $e');
      return null;
    }
  }
}
