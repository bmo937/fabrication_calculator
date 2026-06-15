import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color _tealDeep = Color(0xFF0A6E67);
  static const Color _charcoal = Color(0xFF20272B);
  static const Color _charcoalSoft = Color(0xFF2A3338);
  static const Color _mist = Color(0xFFF1F6F6);

  static ThemeData light() {
    final ColorScheme scheme = const ColorScheme.light(
      primary: _tealDeep,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFB8EFEA),
      onPrimaryContainer: Color(0xFF032E2B),
      secondary: Color(0xFF4C6360),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFCFE8E4),
      onSecondaryContainer: Color(0xFF091F1D),
      tertiary: Color(0xFF4E5F75),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD5E4FF),
      onTertiaryContainer: Color(0xFF071C34),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFF7FBFB),
      onSurface: _charcoal,
      surfaceContainerHighest: Color(0xFFE2ECEC),
      onSurfaceVariant: Color(0xFF404B50),
      outline: Color(0xFF6F7E86),
      shadow: Color(0x33000000),
      scrim: Color(0x66000000),
      inverseSurface: _charcoal,
      onInverseSurface: Color(0xFFEAF1F1),
      inversePrimary: Color(0xFF72D0C8),
    );

    return _buildTheme(scheme);
  }

  static ThemeData dark() {
    final ColorScheme scheme = const ColorScheme.dark(
      primary: Color(0xFF72D0C8),
      onPrimary: Color(0xFF003733),
      primaryContainer: Color(0xFF00504A),
      onPrimaryContainer: Color(0xFF8DF1E8),
      secondary: Color(0xFFB3CCC8),
      onSecondary: Color(0xFF1E3533),
      secondaryContainer: Color(0xFF344B48),
      onSecondaryContainer: Color(0xFFCFE8E4),
      tertiary: Color(0xFFB6C8E2),
      onTertiary: Color(0xFF1F3148),
      tertiaryContainer: Color(0xFF354960),
      onTertiaryContainer: Color(0xFFD5E4FF),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _charcoal,
      onSurface: Color(0xFFDEE5E6),
      surfaceContainerHighest: _charcoalSoft,
      onSurfaceVariant: Color(0xFFBFC9CE),
      outline: Color(0xFF88979F),
      shadow: Color(0x7F000000),
      scrim: Color(0x99000000),
      inverseSurface: _mist,
      onInverseSurface: Color(0xFF1D2123),
      inversePrimary: _tealDeep,
    );

    return _buildTheme(scheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final TextTheme baseText = GoogleFonts.manropeTextTheme();
    final TextTheme textTheme = baseText.copyWith(
      headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
      bodySmall: baseText.bodySmall?.copyWith(height: 1.3),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: colorScheme.surface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          side: WidgetStateProperty.all(BorderSide(color: colorScheme.outline.withValues(alpha: 0.35))),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outline.withValues(alpha: 0.25), space: 18),
    );
  }
}
