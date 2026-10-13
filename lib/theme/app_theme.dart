import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'colors.dart';

/// Accent usage (from the Pencil mockups, zmey-client.pen):
/// - `primary` = filled accents (buttons, own bubbles, send) = maroon in both modes.
/// - `secondary` = text accents (links, active nav, sender names, cursor,
///   spinners) = maroon in light, gold in dark. Maroon is too dark to read
///   on the dark background, which is why the two roles are split.
/// - `tertiary` = gold highlights (unread badges) in both modes.
class AppTheme {
  /// Bundled by the user later (assets/fonts). Until then Flutter falls back
  /// to the platform font.
  static const _font = 'Inter';

  static final ThemeData light = _build(
    brightness: Brightness.light,
    bg: ZmeyColors.lightBg,
    surface: ZmeyColors.lightSurface,
    text: ZmeyColors.lightTextPrimary,
    textSecondary: ZmeyColors.lightTextSecondary,
    accentFill: ZmeyColors.lightAccentMaroon,
    onAccentFill: ZmeyColors.lightBg,
    accentText: ZmeyColors.lightAccentMaroon,
    onAccentText: ZmeyColors.lightBg,
    gold: ZmeyColors.lightAccentGold,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    bg: ZmeyColors.darkBg,
    surface: ZmeyColors.darkSurface,
    text: ZmeyColors.darkTextPrimary,
    textSecondary: ZmeyColors.darkTextSecondary,
    accentFill: ZmeyColors.darkAccentMaroon,
    onAccentFill: ZmeyColors.darkTextPrimary,
    accentText: ZmeyColors.darkAccentGold,
    onAccentText: ZmeyColors.darkBg,
    gold: ZmeyColors.darkAccentGold,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color text,
    required Color textSecondary,
    required Color accentFill,
    required Color onAccentFill,
    required Color accentText,
    required Color onAccentText,
    required Color gold,
  }) {
    // Every role is set explicitly: unset ones fall back to Material's
    // baseline purple, which isn't part of the palette.
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accentFill,
      onPrimary: onAccentFill,
      primaryContainer: surface,
      onPrimaryContainer: text,
      secondary: accentText,
      onSecondary: onAccentText,
      secondaryContainer: surface,
      onSecondaryContainer: text,
      tertiary: gold,
      onTertiary: ZmeyColors.lightTextPrimary,
      tertiaryContainer: surface,
      onTertiaryContainer: text,
      // No error color in the palette yet, Material's default red for now.
      error: brightness == Brightness.light
          ? const Color(0xFFB3261E)
          : const Color(0xFFF2B8B5),
      onError: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF601410),
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      surfaceTint: Colors.transparent,
      outline: textSecondary,
      outlineVariant: surface,
      inverseSurface: text,
      onInverseSurface: bg,
      inversePrimary: accentText,
      shadow: ZmeyColors.lightTextPrimary,
      scrim: ZmeyColors.lightTextPrimary,
    );

    final rounded10 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final filledButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: accentFill,
      foregroundColor: onAccentFill,
      disabledBackgroundColor: accentFill.withValues(alpha: 0.5),
      disabledForegroundColor: onAccentFill.withValues(alpha: 0.7),
      elevation: 0,
      minimumSize: const Size(64, 48),
      shape: rounded10,
      textStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: _font,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: surface,
      iconTheme: IconThemeData(color: text),
      // AppBar's automatic back button uses the app's SVG arrow, tinted with
      // the surrounding icon color (the app bar's foreground).
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => SvgPicture.asset(
          'assets/icons/arrow-back.svg',
          colorFilter: ColorFilter.mode(
            IconTheme.of(context).color ?? text,
            BlendMode.srcIn,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: noBorder,
        enabledBorder: noBorder,
        disabledBorder: noBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentText, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
          shape: rounded10,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: text, textColor: text),
      dividerTheme: DividerThemeData(color: surface, thickness: 1, space: 1),
      // Spinners and the cursor use the text accent: maroon is near-invisible
      // on the dark background.
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accentText),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentText,
        selectionColor: accentText.withValues(alpha: 0.25),
        selectionHandleColor: accentText,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: TextStyle(fontFamily: _font, color: bg),
        shape: rounded10,
      ),
    );
  }
}
