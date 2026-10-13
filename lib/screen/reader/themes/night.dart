import 'package:flutter/material.dart';

/// 夜间阅读配色：深底、偏灰的正文，避免纯白字刺眼。
final nightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9BB0C7),
        primaryContainer: Color(0xFF3A4654),
        secondary: Color(0xFF8B939C),
        background: Color(0xFF121212),
        onBackground: Color(0xFFC8C8C8),
        surface: Color(0xFF1C1C1E),
        outline: Color(0xFF3A3A3C)));
