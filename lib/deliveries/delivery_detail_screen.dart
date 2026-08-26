import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/evidencia.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/contacto_card.dart';
import '../widgets/evidencia_viewer_screen.dart';
import '../widgets/field_group.dart';
import 'delivery_detail_widgets.dart';
import 'delivery_photo_screen.dart';
import 'evidencia_fotos_screen.dart';
import 'dosificacion_screen.dart';
import 'prueba_concreto_screen.dart';
import 'remision.dart';
import 'route_navigation_screen.dart';
import 'signature_screen.dart';

/// The 7-step sequential progression, excluding [HitoEntrega.conIncidencia]
/// (an exception state, not a step to render in a linear stepper).
const _secuenciaHitos = [
  HitoEntrega.cargandoPlanta,
  HitoEntrega.salioPlanta,
  HitoEntrega.enCamino,
  HitoEntrega.proximoLlegar,
  HitoEntrega.enObra,
  HitoEntrega.descargando,
  HitoEntrega.entregado,
];

const _accentYellow = AppColors.accent;

/// `GET /remisiones/{id}/firma` can come back with more than one record
/// despite the backend supposedly rejecting a second firma (e.g. leftover
/// seed/test data alongside a real one) — pick whichever has the latest
/// `fechaHoraFirma` rather than blindly trusting array order.
FirmaResponse? _firmaMasReciente(List<FirmaResponse>? firmas) {
  if (firmas == null || firmas.isEmpty) return null;
  return firmas.reduce((a, b) {
    final fechaA = DateTime.tryParse(a.fechaHoraFirma ?? '');
    final fechaB = DateTime.tryParse(b.fechaHoraFirma ?? '');
    if (fechaA == null) return b;
    if (fechaB == null) return a;
    return fechaB.isAfter(fechaA) ? b : a;
  });
}

/// Detail view for a single Remisión: summary, the real 7-step hito stepper
/// (fetched/advanced via `OperacionesService`, only when a Remisión already
/// exists) and entry points to firma digital / foto de evidencia (still
/// mock — see `vistas.md`) plus, for Operador de Bomba, dosificación and
/// prueba de concreto fresco.
class DeliveryDetailScreen extends StatefulWidget {
  final Remision remision;

  const DeliveryDetailScreen({super.key, required this.remision});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  /// Null when there's no real Remisión yet (nothing to fetch/operate on).
  Future<RemisionResumen?>? _detalleFuture;
  RemisionResumen? _detalleOverride;
  bool _avanzando = false;

  /// Whether the remisión has been firmada — `RemisionResponse` has no
  /// boolean flag for it, so this is derived from whether `GET
  /// /remisiones/{id}/firma` comes back non-empty.
  Future<List<FirmaResponse>>? _firmasFuture;

  /// How many fotos/evidencia are already attached (`GET
  /// /remisiones/{id}/archivos`) — same "no boolean flag, derive from the
  /// list" situation as firmas.
  Future<List<ArchivoResponse>>? _archivosFuture;

  @override
  void initState() {
    super.initState();
    final remisionId = widget.remision.remisionId;
    if (remisionId != null) {
      _detalleFuture = OperacionesService.remisionDetalle(remisionId);
      _firmasFuture = OperacionesService.firmasPorRemision(remisionId);
      _archivosFuture = OperacionesService.archivosPorRemision(remisionId);
    }
  }

  void _refrescarFirmas() {
    final remisionId = widget.remision.remisionId;
    if (remisionId == null || !mounted) return;
    setState(() {
      _firmasFuture = OperacionesService.firmasPorRemision(remisionId);
    });
  }

  void _refrescarArchivos() {
    final remisionId = widget.remision.remisionId;
    if (remisionId == null || !mounted) return;
    setState(() {
      _archivosFuture = OperacionesService.archivosPorRemision(remisionId);
    });
  }

  /// Re-fetches after returning from `RouteNavigationScreen` — that screen
  /// registers `salioPlanta`/`enObra` on its own (guidance start / SDK
  /// arrival geofence), so the status this screen is showing is stale by
  /// the time the driver comes back to it.
  void _refrescarDetalle() {
    final remisionId = widget.remision.remisionId;
    if (remisionId == null || !mounted) return;
    setState(() {
      _detalleOverride = null;
      _detalleFuture = OperacionesService.remisionDetalle(remisionId);
    });
  }

  /// Whether the remisión has genuinely reached [objetivo] or a later step
  /// in [_secuenciaHitos]. A blank/unrecognized `estatus` (nothing
  /// registered yet, or `con_atraso`/`con_incidencia`) never counts as
  /// having reached it — only a confirmed, recognized hito does.
  bool _hitoAlcanzado(RemisionResumen? detalle, HitoEntrega objetivo) {
    if (detalle == null) return false;
    final current = HitoEntrega.fromBackendValue(detalle.estatus);
    if (current == null) return false;
    return _secuenciaHitos.indexOf(current) >= _secuenciaHitos.indexOf(objetivo);
  }

  /// True once the remisión has genuinely reached "en obra" or later
  /// (descargando/entregado) — at that point re-starting turn-by-turn
  /// navigation to a destination already reached doesn't make sense, so
  /// "Iniciar ruta" hides.
  bool _yaLlegoAObra(RemisionResumen? detalle) => _hitoAlcanzado(detalle, HitoEntrega.enObra);

  /// "Iniciar ruta" only makes sense once the truck is actually being
  /// loaded — while the pedido is merely "programado" there's no `horaCarga`
  /// yet, so there's nothing to navigate to/from. Gating on `horaCarga`
  /// directly (rather than the derived hito) matches what "cargando en
  /// planta" actually means on the backend, since a blank `estatus` also
  /// resolves to `cargandoPlanta` (see `HitoEntrega.fromBackendValue`) even
  /// before `horaCarga` is set.
  bool _puedeIniciarRuta(RemisionResumen? detalle) =>
      detalle != null && detalle.horaCarga != null && !_yaLlegoAObra(detalle);

  Future<void> _avanzarHito(HitoEntrega next) async {
    final remisionId = widget.remision.remisionId;
    if (remisionId == null || _avanzando) return;
    setState(() => _avanzando = true);
    try {
      final detalle = await OperacionesService.avanzarHito(
        remisionId,
        next.backendValue,
      );
      if (mounted) setState(() => _detalleOverride = detalle);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } finally {
      if (mounted) setState(() => _avanzando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remision = widget.remision;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.55,
    );
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.12);
    final puedeOperar = AuthService.permisos.contains(permisoOperarRemisiones);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<RemisionResumen?>(
          future: _detalleFuture,
          builder: (context, snapshot) {
            final detalle = _detalleOverride ?? snapshot.data;
            if (detalle == null || detalle.folioRemision.isEmpty) {
              return Text(
                remision.folio,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              );
            }
            // Pedido folio (what EntregasService built the list from) next
            // to the real folioRemision (only known once the Remisión
            // detail loads) — same "Programado" vs. real-data distinction
            // as the rest of this screen.
            return Text(
              '${remision.folio} · ${detalle.folioRemision}',
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ScrollConfiguration(
          // This screen loads its sections (detalle/firma/evidencia) from
          // three independent Futures that resolve at different times,
          // each capable of changing the list's total content height right
          // as it's loading. If that happens right as the user reverses
          // scroll direction near the end, the platform's overscroll
          // effect (elastic bounce on iOS, the stretch effect on Android)
          // fights the changing extent and produces a visible spring/
          // wobble correction. Disabling it entirely removes that.
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              FutureBuilder<RemisionResumen?>(
                future: _detalleFuture,
                builder: (context, snapshot) {
                  final detalle = _detalleOverride ?? snapshot.data;
                  return SummaryCard(
                    remision: remision,
                    folioRemision: detalle?.folioRemision,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  );
                },
              ),
              if (remision.contactoNombre != null && remision.contactoNombre!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ContactoCard(
                  nombre: remision.contactoNombre!,
                  cargo: remision.contactoCargo,
                  telefono: remision.telefono,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
              const SizedBox(height: 24),
              FutureBuilder<RemisionResumen?>(
                future: _detalleFuture,
                builder: (context, snapshot) {
                  final detalle = _detalleOverride ?? snapshot.data;
                  if (!_puedeIniciarRuta(detalle)) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ubicación y ruta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) => RouteNavigationScreen(
                                      remision: remision,
                                    ),
                                  ),
                                )
                                .then((_) => _refrescarDetalle());
                          },
                          icon: const Icon(
                            Icons.navigation,
                            color: Colors.black,
                          ),
                          label: const Text(
                            'Iniciar ruta',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentYellow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (remision.remisionId != null && puedeOperar) ...[
                const SizedBox(height: 28),
                Text(
                  'Avanzar hito de entrega',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),
                FutureBuilder<RemisionResumen?>(
                  future: _detalleFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return Text(
                        error is AuthException
                            ? error.message
                            : 'No se pudo cargar el estatus de la remisión',
                        style: TextStyle(color: mutedColor),
                      );
                    }

                    final detalle = _detalleOverride ?? snapshot.data;
                    if (detalle == null) return const SizedBox.shrink();

                    final horarios = <(String, DateTime?)>[
                      ('Cargó en planta', detalle.horaCarga),
                      ('Salida de planta', detalle.horaSalida),
                      ('Llegada a obra', detalle.horaLlegadaObra),
                      ('Entrega', detalle.horaEntrega),
                    ].where((h) => h.$2 != null).toList();

                    // A blank estatus resolves to `cargandoPlanta` (see
                    // `HitoEntrega.fromBackendValue`) — null here only means
                    // a genuinely unrecognized status (`con_atraso`, etc).
                    final current = HitoEntrega.fromBackendValue(
                      detalle.estatus,
                    );
                    if (current == null) {
                      debugPrint(
                        'DeliveryDetailScreen: unrecognized estatus="${detalle.estatus}"',
                      );
                      // con_atraso / con_incidencia / anything else unrecognized:
                      // no known "next" step, so show the raw status instead of
                      // a stepper we can't meaningfully advance.
                      return Column(
                        children: [
                          if (horarios.isNotEmpty) ...[
                            HorariosCard(
                              horarios: horarios,
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              mutedColor: mutedColor,
                            ),
                            const SizedBox(height: 12),
                          ],
                          FieldGroup(
                            cardColor: cardColor,
                            borderColor: borderColor,
                            padding: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                detalle.estatus,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final isFinal = current == HitoEntrega.entregado;
                    final currentIndex = _secuenciaHitos.indexOf(current);

                    return Column(
                      children: [
                        if (horarios.isNotEmpty) ...[
                          HorariosCard(
                            horarios: horarios,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            mutedColor: mutedColor,
                          ),
                          const SizedBox(height: 12),
                        ],
                        FieldGroup(
                          cardColor: cardColor,
                          borderColor: borderColor,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final hito in _secuenciaHitos)
                                HitoRow(
                                  hito: hito,
                                  current: current,
                                  isLast: hito == _secuenciaHitos.last,
                                  textColor: textColor,
                                  mutedColor: mutedColor,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isFinal || _avanzando
                                ? null
                                : () => _avanzarHito(
                                    _secuenciaHitos[currentIndex + 1],
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentYellow,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: _accentYellow.withValues(
                                alpha: 0.3,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _avanzando
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    isFinal
                                        ? 'Entrega finalizada'
                                        : 'Avanzar a "${_secuenciaHitos[currentIndex + 1].label}"',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'Evidencia de entrega',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              FieldGroup(
                cardColor: cardColor,
                borderColor: borderColor,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    FutureBuilder<RemisionResumen?>(
                      future: _detalleFuture,
                      builder: (context, snapshot) {
                        final detalle = _detalleOverride ?? snapshot.data;
                        // Without a Remisión or the permission to operate on
                        // it, these rows have nothing to do at all, so they
                        // stay hidden. Once that's satisfied, they stay
                        // visible but disabled until the truck has actually
                        // started unloading at the obra — showing them
                        // enabled earlier would let a driver sign off on a
                        // delivery that hasn't happened yet.
                        if (remision.remisionId == null || !puedeOperar) {
                          return const SizedBox.shrink();
                        }
                        final habilitado = _hitoAlcanzado(detalle, HitoEntrega.descargando);
                        return Column(
                          children: [
                            FutureBuilder<List<FirmaResponse>>(
                              future: _firmasFuture,
                              builder: (context, snapshot) {
                                final firma = _firmaMasReciente(snapshot.data);
                                return ActionRow(
                                  icon: Icons.draw_outlined,
                                  label: 'Firma digital de entrega',
                                  textColor: textColor,
                                  mutedColor: mutedColor,
                                  enabled: habilitado,
                                  statusLabel: firma != null ? 'Firmada' : null,
                                  statusColor: firma != null
                                      ? AppColors.success
                                      : null,
                                  onTap: () async {
                                    // Backend blocks re-firmar (409) since it
                                    // would double-count entregado volume on
                                    // the pedido — once firmada, tapping
                                    // views the firma instead of reopening
                                    // SignatureScreen.
                                    if (firma != null) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => EvidenciaViewerScreen(
                                            url: firma.firmaDigitalUrl,
                                            label: 'Firma digital',
                                          ),
                                          fullscreenDialog: true,
                                        ),
                                      );
                                      return;
                                    }
                                    final firmada = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (context) => SignatureScreen(
                                              remisionId: remision.remisionId!,
                                              remisionFolio: remision.folio,
                                            ),
                                          ),
                                        );
                                    if (firmada == true) _refrescarFirmas();
                                  },
                                );
                              },
                            ),
                            Divider(height: 1, color: borderColor),
                            FutureBuilder<List<ArchivoResponse>>(
                              future: _archivosFuture,
                              builder: (context, snapshot) {
                                // GET /remisiones/{id}/archivos returns every
                                // archivo attached to the remisión regardless
                                // of type — e.g. it can also include the
                                // remisión's own PDF waybill generated by
                                // planta/producción, which isn't a photo and
                                // has no real image to render. Only
                                // count/show what this screen itself uploads.
                                final archivos =
                                    (snapshot.data ?? const <ArchivoResponse>[])
                                        .where(
                                          (a) => a.tipoArchivo == 'foto_evidencia',
                                        )
                                        .toList();
                                return ActionRow(
                                  icon: Icons.photo_camera_outlined,
                                  label: 'Foto / evidencia de entrega',
                                  textColor: textColor,
                                  mutedColor: mutedColor,
                                  enabled: habilitado,
                                  statusLabel: archivos.isNotEmpty
                                      ? (archivos.length == 1
                                            ? '1 foto'
                                            : '${archivos.length} fotos')
                                      : null,
                                  statusColor: archivos.isNotEmpty
                                      ? AppColors.success
                                      : null,
                                  onTap: () async {
                                    // Once evidencia exists, this row is
                                    // view-only — mirrors the firma pattern
                                    // (tapping views instead of reopening the
                                    // capture screen), since the backend has
                                    // no concept of "replacing" a saved photo.
                                    if (archivos.isNotEmpty) {
                                      if (archivos.length == 1) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EvidenciaViewerScreen(
                                                  url: archivos.first
                                                      .archivoUrl,
                                                  label: 'Evidencia de entrega',
                                                ),
                                            fullscreenDialog: true,
                                          ),
                                        );
                                      } else {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EvidenciaFotosScreen(
                                                  remisionFolio: remision.folio,
                                                  archivos: archivos,
                                                ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    final guardado = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                DeliveryPhotoScreen(
                                                  remisionId:
                                                      remision.remisionId!,
                                                  remisionFolio: remision.folio,
                                                ),
                                          ),
                                        );
                                    if (guardado == true) _refrescarArchivos();
                                  },
                                );
                              },
                            ),
                            Divider(height: 1, color: borderColor),
                          ],
                        );
                      },
                    ),
                    if (AuthService.rol == 'Operador de Bomba') ...[
                      Divider(height: 1, color: borderColor),
                      ActionRow(
                        icon: Icons.water_drop_outlined,
                        label: 'Reporte de dosificación',
                        textColor: textColor,
                        mutedColor: mutedColor,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => DosificacionScreen(
                                remisionFolio: remision.folio,
                              ),
                            ),
                          );
                        },
                      ),
                      if (remision.remisionId != null && puedeOperar) ...[
                        Divider(height: 1, color: borderColor),
                        ActionRow(
                          icon: Icons.science_outlined,
                          label: 'Prueba de concreto fresco',
                          textColor: textColor,
                          mutedColor: mutedColor,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    PruebaConcretoScreen(remision: remision),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
