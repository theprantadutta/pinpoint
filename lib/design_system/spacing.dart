/// Pinpoint Design System - Spacing
/// Consistent spacing scale based on 4px/8px grid for brutalist/bold aesthetic
class PinpointSpacing {
  // Private constructor to prevent instantiation
  PinpointSpacing._();

  // ============================================
  // Base Grid System
  // ============================================

  /// Base unit - 4px (smaller increments)
  static const double baseUnit = 4.0;

  /// Grid unit - 8px (standard increment)
  static const double gridUnit = 8.0;

  // ============================================
  // Spacing Scale
  // ============================================

  /// None - 0px
  static const double none = 0.0;

  /// Extra extra small - 2px
  static const double xxs = 2.0;

  /// Extra small - 4px
  static const double xs = 4.0;

  /// Small - 8px
  static const double sm = 8.0;

  /// Medium small - 12px (NEW: for better granularity)
  static const double ms = 12.0;

  /// Medium - 16px
  static const double md = 16.0;

  /// Medium large - 20px (NEW: for brutalist spacing)
  static const double ml = 20.0;

  /// Large - 24px
  static const double lg = 24.0;

  /// Extra large - 32px
  static const double xl = 32.0;

  /// Extra extra large - 40px (NEW: bold spacing)
  static const double xxl = 40.0;

  /// Extra extra extra large - 48px (NEW: hero sections)
  static const double xxxl = 48.0;

  /// Huge - 64px (NEW: dramatic spacing)
  static const double huge = 64.0;

  // ============================================
  // Semantic Spacing (Brutalist/Bold)
  // ============================================

  /// Compact padding - for tight layouts
  static const double paddingCompact = sm; // 8px

  /// Default padding - standard UI elements
  static const double paddingDefault = md; // 16px

  /// Comfortable padding - spacious layouts
  static const double paddingComfortable = ml; // 20px

  /// Generous padding - bold, breathing room
  static const double paddingGenerous = lg; // 24px

  /// Hero padding - dramatic spacing for hero sections
  static const double paddingHero = xl; // 32px

  /// Section spacing - between major sections
  static const double sectionSpacing = xl; // 32px

  /// List item spacing - between list items
  static const double listItemSpacing = ms; // 12px

  /// Card spacing - between cards
  static const double cardSpacing = md; // 16px

  /// Icon padding - around icons
  static const double iconPadding = sm; // 8px

  /// Button padding horizontal
  static const double buttonPaddingH = lg; // 24px

  /// Button padding vertical
  static const double buttonPaddingV = ms; // 12px

  /// Input padding horizontal
  static const double inputPaddingH = md; // 16px

  /// Input padding vertical
  static const double inputPaddingV = ms; // 12px

  /// Screen edge padding (mobile)
  static const double screenEdge = ml; // 20px

  /// Screen edge padding (tablet/desktop)
  static const double screenEdgeLarge = xl; // 32px

  // ============================================
  // Helper Methods
  // ============================================

  /// Get spacing by multiplier
  static double scale(double multiplier) => gridUnit * multiplier;

  /// Get spacing by index (0-10)
  static double byIndex(int index) {
    switch (index) {
      case 0:
        return none;
      case 1:
        return xs;
      case 2:
        return sm;
      case 3:
        return ms;
      case 4:
        return md;
      case 5:
        return ml;
      case 6:
        return lg;
      case 7:
        return xl;
      case 8:
        return xxl;
      case 9:
        return xxxl;
      case 10:
        return huge;
      default:
        return md; // Default to medium
    }
  }
}

/// Spacing presets for common UI patterns
class SpacingPresets {
  // Card spacing
  static const cardPadding = EdgeInsets.all(PinpointSpacing.paddingDefault);
  static const cardPaddingGenerous = EdgeInsets.all(PinpointSpacing.paddingGenerous);

  // List spacing
  static const listItemPadding = EdgeInsets.symmetric(
    horizontal: PinpointSpacing.screenEdge,
    vertical: PinpointSpacing.listItemSpacing,
  );

  // Screen spacing
  static const screenPadding = EdgeInsets.all(PinpointSpacing.screenEdge);
  static const screenPaddingH = EdgeInsets.symmetric(horizontal: PinpointSpacing.screenEdge);
  static const screenPaddingV = EdgeInsets.symmetric(vertical: PinpointSpacing.screenEdge);

  // Section spacing
  static const sectionGap = SizedBox(height: PinpointSpacing.sectionSpacing);
  static const cardGap = SizedBox(height: PinpointSpacing.cardSpacing);
  static const listGap = SizedBox(height: PinpointSpacing.listItemSpacing);

  // Button spacing
  static const buttonPadding = EdgeInsets.symmetric(
    horizontal: PinpointSpacing.buttonPaddingH,
    vertical: PinpointSpacing.buttonPaddingV,
  );

  // Input spacing
  static const inputPadding = EdgeInsets.symmetric(
    horizontal: PinpointSpacing.inputPaddingH,
    vertical: PinpointSpacing.inputPaddingV,
  );
}
