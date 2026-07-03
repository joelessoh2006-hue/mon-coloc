import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Affiche une image à partir d’une URL réseau, d’un data URI ou d’un contenu Base64.
/// En cas d’échec, affiche un placeholder sans faire planter le widget.
class SecureImage extends StatelessWidget {
  final String? imageSource;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? fallbackBackgroundColor;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;

  const SecureImage({
    super.key,
    required this.imageSource,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackBackgroundColor,
    this.fallbackIcon = Icons.home_rounded,
    this.fallbackIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final source = imageSource?.trim();
    if (source == null || source.isEmpty) {
      return _buildFallback();
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    try {
      final bytes = _decodeBytes(source);
      if (bytes != null) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => _buildFallback(),
          ),
        );
      }
    } catch (_) {
      // Fallback ci-dessous.
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    final backgroundColor = fallbackBackgroundColor ?? Colors.grey.shade200;
    final iconColor = fallbackIconColor ?? Colors.grey.shade600;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        width: width,
        height: height,
        color: backgroundColor,
        child: Center(
          child: Icon(
            fallbackIcon,
            size: width != null && width! > 80 ? 42 : 28,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Uint8List? _decodeBytes(String input) {
    final normalized = _normalizeBase64(input);
    if (normalized.isEmpty) {
      return null;
    }

    return base64Decode(normalized);
  }

  String _normalizeBase64(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('data:image')) {
      final separatorIndex = trimmed.indexOf(',');
      if (separatorIndex != -1) {
        return trimmed.substring(separatorIndex + 1).trim();
      }
    }
    return trimmed;
  }
}
