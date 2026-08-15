import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../operaciones/operaciones_service.dart';
import '../operaciones/remision_tracking.dart';
import 'delivery_photo_screen.dart';
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

const _accentYellow = Color(0xFFFFCC00);

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

  @override
  void initState() {
    super.initState();
    final remisionId = widget.remision.remisionId;
    if (remisionId != null) {
      _detalleFuture = OperacionesService.remisionDetalle(remisionId);
    }
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

  /// True once the remisión has genuinely reached "en obra" or later
  /// (descargando/entregado) — at that point re-starting turn-by-turn
  /// navigation to a destination already reached doesn't make sense, so
  /// "Iniciar ruta" hides. A blank/unrecognized `estatus` (nothing
  /// registered yet, or `con_atraso`/`con_incidencia`) never hides it —
  /// only a confirmed arrival does.
  bool _yaLlegoAObra(RemisionResumen? detalle) {
    if (detalle == null) return false;
    final current = HitoEntrega.fromBackendValue(detalle.estatus);
    if (current == null) return false;
    return _secuenciaHitos.indexOf(current) >=
        _secuenciaHitos.indexOf(HitoEntrega.enObra);
  }

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
              return Text(remision.folio);
            }
            // Pedido folio (what EntregasService built the list from) next
            // to the real folioRemision (only known once the Remisión
            // detail loads) — same "Programado" vs. real-data distinction
            // as the rest of this screen.
            return Text('${remision.folio} · ${detalle.folioRemision}');
          },
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _accentYellow,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _SummaryCard(
              remision: remision,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
            const SizedBox(height: 24),
            FutureBuilder<RemisionResumen?>(
              future: _detalleFuture,
              builder: (context, snapshot) {
                final detalle = _detalleOverride ?? snapshot.data;
                if (_yaLlegoAObra(detalle)) return const SizedBox.shrink();

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
                                  builder: (context) =>
                                      RouteNavigationScreen(remision: remision),
                                ),
                              )
                              .then((_) => _refrescarDetalle());
                        },
                        icon: const Icon(Icons.navigation, color: Colors.black),
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
                    ('Carga en planta', detalle.horaCarga),
                    ('Salida de planta', detalle.horaSalida),
                    ('Llegada a obra', detalle.horaLlegadaObra),
                    ('Entrega', detalle.horaEntrega),
                  ].where((h) => h.$2 != null).toList();

                  // A blank estatus means the remisión exists (it has an id,
                  // maybe even horaCarga) but no hito has ever been PATCHed
                  // yet — treat that as "before the first step", not as an
                  // unrecognized status, so the driver can still advance from
                  // the beginning instead of seeing a dead end.
                  final sinIniciar = detalle.estatus.isEmpty;
                  final current = sinIniciar
                      ? null
                      : HitoEntrega.fromBackendValue(detalle.estatus);
                  if (!sinIniciar && current == null) {
                    debugPrint(
                      'DeliveryDetailScreen: unrecognized estatus="${detalle.estatus}"',
                    );
                    // con_atraso / con_incidencia / anything else unrecognized:
                    // no known "next" step, so show the raw status instead of
                    // a stepper we can't meaningfully advance.
                    return Column(
                      children: [
                        if (horarios.isNotEmpty) ...[
                          _HorariosCard(
                            horarios: horarios,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            mutedColor: mutedColor,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _FieldGroup(
                          cardColor: cardColor,
                          borderColor: borderColor,
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
                  final currentIndex = sinIniciar
                      ? -1
                      : _secuenciaHitos.indexOf(current!);

                  return Column(
                    children: [
                      if (horarios.isNotEmpty) ...[
                        _HorariosCard(
                          horarios: horarios,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textColor: textColor,
                          mutedColor: mutedColor,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _FieldGroup(
                        cardColor: cardColor,
                        borderColor: borderColor,
                        child: Column(
                          children: [
                            for (final hito in _secuenciaHitos)
                              _HitoRow(
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
            _FieldGroup(
              cardColor: cardColor,
              borderColor: borderColor,
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.draw_outlined,
                    label: 'Firma digital de entrega',
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SignatureScreen(remisionFolio: remision.folio),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: borderColor),
                  _ActionRow(
                    icon: Icons.photo_camera_outlined,
                    label: 'Foto / evidencia de entrega',
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DeliveryPhotoScreen(
                            remisionFolio: remision.folio,
                          ),
                        ),
                      );
                    },
                  ),
                  if (AuthService.rol == 'Operador de Bomba') ...[
                    Divider(height: 1, color: borderColor),
                    _ActionRow(
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
                      _ActionRow(
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
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Remision remision;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _SummaryCard({
    required this.remision,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            remision.obra,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            remision.cliente,
            style: TextStyle(fontSize: 13.5, color: mutedColor),
          ),
          const SizedBox(height: 14),
          _DetailLine(
            icon: Icons.location_on_outlined,
            text: remision.direccion,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.access_time,
            text: 'Programada: ${remision.horaProgramada}',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.grain,
            text: '${remision.tipoConcreto} · ${remision.volumenM3} m³',
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color mutedColor;

  const _DetailLine({
    required this.icon,
    required this.text,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13.5, color: textColor)),
        ),
      ],
    );
  }
}

/// Rounded card wrapper matching the style used across the rest of the app.
/// Real hito timestamps stamped by the backend (`RemisionResumen.hora*`) —
/// only the ones that already happened are passed in, so this only ever
/// renders entries with a non-null `DateTime`.
class _HorariosCard extends StatelessWidget {
  final List<(String, DateTime?)> horarios;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;

  const _HorariosCard({
    required this.horarios,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
  });

  static String _formatHora(DateTime hora) {
    final local = hora.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return _FieldGroup(
      cardColor: cardColor,
      borderColor: borderColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, entry) in horarios.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.$1,
                      style: TextStyle(fontSize: 13.5, color: mutedColor),
                    ),
                  ),
                  Text(
                    _formatHora(entry.$2!),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Widget child;

  const _FieldGroup({
    required this.cardColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// One row of the hito stepper: a filled/checked circle for done steps, a
/// highlighted circle for the current one, an outlined circle for what's
/// ahead, connected by a vertical line.
class _HitoRow extends StatelessWidget {
  final HitoEntrega hito;

  /// Null means nothing has been registered yet (a blank `estatus`) — every
  /// row renders as pending, none done/current.
  final HitoEntrega? current;
  final bool isLast;
  final Color textColor;
  final Color mutedColor;

  const _HitoRow({
    required this.hito,
    required this.current,
    required this.isLast,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final isDone = current != null && hito.index < current.index;
    final isCurrent = current != null && hito.index == current.index;
    final circleColor = isDone
        ? const Color(0xFF4CAF50)
        : isCurrent
        ? _accentYellow
        : mutedColor.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isCurrent ? circleColor : Colors.transparent,
                  border: Border.all(color: circleColor, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  color: mutedColor.withValues(alpha: 0.2),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hito.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent || isDone ? textColor : mutedColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _accentYellow),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
