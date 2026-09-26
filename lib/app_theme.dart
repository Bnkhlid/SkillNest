import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─── noted — Design Tokens ──────────────────────────────────────────────────
/// Neo-brutalist soft pastel note-taking system.
/// Crisp 2px ink borders · solid offset drop shadows · pastel cards (Yellow, Pink, Mint) · Vanilla canvas.

class Insets {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}

class Radii {
  static const double card = 18;
  static const double note = 20;
  static const double control = 14;
  static const double sheet = 26;
  static const double dialog = 24;
  static const double thumb = 12;
  static const double checkbox = 8;
}

class Touch {
  static const Size min = Size(44, 44);
}

/// Palette taken directly from Figma "noted" design system.
class NotedColors {
  // Notes palette
  static const Color yellow = Color(0xFFF9D788);
  static const Color yellowLight = Color(0xFFFDF6E2);
  static const Color yellowHeader = Color(0xFFFEE4A0);

  static const Color pink = Color(0xFFF7A399);
  static const Color pinkLight = Color(0xFFFDE8E5);
  static const Color pinkCard = Color(0xFFF8AAA1);

  static const Color mint = Color(0xFF8FE3D6);
  static const Color mintLight = Color(0xFFE0F7F4);
  static const Color mintCard = Color(0xFFA1ECE1);

  static const Color purpleLight = Color(0xFFEDE7F6);
  static const Color blueLight = Color(0xFFE1F0FA);

  // Canvas / Surface
  static const Color canvasLight = Color(0xFFFCF8EC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFDFBF7);

  // Ink / Borders
  static const Color ink = Color(0xFF242424);
  static const Color inkMuted = Color(0xFF6B6B6B);
  static const Color inkSubtle = Color(0xFF8E8E93);
  static const Color border = Color(0xFF242424);
  static const Color shadow = Color(0xFF242424);

  // Dark mode variants
  static const Color canvasDark = Color(0xFF141414);
  static const Color surfaceDark = Color(0xFF1F1F1F);
  static const Color cardDark = Color(0xFF282828);
  static const Color borderDark = Color(0xFF383838);

  static Color collectionAccent(int index) {
    return switch (index % 6) {
      0 => const Color(0xFFFFC107), // Amber/Yellow
      1 => const Color(0xFF2EB872), // Emerald/Mint
      2 => const Color(0xFFF06292), // Rose/Pink
      3 => const Color(0xFFAB47BC), // Violet/Purple
      4 => const Color(0xFF42A5F5), // Sky/Blue
      _ => const Color(0xFFFF9800), // Orange/Peach
    };
  }

  static Color pastelCard(int index, {required bool isDark}) {
    if (!isDark) {
      return switch (index % 6) {
        0 => yellowLight,
        1 => mintLight,
        2 => pinkLight,
        3 => purpleLight,
        4 => blueLight,
        _ => const Color(0xFFFDEED8),
      };
    } else {
      return switch (index % 6) {
        0 => const Color(0xFF332A18), // Warm Amber
        1 => const Color(0xFF16352A), // Fresh Mint
        2 => const Color(0xFF3A1C28), // Deep Rose
        3 => const Color(0xFF281C3D), // Rich Violet
        4 => const Color(0xFF162C44), // Midnight Blue
        _ => const Color(0xFF382417), // Rich Peach
      };
    }
  }
}

/// Neo-brutalist helper styles for decorative containers with crisp ink borders & flat offset shadows.
class NotedBox {
  static BoxDecoration card({
    Color color = Colors.white,
    Color borderColor = NotedColors.border,
    double radius = Radii.card,
    bool shadow = true,
    double borderWidth = 2.0,
    Offset shadowOffset = const Offset(3.5, 4.5),
    Color shadowColor = NotedColors.shadow,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: shadowColor,
                offset: shadowOffset,
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  static BoxDecoration pill({
    Color color = NotedColors.yellow,
    Color borderColor = NotedColors.border,
    bool shadow = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: borderColor, width: 2.0),
      boxShadow: shadow
          ? const [
              BoxShadow(
                color: NotedColors.shadow,
                offset: Offset(2, 3),
                blurRadius: 0,
              ),
            ]
          : null,
    );
  }
}

ColorScheme _lightScheme() => const ColorScheme(
      brightness: Brightness.light,
      primary: NotedColors.ink,
      onPrimary: Colors.white,
      primaryContainer: NotedColors.yellow,
      onPrimaryContainer: NotedColors.ink,
      secondary: NotedColors.mint,
      onSecondary: NotedColors.ink,
      secondaryContainer: NotedColors.mintLight,
      onSecondaryContainer: NotedColors.ink,
      tertiary: NotedColors.pink,
      onTertiary: NotedColors.ink,
      tertiaryContainer: NotedColors.pinkLight,
      onTertiaryContainer: NotedColors.ink,
      error: Color(0xFFD94838),
      onError: Colors.white,
      errorContainer: Color(0xFFFDE8E5),
      onErrorContainer: NotedColors.ink,
      surface: NotedColors.canvasLight,
      onSurface: NotedColors.ink,
      onSurfaceVariant: NotedColors.inkMuted,
      surfaceContainerHighest: Color(0xFFE9E4D6),
      surfaceContainerHigh: Color(0xFFF0EBDC),
      surfaceContainer: Color(0xFFF7F2E4),
      surfaceContainerLow: NotedColors.yellowLight,
      surfaceContainerLowest: Colors.white,
      onInverseSurface: NotedColors.canvasLight,
      inverseSurface: NotedColors.ink,
      inversePrimary: NotedColors.yellow,
      outline: NotedColors.border,
      outlineVariant: Color(0xFFDDD7C8),
      shadow: NotedColors.shadow,
      scrim: Color(0x66000000),
    );

ColorScheme _darkScheme() => const ColorScheme(
      brightness: Brightness.dark,
      primary: NotedColors.yellow,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF352C16),
      onPrimaryContainer: Colors.white,
      secondary: NotedColors.mint,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF1B3834),
      onSecondaryContainer: Colors.white,
      tertiary: NotedColors.pink,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF3D2321),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFFF7A6B),
      onError: Colors.white,
      errorContainer: Color(0xFF6E1810),
      onErrorContainer: Colors.white,
      surface: NotedColors.canvasDark,
      onSurface: Color(0xFFF5F2EB),
      onSurfaceVariant: Color(0xFFB5B0A4),
      surfaceContainerHighest: Color(0xFF383838),
      surfaceContainerHigh: Color(0xFF2E2E2E),
      surfaceContainer: Color(0xFF242424),
      surfaceContainerLow: Color(0xFF1B1B1B),
      surfaceContainerLowest: Color(0xFF121212),
      onInverseSurface: NotedColors.canvasDark,
      inverseSurface: Color(0xFFF5F2EB),
      inversePrimary: Colors.white,
      outline: Color(0xFF555555),
      outlineVariant: Color(0xFF3A3A3A),
      shadow: Colors.black,
      scrim: Color(0x99000000),
    );

ThemeData buildTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? _lightScheme() : _darkScheme();
  final isLight = brightness == Brightness.light;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,

    fontFamily: 'Roboto',

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: isLight ? NotedColors.ink : scheme.onSurface,
      iconTheme: IconThemeData(color: isLight ? NotedColors.ink : scheme.onSurface),
      actionsIconTheme: IconThemeData(color: isLight ? NotedColors.ink : scheme.onSurface),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: isLight ? NotedColors.ink : scheme.onSurface,
      ),
      toolbarHeight: 64,
      systemOverlayStyle: isLight
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? NotedColors.yellow : const Color(0xFF352C16);
          }
          return isLight ? Colors.white : scheme.surfaceContainer;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? NotedColors.ink : Colors.white;
          }
          return isLight ? NotedColors.ink : scheme.onSurface;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? NotedColors.ink : Colors.white;
          }
          return isLight ? NotedColors.ink : scheme.onSurface;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return (isLight ? NotedColors.ink : Colors.white).withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        splashFactory: InkRipple.splashFactory,
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(
              color: isLight ? NotedColors.border : const Color(0xFFFFC107),
              width: 2,
            );
          }
          return BorderSide(
            color: isLight ? NotedColors.border : scheme.outlineVariant,
            width: 2,
          );
        }),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isLight ? NotedColors.ink : const Color(0xFF352C16),
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          side: BorderSide(
            color: isLight ? NotedColors.border : const Color(0xFFFFC107),
            width: 2,
          ),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isLight ? NotedColors.yellow : const Color(0xFF352C16),
        foregroundColor: isLight ? NotedColors.ink : Colors.white,
        minimumSize: const Size(64, 48),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          side: BorderSide(
            color: isLight ? NotedColors.border : const Color(0xFFFFC107),
            width: 2,
          ),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        foregroundColor: isLight ? NotedColors.ink : Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          side: BorderSide(
            color: isLight ? NotedColors.border : scheme.outlineVariant,
            width: 2,
          ),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isLight ? NotedColors.ink : scheme.onSurface,
        minimumSize: Touch.min,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: isLight ? NotedColors.ink : scheme.onSurface,
        minimumSize: Touch.min,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isLight ? NotedColors.yellow : const Color(0xFF352C16),
      foregroundColor: isLight ? NotedColors.ink : Colors.white,
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isLight ? NotedColors.border : const Color(0xFFFFC107),
          width: 2.2,
        ),
      ),
    ),

    chipTheme: ChipThemeData(
      side: BorderSide(
        color: isLight ? NotedColors.border : scheme.outlineVariant,
        width: 1.8,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
      selectedColor: isLight ? NotedColors.yellow : const Color(0xFF352C16),
      secondarySelectedColor: isLight ? NotedColors.yellow : const Color(0xFF352C16),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isLight ? NotedColors.ink : Colors.white,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: isLight ? NotedColors.ink : Colors.white,
      ),
      iconTheme: IconThemeData(
        color: isLight ? NotedColors.ink : Colors.white,
        size: 17,
      ),
      checkmarkColor: isLight ? NotedColors.ink : Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? Colors.white : scheme.surfaceContainerLow,
      prefixIconColor: isLight ? NotedColors.ink : Colors.white,
      suffixIconColor: isLight ? NotedColors.ink : Colors.white,
      hintStyle: TextStyle(color: isLight ? NotedColors.inkMuted : scheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 14.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(
          color: isLight ? NotedColors.border : scheme.outlineVariant,
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(
          color: isLight ? NotedColors.border : scheme.outlineVariant,
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(
          color: isLight ? NotedColors.border : const Color(0xFFFFC107),
          width: 2.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),

    cardTheme: CardThemeData(
      color: isLight ? Colors.white : scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: NotedColors.border, width: 2),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: isLight ? NotedColors.canvasLight : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.dialog),
        side: const BorderSide(color: NotedColors.border, width: 2),
      ),
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      contentTextStyle: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurfaceVariant),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isLight ? NotedColors.canvasLight : scheme.surfaceContainerLow,
      showDragHandle: true,
      dragHandleColor: NotedColors.inkMuted,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        side: BorderSide(color: NotedColors.border, width: 2),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NotedColors.ink,
      contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      actionTextColor: NotedColors.yellow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        side: const BorderSide(color: Colors.white24, width: 1),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return NotedColors.ink;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return NotedColors.mint;
        return isLight ? const Color(0xFFE5DFD1) : scheme.surfaceContainerHighest;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(NotedColors.border),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: NotedColors.border, width: 2),
      checkColor: const WidgetStatePropertyAll(NotedColors.ink),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return NotedColors.mint;
        return Colors.white;
      }),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: NotedColors.mint,
      linearTrackColor: isLight ? const Color(0xFFEFE8D8) : scheme.surfaceContainerHighest,
      circularTrackColor: isLight ? const Color(0xFFEFE8D8) : scheme.surfaceContainerHighest,
      linearMinHeight: 7,
    ),

    dividerTheme: const DividerThemeData(
      color: NotedColors.border,
      thickness: 1.5,
      space: 1,
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      iconColor: scheme.onSurfaceVariant,
    ),
  );
}
