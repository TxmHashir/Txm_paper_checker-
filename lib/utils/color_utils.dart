import 'package:flutter/material.dart';

extension ColorUtils on Color {
  /// Minimal helper to match existing `withValues(alpha: ...)` usage in the repo.
  /// If `alpha` is provided it is treated as opacity (0.0 - 1.0).
  Color withValues({double? alpha, int? red, int? green, int? blue}) {
    final double a = (alpha ?? 1.0).clamp(0.0, 1.0);
    if (red != null || green != null || blue != null) {
      final int r = red ?? this.red;
      final int g = green ?? this.green;
      final int b = blue ?? this.blue;
      return Color.fromARGB((a * 255).round(), r, g, b);
    }
    return withOpacity(a);
  }
}
