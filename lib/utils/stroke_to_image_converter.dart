import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class StrokeToImageConverter {
  /// Convert user strokes to a high-quality base64 encoded PNG image
  static Future<String> createHighQualityImage({
    required List<List<Offset>> normalizedStrokes,
    Size imageSize = const Size(512, 512),
    Color backgroundColor = Colors.white,
    Color strokeColor = Colors.black,
    double strokeWidth = 12.0,
  }) async {
    try {
      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Fill background
      final backgroundPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, imageSize.width, imageSize.height), backgroundPaint);

      // Draw strokes with enhanced quality
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high; // Enhanced quality

      for (final stroke in normalizedStrokes) {
        if (stroke.length < 2) continue;

        final path = Path();
        path.moveTo(stroke[0].dx * imageSize.width, stroke[0].dy * imageSize.height);

        // Use quadratic bezier curves for smoother lines
        for (int i = 1; i < stroke.length; i++) {
          if (i == stroke.length - 1) {
            // Last point - simple line
            path.lineTo(stroke[i].dx * imageSize.width, stroke[i].dy * imageSize.height);
          } else {
            // Use control points for smooth curves
            final current = stroke[i];
            final next = stroke[i + 1];
            final controlPoint = Offset(
              (current.dx + next.dx) / 2 * imageSize.width,
              (current.dy + next.dy) / 2 * imageSize.height,
            );
            path.quadraticBezierTo(
              controlPoint.dx,
              controlPoint.dy,
              next.dx * imageSize.width,
              next.dy * imageSize.height,
            );
            i++; // Skip next point as we used it for control
          }
        }

        canvas.drawPath(path, strokePaint);
      }

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        imageSize.width.toInt(),
        imageSize.height.toInt(),
      );

      // Convert to byte data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to byte data');
      }

      // Convert to base64
      final base64String = base64Encode(byteData.buffer.asUint8List());

      // Clean up
      picture.dispose();
      image.dispose();

      return base64String;
    } catch (e) {
      throw Exception('Failed to convert strokes to image: $e');
    }
  }

  /// Convert strokes from normalized coordinates to actual pixel coordinates
  static List<List<Offset>> normalizeStrokesToPixels({
    required List<List<Offset>> normalizedStrokes,
    required Size canvasSize,
  }) {
    return normalizedStrokes.map((stroke) {
      return stroke.map((point) {
        return Offset(
          point.dx * canvasSize.width,
          point.dy * canvasSize.height,
        );
      }).toList();
    }).toList();
  }
}
