import 'package:flutter/material.dart';

/// Single source of truth for every color used across the app — brand
/// accent, status colors, and the theme-aware surface/text helpers that
/// nearly every screen recomputed inline via its own `isDark ? ... : ...`
/// ternary.
///
/// Before this file, almost every screen redeclared its own local
/// `const _accentYellow = Color(0xFFFFCC00);` (~30 files) — and a couple
/// drifted to a different literal for the exact same color
/// (`Color.fromRGBO(255, 204, 0, 1)`, `Color.fromARGB(255, 7, 7, 7)` for
/// "black"), which is how the project ended up with visibly inconsistent
/// yellows in places like `vehicle_screen.dart`. Import this instead of
/// redeclaring a local constant.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------

  /// FN Concretos brand yellow. Always this literal for accents (icons,
  /// highlights, active-nav-item circle, primary buttons) — never
  /// `Theme.of(context).colorScheme.primary`: Material3's tonal palette
  /// generation shifts the seed into a duller, less saturated yellow for
  /// the `primary` role (called out explicitly after `colorScheme.primary`
  /// crept into `profile_screen.dart`/`placeholder_content.dart`).
  static const accent = Color(0xFFFFCC00);

  /// Text/icon color on top of a solid [accent] fill (active nav-bar
  /// circle, primary buttons) — plain black reads best on this yellow.
  static const onAccent = Colors.black;

  // ---------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------

  /// Success / resuelto / firmada / completo / vigente.
  static const success = Color(0xFF4CAF50);

  /// Error / rechazado / falla / vencido.
  static const error = Color(0xFFEF5350);

  /// Warning / en mantenimiento / pendiente abierto / por vencer.
  static const warning = Color(0xFFFFA000);

  // ---------------------------------------------------------------------
  // Native launch screen
  // ---------------------------------------------------------------------

  /// Splash/native-launch-screen background — must stay in sync with the
  /// native launch screens (`android/app/.../drawable/launch_background.xml`,
  /// `ios/Runner/Base.lproj/LaunchScreen.storyboard`, both `#15181B`) so
  /// there's no visible flash between the OS's launch screen and the
  /// splash video's first frame.
  static const splashBackground = Color(0xFF15181B);

  // ---------------------------------------------------------------------
  // Theme-aware surfaces/text — the "dark mode solid near-black
  // Color(0xFF141414) with a light border; light mode white with a
  // black-ish border" card pattern documented in CLAUDE.md (recurs across
  // deliveries/, vehicle/, direccion/, profile/), plus the matching
  // text/muted-text colors. Deliberately not `colorScheme.surfaceContainerHighest`
  // — skews yellow on this app's yellow-seeded ColorScheme (rejected
  // explicitly).
  // ---------------------------------------------------------------------

  static bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Card/container surface.
  static Color card(BuildContext context) => _isDark(context) ? const Color(0xFF141414) : Colors.white;

  /// Slightly different dark-mode surface used by AppBars, bottom sheets,
  /// and the bottom nav bar's tint — one shade lighter than [card] so
  /// stacked surfaces still read as distinct layers.
  static Color surfaceAlt(BuildContext context) => _isDark(context) ? const Color(0xFF1E1E1E) : Colors.white;

  /// Card border. [alpha] varies a bit by call site in the wild (0.08 for
  /// list-style cards, 0.10-0.12 for elevated ones) — pass whichever the
  /// original screen used.
  static Color border(BuildContext context, {double alpha = 0.10}) =>
      (_isDark(context) ? Colors.white : Colors.black).withValues(alpha: alpha);

  /// Primary on-card text.
  static Color text(BuildContext context) => _isDark(context) ? Colors.white : Colors.black87;

  /// Secondary/muted on-card text (subtitles, hints, timestamps).
  static Color mutedText(BuildContext context, {double alpha = 0.55}) =>
      (_isDark(context) ? Colors.white : Colors.black).withValues(alpha: alpha);
}
