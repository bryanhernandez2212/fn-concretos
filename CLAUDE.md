# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"FN Concretera": a Flutter mobile client for a concrete company. The package name is `fn_concretos`. The directory is `fn-concretos`, and some leftover scaffolding (`my_flutter_app.code-workspace`, iOS `RunnerTests`) still uses `my_flutter_app`.

The app routes by role/permission and talks to six real backend microservices. A few pieces are still mock data (see "Still mock" below). Check the specific screen before assuming whether something is real.

## Commands

- `flutter pub get` installs dependencies. `flutter run` runs the app.
- `flutter analyze` runs lints (`flutter_lints`; native/build dirs are excluded in `analysis_options.yaml`).
- `dart format .` formats the code.
- `flutter test` runs tests, and `flutter test path/to/file_test.dart` runs a single file. There is no `test/` directory yet.
- There is no CI and there are no custom build scripts.
- When installing on a real iOS device, run `flutter build ios --release` explicitly before `flutter install`. Debug builds crash on the dev iPhone, and `flutter install` can pick up a stale build.

## Native setup gotchas

- **Google Maps / Navigation SDK**: the key lives in `AndroidManifest.xml` / `AppDelegate.swift`. Without the key, maps render grey. Without Navigation SDK access, turn-by-turn fails with "No se pudo calcular la ruta". Routes API (REST `computeRoutes`, used by Dirección's ETA and remaining-route line) is enabled on the same key.
- **`local_auth`**: `MainActivity.kt` extends `FlutterFragmentActivity`, and `Info.plist` has `NSFaceIDUsageDescription`. Known gap: `styles.xml` themes aren't AppCompat, which can crash the biometric dialog on Android 7.0–8.1 (minSdk 24).
- **Ids**: the Android `applicationId` is `com.fnconcretos.app`, which matches the Firebase/OneSignal registration. The iOS bundle id is `com.bryan.fn`. They don't match on purpose: OneSignal is Android-only for now, because the project only has a free Apple ID.
- **`model_viewer_plus`** serves its viewer from a plain-HTTP loopback server. `res/xml/network_security_config.xml` allows cleartext only for `127.0.0.1`/`localhost`. Don't replace it with a blanket `usesCleartextTraffic`.
- **Android Live Update notification** during navigation lives in `deliveries/navegacion/navigation_live_update.dart`, which is a MethodChannel `fn_concretos/navigation_live_update` to `NavigationLiveUpdateManager.kt`. Its `PendingIntent` carries `MainActivity.EXTRA_REMISION_ID`.
  - A warm tap goes through `onNewIntent` → `onNotificationTap`.
  - A cold start goes through `consumeLaunchRemisionId()`, called from `main.dart`.
  - Both paths end at `_handleRouteNotificationTap` → `EntregasService.remisionPorId()` → `DeliveryDetailScreen`.
  - Promoted cards need OS support plus a user setting. Base Android 16 renders them as ordinary notifications.
- **Splash**: the background `Color(0xFF15181B)` must match `launch_background.xml` and `LaunchScreen.storyboard`.

## Architecture

### Layout

`lib/` is organized by feature folder. Large features split into sub-area folders:

- `direccion/`: `autorizaciones/`, `pedidos/`, `rutas/`, `live_tracking/`, `ordenes_compra/`
- `asesor_comercial/`: `visitas/`, `cotizaciones/`, `clientes_obras/`, `comisiones/`, `solicitudes_diseno/`
- `deliveries/`: `listado/`, `detalle/`, `evidencias/`, `pruebas_campo/`, `navegacion/`
- `auth/`: `login/`, `recuperar_password/`, `biometria/`

Each feature's home shell and shared service/DTO sit at the feature root.

Services and DTOs used by several features live in a top-level folder named after their backend service: `comercial/`, `operaciones/`, `catalogo/`, `finanzas/`, `administracion/`. `lib/config/api_config.dart` (`ApiConfig`) holds every base URL (`$_host/<service>`, sandbox only).

Shared UI:
- `lib/widgets/` holds `BottomNavBar`, `AppSnack`, `FieldGroup`, `InfoPill`, `HeaderIconButton`, `NotificationBellButton`, `ContactoCard`, `WhatsappButton`, `EvidenciaViewerScreen` and `RastreoInfoCard`.
- `lib/theme/app_colors.dart` (`AppColors`) is the only source of brand, status and card-surface colors.

Large screens keep their State in the screen file. Self-contained UI moves into a sibling `<screen>_widgets.dart` or `_sections.dart` as public StatelessWidgets that take plain values and callbacks.

### State & navigation

- There is no state-management package and no router. Screens use `Navigator.push` with `MaterialPageRoute` and hold their own local State.
- The only cross-screen state is `main.dart`'s `themeNotifier` (`ValueNotifier<ThemeMode>`, default dark), the static session fields on `AuthService`, and `main.dart`'s `navigatorKey` (for push/notification taps). Keep to the "static field, no package" pattern.
- Startup goes `SplashScreen`, which plays `splash.mp4` while `AuthService.restoreSession()` runs in parallel. The user then goes to either `LoginScreen` or `destinationForSession()` (`auth/login/login_screen.dart`). If biometrics are enabled, a restored session goes through `BiometricLockScreen` first.
- Routing, in order:
  1. A role in `roles.dart`'s `rolesConAppMovil` (`Operador de Olla`/`Operador de Bomba`) goes to `home/HomeScreen`: Entregas / Vehículo / Perfil.
  2. The permission `pedidos.autorizar_credito` goes to `DireccionHomeScreen`: Autorizaciones / Compras (only with `ordenes_compra.autorizar`) / Rutas / Perfil.
  3. The permission `agenda.administrar` goes to `AsesorComercialHomeScreen`: Visitas / Cotizaciones / Comisiones (hidden if `miAsesor()` returns a 404) / Perfil.
  4. Everyone else goes to `RoleUnavailableScreen`.
- Dirección and Asesor routing is by **permission, not role name** on purpose, because the backend can move permissions between roles. `catalogoRoles` in `roles.dart` only mirrors role names and descriptions for display.
- The shells keep every tab mounted and cross-fade between them (`AnimatedOpacity`+`AnimatedScale`, not `IndexedStack`). Scrollable tabs pad by `BottomNavBar.clearance(context)`.
- Top header rows: a tab's own action button (a `HeaderIconButton`) goes **before** the `NotificationBellButton`. Dirección hides that header row on Rutas, because Rutas has its own `AppBar`.

### Backend services

All services use `AuthService.authHeaders()` (bearer auth, with a token refresh before each call). Transport errors become `AuthException('No se pudo conectar con el servidor')`; follow that pattern in any new call.

Services import `config/http_client.dart` `as http`, never `package:http` directly. It is a drop-in for `get`/`post`/`put`/`patch`/`delete` backed by one shared keep-alive `http.Client`, so connections get reused instead of opening a new TLS handshake per call. Any new service file must use the same import.

- **auth** (`auth/auth_service.dart`) handles login, MFA (TOTP), password flows, `/auth/me` and logout.
  - The refresh token is kept in `flutter_secure_storage` so `restoreSession()` can log the user back in.
  - `POST /auth/validate` is deliberately not implemented, because it's gateway-only.
  - MFA is mandatory for Dirección by policy, but the backend doesn't enforce it. `DireccionHomeScreen` shows a nudge dialog that can be dismissed.
  - Biometrics are a **local device gate only**, with no backend concept. Turning them on also turns on token persistence.
  - `notifications/notificaciones_service.dart` (the inbox, bell count, mark-read) also lives on the auth sandbox.
- **comercial** (`comercial/comercial_service.dart`, `pedido.dart`) handles pedidos, clientes, obras, contactos and estado de cuenta.
  - It has a 60s in-memory `_cached` for cliente/obra/estado de cuenta/contactos lookups. It's deliberately not used for the pending-authorization queue, `obtenerPedido` or writes. This is the only HTTP cache in the app.
  - A pedido's contact is resolved per obra+cliente pairing: `contactoParaEntrega({obraId, clienteId})`.
  - `GET /obras` only takes `q`/`ciudad`/`estatus`. `buscarObras(clienteId:)` filters on the client by `clientePrincipalId`, so obras where the cliente is only a linked secondary client (`/obras/{id}/clientes`) don't show up.
  - `EstadoCuenta.disponible == false` means the data is stubbed. Show it that way, not as "al corriente".
  - Delivered volume and status update on the server when each remisión's firma is registered. `PedidoDetailScreen` re-polls `obtenerPedido` every 15s.
- **asesor_comercial** (`asesor_comercial_service.dart`) covers asesores, visitas, cotizaciones and solicitudes de diseño on the comercial sandbox.
  - `miAsesor()` calls `GET /asesores/me` and returns `null` on 404.
  - Cotizaciones have multiple line items (`producto`/`bombeo`/`servicio`). The backend generates `flete_vacio` lines itself; the form only previews them.
  - `plantaId` comes from the obra, then from the asesor, then from a manual pick.
  - The discount field is always shown. The backend enforces the limits.
  - Editing sends a full `PUT` of the cotización.
  - Converting to a pedido pops back with a snackbar. It doesn't open Dirección's `PedidoDetailScreen`.
  - Obra/visita creation flow: `ClientePickerScreen`, then `ObraFormScreen` (interactive pin picker; native reverse-geocode through the `geocoding` package, not the Google Geocoding API), then `VisitaFormScreen`. "Al instante" chains into check-in; "Programar" doesn't.
  - Check-in photos upload through **operaciones'** presigned URL, because comercial has no upload endpoint.
  - Obra maps stay in the app. An external "open in Google Maps" hand-off was tried and rejected.
- **catalogo** (`catalogo/catalogo_service.dart`) provides read-only plantas, productos (`q=`), per-planta precios and elementos constructivos, for cotizaciones.
- **finanzas** (`finanzas/finanzas_service.dart`):
  - Comisiones: Proyección (`/comisiones-periodo/proyeccion`, computed on the fly) must carry the "esto es una PROYECCIÓN" disclaimer. Historial is processed cortes. `asesorId` is `Asesor.id`, not the auth id.
  - Órdenes de compra: list, detail, bitácora, autorizar and rechazar only. Dirección's list filters client-side with `OrdenCompra.porAutorizar`. That estatus value is **unverified** against live data.
  - Production URLs (`fnconcretos.app/api/...`) returned 502 on 2026-09-24, so the app stays on the sandbox.
- **operaciones** (`operaciones/operaciones_service.dart`) covers programación de producción, remisiones, the hito state machine, GPS, firma/archivos/evidencias (presigned uploads), pruebas de concreto, and vehiculos/mantenimientos/pendientes/documentos/modelos 3D.
  - Write gates: `permisoOperarRemisiones` (`remisiones.operar`) and `permisoReportarPendienteVehiculo`. The caller checks these before calling.
  - GPS source per vehicle (`operaciones/rastreo_gps.dart`): `VehiculoResumen.origenGps` is either `samsara` or anything else, which means phone GPS. With `samsara`, the backend ingests positions from the Samsara device, and **the phone must not send its own** (`OrigenGps.telefonoEnviaPosicion`). Anything unknown falls back to phone GPS. The Samsara token lives only on the backend. `RastreoInfoCard` tells the driver which source is active.
- **administracion** (`administracion/administracion_service.dart`) provides `GET /empleados/{id}` for profile data. Photo updates do a full `PUT /empleados/{id}`, round-tripping the other fields. It has its own presigned-upload endpoint.

### Feature notes

- **Deliveries**:
  - How `EntregasService.entregasDelDia(fecha:)` builds the list:
    1. It fetches `programacion-produccion?fecha=`, which is the whole plant's schedule.
    2. It fetches `remisiones?pedidoId=` and keeps only those with `conductorId == AuthService.idEmpleado`. That id-space match is an **unverified assumption**.
    3. It fetches the comercial pedido/obra/contacto.
  - Don't use `/asignaciones` to decide ownership. It comes back empty for pedidos that already have remisiones.
  - A pedido with no remisión doesn't appear, because the app never creates remisiones.
  - Each matching remisión produces its own list entry, including several trips on one pedido.
  - The hito sequence is `cargandoPlanta → … → entregado`, advanced through `avanzarHito`, and the server response is the source of truth.
  - `RouteNavigationScreen` auto-registers `salioPlanta`, then `enCamino`, then `proximoLlegar` at 1 km remaining.
  - Firma and evidencia rows unlock at `descargando`. Only one firma is allowed (the backend returns 409 on a second), after which the row becomes view-only.
  - Still mock: `DosificacionScreen`.
- **RouteNavigationScreen** quirks (confirmed on device):
  - `setNavigationUIEnabled(true)` must be called after `startGuidance()`, because `automatic` only checks at view creation.
  - The bottom `RouteNavBottomBar` must stay in the `Stack`. Without it, the platform view collapses. It is transparent so the native chrome shows through.
  - "Finalizar ruta" pops straight away. Only the back arrow and the system back gesture confirm first.
- **Dirección live tracking**:
  - `PedidoDetailScreen` shows one tracking card per remisión. `RutasActivasScreen` shows the whole fleet on one map; it lists unfiltered `/remisiones` and filters to in-route estatus on the client.
  - Both poll `/remisiones/{id}/ruta` every 15s.
  - Heading and speed are derived on the client from the last two points (`vehicle_marker_icon.dart`).
  - Map sprites are drawn on a `Canvas`, not image assets: a shaded top-down olla in the route's color (`VehicleMarkerIcon`) and a checkered-flag llegada pin at the obra (`DestinoMarkerIcon`, skipped when the obra comes back as 0,0). Both expose `paint()`/`renderPng()`, so a throwaway `flutter test` can render them to a PNG for previewing.
  - The backend only returns raw GPS pings. `RecorridoPorCalles` turns them into the street path via Routes API `via` waypoints, in cached tramos of 12 points (≤10 intermediates keeps the Essentials SKU). Only the growing last tramo is re-routed, at most once per 60s. Unrouted pings still draw as straight lines.
  - ETA, progress and the road route still ahead (drawn lighter next to the GPS trail, only while `salio_planta`/`en_camino`/`proximo_llegar`) all come from one Routes API call in `DirectionsService`, throttled to once per 60s per remisión (billed per request). Between calls, `RouteEtaTracker.rutaRestanteDesde` trims the already-driven part.
  - "Pantalla completa" hides the list but never rebuilds the native map.
- **Vehicle**:
  - `VehiculoService.miVehiculo()` fetches the fleet and matches `conductorAsignadoId` to `idEmpleado`.
  - Documents and pendientes are read-only. Reporting a pendiente takes an optional photo, stored in `evidenciaApertura`.
  - The 3D model comes from `VehiculoResponse.modelo3dUrl`, falling back to the first active entry in `/modelos-3d?tipoVehiculoId=`.
- **Notifications**:
  - The OneSignal client (Android) sets `OneSignal.login` to the **`usuarioId`**, not `idEmpleado`. `rol`/`permisos` are sent as tags.
  - The push-permission prompt only appears on an explicit login or MFA verify, never during `restoreSession`.
  - The backend sends the pushes; the app never triggers them. Tapping one opens `NotificacionesScreen`, with no deep links, because the `referenciaTipo` values aren't documented.
- **Profile**: planta and ciudad were removed because `/auth/me` never returned them. Don't bring them back without a backend source.

## Conventions

- UI copy is in Spanish. Code identifiers, file names and comments are in English.
- For accents, use `AppColors.accent` (`#FFCC00`), never `colorScheme.primary`, which comes out as a duller yellow from the tonal palette. Don't add local color constants.
- Card surfaces use `AppColors.card`/`surfaceAlt`/`border`/`text`/`mutedText` (they take a `BuildContext`) or `FieldGroup`: near-black with a light border in dark mode, white with a dark border in light mode. Never use `surfaceContainerHighest`, which picks up a yellow tint.
- User feedback goes through `AppSnack.success`/`.error`/`.info`, not a raw `SnackBar`.
- `RefreshIndicator` screens always return a scrollable (such as a `ListView`) in every loading, error and data state.
- Best-effort secondary lookups (names, addresses, refreshes after a write) fail silently and show the raw id or skip the card. They never break the screen.
- Don't show made-up data. If there's no name lookup, show the raw id. Don't collect input the backend would throw away.
- For a redesign, change only the piece that was named. Suggest other improvements instead of making them.
