import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Pinpoint Theme - Complete Material 3 theme with custom extensions
class PinpointTheme {
  // Private constructor to prevent instantiation
  PinpointTheme._();

  // ============================================
  // System chrome
  // ============================================

  /// The status- and navigation-bar treatment for an edge-to-edge app.
  ///
  /// Flutter's own [SystemUiOverlayStyle.light] / [SystemUiOverlayStyle.dark]
  /// constants cannot be used here: both hard-code an OPAQUE BLACK
  /// `systemNavigationBarColor`, which paints a black band over the bottom of
  /// a layout that is supposed to run under the gesture bar. From Android 15
  /// (targeting SDK 35+) the system draws every app edge-to-edge whether it
  /// asks to or not, so that band is what a user would actually see.
  ///
  /// `systemNavigationBarContrastEnforced: false` matters for the same reason:
  /// Android 15 removed the automatic scrim it used to paint behind the bars,
  /// and leaving enforcement on reintroduces a translucent strip over content
  /// that is already designed to show through.
  ///
  /// [brightness] is the brightness of the app's own surfaces, so the icons
  /// are set to contrast with it: a dark UI gets light icons.
  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      // iOS reads the OPPOSITE field, and reads it as the brightness of what
      // sits BEHIND the bar rather than of the icons.
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  // ============================================
  // Theme Data
  // ============================================

  /// Dark Sketchbook theme.
  static ThemeData dark({
    SketchAccent accent = SketchAccent.fallback,
    bool highContrast = false,
    bool doodlesEnabled = true,
    String? fontFamily,
  }) =>
      _build(
        brightness: Brightness.dark,
        base: SketchColors.dark,
        accent: accent,
        highContrast: highContrast,
        doodlesEnabled: doodlesEnabled,
        fontFamily: fontFamily,
      );

  /// Light Sketchbook theme.
  static ThemeData light({
    SketchAccent accent = SketchAccent.fallback,
    bool highContrast = false,
    bool doodlesEnabled = true,
    String? fontFamily,
  }) =>
      _build(
        brightness: Brightness.light,
        base: SketchColors.light,
        accent: accent,
        highContrast: highContrast,
        doodlesEnabled: doodlesEnabled,
        fontFamily: fontFamily,
      );

  static ThemeData _build({
    required Brightness brightness,
    required SketchColors base,
    required SketchAccent accent,
    required bool highContrast,
    required bool doodlesEnabled,
    String? fontFamily,
  }) {
    var c = base.copyWith(highlight: accent.pastel);
    if (highContrast) c = c.highContrast(brightness);
    if (!doodlesEnabled) c = c.copyWith(doodlesEnabled: false);

    final textTheme = PinpointTypography.createTextTheme(
      brightness: brightness,
      primaryFont: fontFamily,
    );
    final sketchText = PinpointTypography.createSketchText(
      brightness: brightness,
      primaryFont: fontFamily,
    );

    // Material roles. Primary actions are ink-on-paper (the inverse pill),
    // the accent pastel is "secondary", and the pen blue is "tertiary".
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.inverse,
      onPrimary: c.onInverse,
      primaryContainer: c.highlight,
      onPrimaryContainer: SketchPastels.onPastel,
      secondary: c.highlight,
      onSecondary: SketchPastels.onPastel,
      secondaryContainer: c.highlight,
      onSecondaryContainer: SketchPastels.onPastel,
      tertiary: c.pen,
      onTertiary: c.onInverse,
      tertiaryContainer: SketchPastels.lavender,
      onTertiaryContainer: SketchPastels.onPastel,
      error: SketchFunctional.error,
      onError: Colors.white,
      errorContainer: SketchFunctional.errorFill,
      onErrorContainer: SketchPastels.onPastel,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceDim: c.bg,
      surfaceBright: c.surface,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.bg,
      surfaceContainerHigh: c.soft,
      surfaceContainerHighest: c.soft,
      outline: c.outline,
      outlineVariant: c.hairline,
      shadow: Colors.black,
      scrim: c.scrim,
      inverseSurface: c.inverse,
      onInverseSurface: c.onInverse,
      inversePrimary: c.highlight,
      surfaceTint: Colors.transparent,
    );

    final outlineSide =
        BorderSide(color: c.outline, width: SketchStroke.outline);
    RoundedRectangleBorder rounded(double r, {BorderSide? side}) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: side ?? BorderSide.none,
        );
    WidgetStateProperty<T> both<T>(T v) => WidgetStatePropertyAll<T>(v);
    Color inverseFill(Set<WidgetState> s) => s.contains(WidgetState.disabled)
        ? c.inverse.withValues(alpha: 0.4)
        : c.inverse;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.hairline,
      splashFactory: NoSplash.splashFactory,
      highlightColor: c.soft.withValues(alpha: 0.6),
      hoverColor: c.soft.withValues(alpha: 0.4),
      focusColor: c.highlight.withValues(alpha: 0.5),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        iconTheme: IconThemeData(color: c.ink),
        systemOverlayStyle: systemOverlayStyle(brightness),
        titleTextStyle: sketchText.pageTitle.copyWith(fontSize: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: rounded(SketchRadius.card, side: outlineSide),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: c.inverse,
        disabledColor: c.soft,
        checkmarkColor: c.onInverse,
        labelStyle: sketchText.chip,
        secondaryLabelStyle: sketchText.chip.copyWith(color: c.onInverse),
        side: outlineSide,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: sketchText.bodyRegular.copyWith(color: c.muted),
        labelStyle: sketchText.bodyRegular.copyWith(color: c.muted),
        floatingLabelStyle: sketchText.bodySmall.copyWith(color: c.ink),
        prefixIconColor: c.ink,
        suffixIconColor: c.ink,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SketchRadius.card),
          borderSide: outlineSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SketchRadius.card),
          borderSide: outlineSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SketchRadius.card),
          borderSide: BorderSide(color: c.ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SketchRadius.card),
          borderSide: const BorderSide(
              color: SketchFunctional.error, width: SketchStroke.outline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SketchRadius.card),
          borderSide: const BorderSide(color: SketchFunctional.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.highlight.withValues(alpha: 0.7),
        selectionHandleColor: c.ink,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.inverse,
        foregroundColor: c.onInverse,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(inverseFill),
          foregroundColor: both(c.onInverse),
          textStyle: both(sketchText.button),
          minimumSize: both(const Size(64, 56)),
          padding: both(const EdgeInsets.symmetric(horizontal: 24)),
          shape: both(const StadiumBorder()),
          elevation: both(0),
          overlayColor: both(c.onInverse.withValues(alpha: 0.08)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(inverseFill),
          foregroundColor: both(c.onInverse),
          textStyle: both(sketchText.button),
          minimumSize: both(const Size(64, 56)),
          padding: both(const EdgeInsets.symmetric(horizontal: 24)),
          shape: both(const StadiumBorder()),
          elevation: both(0),
          shadowColor: both(Colors.transparent),
          overlayColor: both(c.onInverse.withValues(alpha: 0.08)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: both(c.ink),
          textStyle: both(sketchText.button),
          minimumSize: both(const Size(64, 56)),
          padding: both(const EdgeInsets.symmetric(horizontal: 24)),
          shape: both(const StadiumBorder()),
          side: both(outlineSide),
          overlayColor: both(c.soft.withValues(alpha: 0.6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: both(c.ink),
          textStyle: both(sketchText.body),
          minimumSize: both(const Size(44, 44)),
          shape: both(const StadiumBorder()),
          overlayColor: both(c.soft.withValues(alpha: 0.6)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: both(c.ink),
          minimumSize: both(const Size(44, 44)),
          overlayColor: both(c.soft.withValues(alpha: 0.6)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? c.inverse
                  : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? c.onInverse : c.ink),
          side: both(outlineSide),
          textStyle: both(sketchText.chip.copyWith(fontSize: 12)),
          shape: both(const StadiumBorder()),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? SketchPastels.mint : c.ink),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.inverse : Colors.transparent),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.inverse : c.outline),
        trackOutlineWidth: both(SketchStroke.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? SketchPastels.mint
                : Colors.transparent),
        checkColor: both(SketchPastels.onPastel),
        side: WidgetStateBorderSide.resolveWith((s) => BorderSide(
            color: s.contains(WidgetState.selected)
                ? SketchPastels.onPastel
                : c.ink,
            width: SketchStroke.checkbox)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(fillColor: both(c.ink)),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.ink,
        inactiveTrackColor: c.soft,
        thumbColor: c.ink,
        overlayColor: c.highlight.withValues(alpha: 0.4),
        valueIndicatorColor: c.inverse,
        valueIndicatorTextStyle: sketchText.chip.copyWith(color: c.onInverse),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
        linearTrackColor: c.soft,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rounded(28, side: outlineSide),
        titleTextStyle: sketchText.emptyTitle,
        contentTextStyle: sketchText.bodyRegular.copyWith(color: c.muted),
        barrierColor: c.scrim,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: c.scrim,
        dragHandleColor: c.hairline,
        dragHandleSize: const Size(40, 5),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SketchRadius.sheet)),
          side: outlineSide,
        ),
        clipBehavior: Clip.antiAlias,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        scrimColor: c.scrim,
        elevation: 0,
        width: 316,
        // Drawer mirrors these for RTL itself.
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(SketchRadius.drawer)),
          side: outlineSide,
        ),
        endShape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(SketchRadius.drawer)),
          side: outlineSide,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rounded(SketchRadius.card, side: outlineSide),
        textStyle: sketchText.body,
        labelTextStyle: both(sketchText.body),
        iconColor: c.ink,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: both(c.surface),
          surfaceTintColor: both(Colors.transparent),
          elevation: both(0),
          shape: both(rounded(SketchRadius.card, side: outlineSide)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverse,
        contentTextStyle:
            sketchText.body.copyWith(fontSize: 14, color: c.onInverse),
        actionTextColor: SketchPastels.yellow,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.inverse,
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: sketchText.chip.copyWith(fontSize: 12, color: c.onInverse),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink,
        textColor: c.ink,
        titleTextStyle: sketchText.body,
        subtitleTextStyle: sketchText.bodySmall,
        shape: rounded(SketchRadius.card),
        selectedColor: c.onInverse,
        selectedTileColor: c.inverse,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.onInverse,
        unselectedLabelColor: c.ink,
        labelStyle: sketchText.chip,
        unselectedLabelStyle: sketchText.chip,
        indicator: BoxDecoration(
            color: c.inverse, borderRadius: BorderRadius.circular(999)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.inverse,
        selectedItemColor: c.onInverse,
        unselectedItemColor: c.onInverse.withValues(alpha: 0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: c.inverse,
        textColor: c.onInverse,
      ),
      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: SketchStroke.outline,
        space: SketchStroke.outline,
      ),
      iconTheme: IconThemeData(color: c.ink, size: 22),
      primaryIconTheme: IconThemeData(color: c.onInverse, size: 22),
      extensions: [
        c,
        sketchText,
      ],
    );
  }
}
