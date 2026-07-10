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

All app code lives flat in `lib/` (no subfolders/feature modules yet). Screens navigate via `Navigator.push`/`pushReplacement` with `MaterialPageRoute` — there is no named-route table or router package.

Navigation flow: `main.dart` → `SplashScreen` (3s delay) → `LoginScreen` (any credentials accepted) → `HomeScreen`.

- **`main.dart`** — app entry point and the single global piece of state: `themeNotifier`, a top-level `ValueNotifier<ThemeMode>` that `MaterialApp` listens to for light/dark theme switching. Any widget can flip the theme by setting `themeNotifier.value` (see `profile_screen.dart`). There is no other shared/global state and no state management package (no Provider/Riverpod/Bloc) — each screen manages its own local `State`.
- **`home_screen.dart`** — the app's shell after login. Holds a bottom `FloatingNavBar` and an `IndexedStack` of four tabs (Inicio, Pedidos, Inventario, Perfil), keeping each tab's state alive when switching. `_currentIndex` here is the single source of truth for which tab is active.
- **`floating_nav_bar.dart`** — the custom rounded bottom nav bar with an animated selection indicator; takes a list of `NavItem` and an `onTap` callback, has no knowledge of the screens it switches between.
- **`pedidos_screen.dart`**, **`inventario_screen.dart`** — currently thin wrappers around `PlaceholderContent`; expected to grow real functionality (orders, inventory) later.
- **`placeholder_content.dart`** — shared "not implemented yet" layout (icon + title + message) used by tabs that don't have real content.
- **`profile_screen.dart`** — user profile UI with an edit-profile dialog (local state only, not persisted) and the dark-mode toggle that writes to `themeNotifier`; "Cerrar Sesión" just navigates back to `LoginScreen` (no real session teardown).
- **`striped_banner.dart`** — a `CustomPainter`-based diagonal-stripe banner used under the `AppBar` in `home_screen.dart`.

## Conventions to note

- UI copy/strings are in Spanish; keep new user-facing text consistent with that.
- Brand color is yellow, `Color(0xFFFFCC00)`, used as the seed color for both light/dark `ColorScheme`s and reused directly (hardcoded) in several widgets rather than pulled from `Theme.of(context)` consistently — check existing screens for the pattern being extended before introducing a new accent color.
- Background images (`assets/images/background.png`, `assets/images/logo.png`) are expected to exist; screens fall back to an icon via `errorBuilder` if missing.
