# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"FN Concretera" — a Flutter app for a concrete company. Note the package name in `pubspec.yaml` is `fn_concretos`, even though the directory/repo is `my_flutter_app`.

The app is currently a UI shell/prototype: navigation, theming, and screen layouts are built out, but there is no backend integration, no persistence, and no real authentication — login accepts any input and just pushes to the home screen.

## Commands

- Install dependencies: `flutter pub get`
- Run the app (choose a connected device/simulator): `flutter run`
- Static analysis (uses `flutter_lints` via `analysis_options.yaml`): `flutter analyze`
- Format code: `dart format .`
- Run tests: `flutter test` (there are currently no test files in the project)
- Build platform targets as needed: `flutter build apk`, `flutter build ios`, `flutter build macos`, `flutter build web`, etc.

There is no CI config, no lockstep test suite, and no custom build scripts — this is a stock `flutter create` project structure.

## Architecture

`lib/` is organized by feature folder, each holding its screen(s) plus any content that's specific to that screen; `lib/widgets/` holds components shared across features. Screens navigate via `Navigator.push`/`pushReplacement` with `MaterialPageRoute` — there is no named-route table or router package.

Navigation flow: `main.dart` → `SplashScreen` (3s delay) → `LoginScreen` (any credentials accepted) → `HomeScreen`.

- **`main.dart`** — app entry point and the single global piece of state: `themeNotifier`, a top-level `ValueNotifier<ThemeMode>` (defaults to `ThemeMode.dark`) that `MaterialApp` listens to for light/dark theme switching. Any widget can flip the theme by setting `themeNotifier.value` (see `profile/profile_screen.dart`). There is no other shared/global state and no state management package (no Provider/Riverpod/Bloc) — each screen manages its own local `State`.
- **`auth/`** — `splash_screen.dart` and `login_screen.dart`.
- **`home/`** — `home_screen.dart` is the app's shell after login: no `AppBar` (removed — each tab's own content starts right at the top, inside a `SafeArea(bottom: false)` so it still clears the status bar/notch), a bottom `BottomNavBar`, and four tabs (folders `home`/`orders`/`inventory`/`profile`, shown to users as "Inicio"/"Pedidos"/"Inventario"/"Perfil"), each kept mounted and cross-faded in/out (`AnimatedOpacity` + `AnimatedScale`, not `IndexedStack`) so tab state survives switching; `_currentIndex` here is the single source of truth for which tab is active. `dashboard_content.dart` is the Home tab's content, deliberately built around one clear focal point rather than a uniform grid: a large gradient `_HeroCard` for the single most important metric, secondary metrics and quick actions as horizontally-scrolling rows (not a `GridView`/fixed `Row`, so they get breathing room instead of being squeezed to fit), and a `_NextVisitCard` teaser into the `visits/` feature — all still static placeholder data.
- **`orders/`**, **`inventory/`** — currently thin wrappers around `PlaceholderContent`; expected to grow real functionality later.
- **`profile/`** — user profile UI with an edit-profile dialog (local state only, not persisted) and the dark-mode toggle that writes to `themeNotifier`; "Log Out" just navigates back to `LoginScreen` (no real session teardown).
- **`visits/`** — `visit_screen.dart` (`VisitScreen`) is a concept mock for the app's core planned workflow: a sales rep visits a job site, captures its data and location, then creates a quote. `_MapPreview`/`_MapGridPainter` fake a Google Maps tile with `CustomPaint` — there's no maps SDK or API key wired up, it's purely visual. Reached from the Home tab's "Visitar obra" quick action in `dashboard_content.dart`; "Crear cotización" only shows a `SnackBar` and pops, no quote is actually persisted anywhere.
- **`widgets/`** — `bottom_nav_bar.dart` (floating pill-shaped bottom nav; the active icon gets a solid accent-colored circle, no labels shown; takes a list of `NavItem` and an `onTap` callback, has no knowledge of the screens it switches between; exposes `BottomNavBar.clearance(context)` so scrollable screens can pad their bottom content enough to clear the floating bar), `placeholder_content.dart` (shared "not implemented yet" layout used by tabs without real content).

## Conventions to note

- UI copy (anything the user sees on screen) is in Spanish. Code — folder/file names, class/variable names, and comments — is in English. Don't mix the two the wrong way: e.g. `lib/orders/orders_screen.dart` (English path/class) renders the title "Pedidos" (Spanish).
- `profile/profile_screen.dart`'s cards (`_SettingsGroup`, the profile-summary card) are theme-aware, not the seed-derived `colorScheme.surfaceContainerHighest` (which skews yellow on this app's yellow-seeded `ColorScheme` — rejected explicitly). Dark mode: solid near-black `Color(0xFF141414)` with a light border, so it stands out against the dark scaffold. Light mode: white with a black-ish border instead of black fill — a black box read as a stray error state on a light background. Text/icon colors on these cards (`onCardText`/`onCardMuted` locals) are computed per-theme to match, since the card color doesn't come from `Theme.of(context)` directly.
- Brand color is yellow, `Color(0xFFFFCC00)`, used as the seed color for both light/dark `ColorScheme`s. For accents (icons, highlights, the nav bar's active-item circle), always hardcode this literal `Color(0xFFFFCC00)` rather than reading `colorScheme.primary` — Material3's tonal palette generation shifts the seed into a duller, less saturated yellow for the `primary` role, which reads as washed out next to the bar's true brand yellow. This was called out explicitly after `colorScheme.primary` crept into `profile_screen.dart` and `placeholder_content.dart`.
- Background images (`assets/images/background.png`, `assets/images/logo.png`) are expected to exist; screens fall back to an icon via `errorBuilder` if missing.
