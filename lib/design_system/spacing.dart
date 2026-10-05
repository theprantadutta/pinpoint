import 'package:flutter/material.dart';

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
  static const cardPaddingGenerous =
      EdgeInsets.all(PinpointSpacing.paddingGenerous);

  // List spacing
  static const listItemPadding = EdgeInsets.symmetric(
    horizontal: PinpointSpacing.screenEdge,
    vertical: PinpointSpacing.listItemSpacing,
  );

  // Screen spacing
  static const screenPadding = EdgeInsets.all(PinpointSpacing.screenEdge);
  static const screenPaddingH =
      EdgeInsets.symmetric(horizontal: PinpointSpacing.screenEdge);
  static const screenPaddingV =
      EdgeInsets.symmetric(vertical: PinpointSpacing.screenEdge);

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

// ============================================
// Sketchbook
// ============================================

/// Sketchbook spacing. Logical px at a 390-wide reference screen; the layout
/// scales with width rather than these values.
class SketchSpace {
  SketchSpace._();

  /// Screen horizontal padding.
  static const double screenX = 20;

  /// Editor text horizontal padding.
  static const double editorX = 24;

  /// Header row top padding below the status bar.
  static const double headerTop = 8;

  /// Between sections.
  static const double section = 22;

  /// Section title to its content.
  static const double titleToContent = 12;

  /// Grid / card gap.
  static const double grid = 12;

  /// Chip gap.
  static const double chip = 8;

  static const double cardPad = 14;
  static const double cardPadLg = 16;

  /// Dock offset from the bottom (plus the system inset).
  static const double dockBottom = 26;

  /// Bottom padding a scroll view needs so nothing hides behind the dock.
  static const double dockClearance = 110;

  /// Minimum tap target.
  static const double minTap = 44;

  /// Content max width on tablets — the mocks are phone-width, and a 1.5px
  /// outlined card stretched to 1200px stops reading as a card.
  static const double maxContentWidth = 720;
}

/// Sketchbook corner radii.
class SketchRadius {
  SketchRadius._();

  static const double card = 18;
  static const double group = 20;
  static const double banner = 22;
  static const double sheet = 34;
  static const double drawer = 34;
  static const double dock = 31;
  static const double checkbox = 8;
  static const double checkboxSmall = 4;
  static const double bullet = 4;
  static const double folderTab = 14;
  static const double folderBody = 16;
  static const double highlight = 4;
}

/// Sketchbook stroke widths.
class SketchStroke {
  SketchStroke._();

  /// Standard outline on cards, chips, circle buttons, inputs.
  static const double outline = 1.5;

  /// Outline on a pastel element.
  static const double pastel = 1.2;

  /// Checkbox stroke.
  static const double checkbox = 2;

  /// Dashed "add" affordance.
  static const double dashLength = 6;
  static const double dashGap = 4;
}
