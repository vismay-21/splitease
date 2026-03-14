import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.text,
    this.totalAmount,
    this.imagePath,
  });

  final String text;
  final double? totalAmount;
  final String? imagePath;
}

class ImageRecognition {
  ImageRecognition._();

  static final ImagePicker _picker = ImagePicker();

  static Future<String> _extractTextWithFallbacks(String imagePath) async {
    final attempts = <Future<String> Function()>[
      () => FlutterTesseractOcr.extractText(
            imagePath,
            language: 'eng',
            args: {
              'psm': '6',
              'preserve_interword_spaces': '1',
            },
          ),
      () => FlutterTesseractOcr.extractText(
            imagePath,
            language: 'eng',
          ),
      () => FlutterTesseractOcr.extractText(imagePath),
    ];

    Object? lastError;
    for (final attempt in attempts) {
      try {
        final text = await attempt();
        if (text.trim().isNotEmpty) {
          return text;
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    return '';
  }

  /// Opens the camera or gallery, runs Tesseract OCR, and returns the result.
  ///
  /// Returns `(result, null)` on success.
  /// Returns `(null, null)` if the user cancelled.
  /// Returns `(null, errorMessage)` on failure — show this to the user.
  static Future<(ReceiptScanResult?, String?)> scanReceipt({
    ImageSource source = ImageSource.camera,
  }) async {
    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      debugPrint('Image picker error: $e');
      return (null, 'Could not open camera/gallery: $e');
    }

    if (image == null) {
      // User cancelled — not an error
      return (null, null);
    }

    final imagePath = image.path;
    if (!File(imagePath).existsSync()) {
      return (null, 'Image file not found. Please try again.');
    }

    try {
      final String extractedText = await _extractTextWithFallbacks(imagePath);

      debugPrint('===== OCR TEXT START =====');
      debugPrint(extractedText);
      debugPrint('===== OCR TEXT END =====');

      if (extractedText.trim().isEmpty) {
        return (
          null,
          'OCR returned no text. Try a clearer image with better lighting and larger text. Also verify assets/tessdata/eng.traineddata is bundled.',
        );
      }

      final double? total = _extractTotalAmount(extractedText);
      debugPrint('Parsed total: ${total?.toStringAsFixed(2) ?? 'not found'}');

      return (
        ReceiptScanResult(
          text: extractedText,
          totalAmount: total,
          imagePath: imagePath,
        ),
        null,
      );
    } catch (error, stackTrace) {
      debugPrint('Tesseract OCR failed: $error');
      debugPrint('$stackTrace');
      return (null, 'OCR error: $error');
    }
  }

  /// Tries to find the final payable amount from OCR text.
  static double? _extractTotalAmount(String text) {
    final normalized = text.replaceAll(',', '.');
    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final amountRegex = RegExp(r'([0-9]+(?:\.[0-9]{1,2})?)');

    for (final line in lines.reversed) {
      final lower = line.toLowerCase();
      if (lower.contains('total') ||
          lower.contains('grand total') ||
          lower.contains('amount due') ||
          lower.contains('net amount')) {
        final matches = amountRegex.allMatches(line);
        if (matches.isNotEmpty) {
          final raw = matches.last.group(1);
          final value = raw == null ? null : double.tryParse(raw);
          if (value != null) {
            return value;
          }
        }
      }
    }

    for (final line in lines.reversed) {
      final matches = amountRegex.allMatches(line);
      if (matches.isNotEmpty) {
        final raw = matches.last.group(1);
        final value = raw == null ? null : double.tryParse(raw);
        if (value != null) {
          return value;
        }
      }
    }

    return null;
  }
}
