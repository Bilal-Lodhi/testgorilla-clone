import 'package:flutter/material.dart';

import 'light_theme.dart';
import 'dark_theme.dart';

/// Central theme constants and factory.
/// Shared semantic color tokens used by both light and dark themes.
class AppTheme {
  // ── Brand / Accent ────────────────────────────────────────────
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color secondaryColor = Color(0xFF2563EB);
  static const Color accentColor = Color(0xFF0EA5E9);

  // ── Semantic status ───────────────────────────────────────────
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFEA580C);
  static const Color errorColor = Color(0xFFDC2626);

  // ── Light-only tokens ─────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color backgroundLight = Color(0xFFF3F6FB);
  static const Color onSurfaceLight = Color(0xFF0B1220);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color outlineBorderLight = Color(0xFFD1D9E8);

  // ── Dark-only tokens ──────────────────────────────────────────
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceMutedDark = Color(0xFF1A2332);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color onSurfaceDark = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFF334155);
  static const Color outlineBorderDark = Color(0xFF475569);

  // ── Shared spacing ────────────────────────────────────────────
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  // ── Helpers ───────────────────────────────────────────────────
  static Color subtext(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

  /// Context-aware surfaceMuted that switches between light/dark.
  static Color surfaceMutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? surfaceMutedDark
      : surfaceMuted;

  // ── Theme factories (kept for backward compatibility) ────────
  static ThemeData get lightTheme => LightTheme.theme;
  static ThemeData get darkTheme => DarkTheme.theme;
}
