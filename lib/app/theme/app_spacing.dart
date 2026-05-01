/// Design-system spacing tokens for the Slock app.
///
/// All values are in logical pixels. Use these instead of ad-hoc
/// numbers to maintain visual rhythm across the UI.
abstract final class AppSpacing {
  // --- Base scale (4px grid) ---

  /// 4 lp — minimal spacing (icon to label, inline elements).
  static const double xs = 4;

  /// 8 lp — tight spacing (compact list items, chip padding).
  static const double sm = 8;

  /// 12 lp — default intra-element spacing.
  static const double md = 12;

  /// 16 lp — default padding (cards, tiles, section start).
  static const double lg = 16;

  /// 24 lp — section separation, dialog padding.
  static const double xl = 24;

  /// 32 lp — large section separation.
  static const double xxl = 32;

  /// 48 lp — page-level breathing room.
  static const double xxxl = 48;

  // --- Semantic aliases ---

  /// Horizontal page padding (left/right gutter).
  static const double pageHorizontal = lg;

  /// Vertical spacing between major sections.
  static const double sectionGap = xxl;

  /// Card internal padding.
  static const double cardPadding = lg;

  /// List item vertical padding.
  static const double listItemVertical = md;

  /// Border radius — small elements (chips, badges).
  static const double radiusSm = 6;

  /// Border radius — medium elements (cards, inputs).
  static const double radiusMd = 12;

  /// Border radius — large elements (dialogs, sheets).
  static const double radiusLg = 16;

  /// Border radius — full / pill.
  static const double radiusFull = 999;
}
