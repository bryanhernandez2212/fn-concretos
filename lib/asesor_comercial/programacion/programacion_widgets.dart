import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../operaciones/produccion.dart';
import '../../operaciones/remision_tracking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/field_group.dart';
import '../../widgets/info_pill.dart';
import '../pedidos/pedidos_widgets.dart';
import 'seguimiento_mapa_screen.dart' show remisionEnRuta;

Color programacionTono(String estatus) => switch (estatus) {
  'cancelada' => AppColors.error,
  'aprobado' => AppColors.success,
  'programado' => AppColors.accent,
  _ => AppColors.warning, // previa
};

/// One previa/programación row with the pedido or cotización it belongs to.
class ProgramacionAsesorCard extends StatelessWidget {
  final ProgramacionFila fila;

  /// "PED-…" / "COT-…" — whichever the row is tied to.
  final String folio;
  final bool esPedido;
  final String? cliente;
  final String? obra;
  final double? volumenM3;

  /// The pedido's remisiones, for the "where is my pedido" tracker. Null
  /// hides it (not loaded yet, failed, or the row isn't programado).
  final List<RemisionResumen>? remisiones;

  /// Opens the live map. Only offered while a remisión is on the road.
  final VoidCallback? onVerMapa;
  final VoidCallback? onTap;

  const ProgramacionAsesorCard({
    super.key,
    required this.fila,
    required this.folio,
    required this.esPedido,
    this.cliente,
    this.obra,
    this.volumenM3,
    this.remisiones,
    this.onVerMapa,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: FieldGroup(
        cardColor: AppColors.card(context),
        borderColor: AppColors.border(context, alpha: 0.08),
        expand: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    folio,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
                  ),
                ),
                EstatusBadge(label: estatusTexto(fila.estatus), color: programacionTono(fila.estatus)),
              ],
            ),
            if (cliente != null && cliente!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                cliente!,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
            if (obra != null && obra!.isNotEmpty)
              Text(obra!, style: TextStyle(fontSize: 13, color: mutedColor)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoPill(
                  icon: Icons.event_outlined,
                  text: fechaCorta(fila.fechaProgramada),
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
                if (fila.horaArranque != null)
                  InfoPill(
                    icon: Icons.schedule,
                    text: fila.horaArranque!,
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                if (volumenM3 != null)
                  InfoPill(
                    icon: Icons.water_drop_outlined,
                    text: '$volumenM3 m³',
                    mutedColor: mutedColor,
                    textColor: textColor,
                  ),
                InfoPill(
                  icon: esPedido ? Icons.assignment_outlined : Icons.receipt_long_outlined,
                  text: esPedido ? 'Pedido' : 'Cotización',
                  mutedColor: mutedColor,
                  textColor: textColor,
                ),
              ],
            ),
            if (remisiones != null) ...[
              const Divider(height: 24),
              ProgresoPedido(remisiones: remisiones!, volumenM3: volumenM3),
              if (onVerMapa != null && remisiones!.any(remisionEnRuta)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onVerMapa,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Ver en el mapa en vivo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Stages of the tracker, in order. A remisión maps onto one of them.
const _etapas = ['Programado', 'Cargando', 'En camino', 'En obra', 'Entregado'];

/// Which of [_etapas] a remisión is at (index).
int etapaRemision(RemisionResumen r) {
  switch (r.estatus) {
    case 'entregado':
      return 4;
    case 'en_obra':
    case 'descargando':
      return 3;
    case 'salio_planta':
    case 'en_camino':
    case 'proximo_llegar':
    case 'con_atraso':
      return 2;
  }
  // cargando_planta / programado / blank / con_incidencia. A solo-bomba
  // remisión never loads at planta, so unstarted means nothing happened.
  return r.esSoloBomba && (r.estatus.isEmpty || r.estatus == 'programado' || r.estatus == 'cargando_planta') ? 0 : 1;
}

/// "Where is my pedido" tracker, like a ride-hailing app: a step line per
/// remisión still on the move, plus how many trips are already delivered.
/// With no remisión yet, the pedido is simply programado.
class ProgresoPedido extends StatelessWidget {
  final List<RemisionResumen> remisiones;
  final double? volumenM3;

  const ProgresoPedido({super.key, required this.remisiones, this.volumenM3});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final entregadas = remisiones.where((r) => r.estatus == 'entregado').toList();
    final activas = remisiones.where((r) => r.estatus != 'entregado').toList();

    final bloques = <Widget>[];
    if (remisiones.isEmpty) {
      bloques.add(_Linea(etapa: 0, detalle: 'Aún sin salida de planta', tono: null));
    } else if (activas.isEmpty) {
      bloques.add(_Linea(etapa: 4, detalle: _hora('Entregado', entregadas.last.horaEntrega), tono: null));
    } else {
      for (final r in activas) {
        if (bloques.isNotEmpty) bloques.add(const SizedBox(height: 14));
        final (detalle, tono) = _detalle(r);
        bloques.add(
          _Linea(
            etapa: etapaRemision(r),
            titulo: activas.length > 1 ? r.folioRemision : null,
            detalle: detalle,
            tono: tono,
          ),
        );
      }
    }

    // Summed from the (polled) remisiones rather than the pedido's volume,
    // which is only loaded once and would go stale next to the tracker.
    final entregadoM3 = entregadas.fold<double>(0, (suma, r) => suma + (r.volumen ?? 0));
    final resumen = [
      if (remisiones.length > 1) '${entregadas.length} de ${remisiones.length} viajes entregados',
      if (entregadoM3 > 0 && volumenM3 != null) '$entregadoM3 de $volumenM3 m³ entregados',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seguimiento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: mutedColor)),
        const SizedBox(height: 10),
        ...bloques,
        if (resumen.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(resumen, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
        ],
      ],
    );
  }

  static String _hora(String prefijo, DateTime? t) =>
      t == null ? prefijo : '$prefijo ${DateFormat('HH:mm').format(t.toLocal())}';

  /// Sub-label under the step line, and a tone when something needs a look.
  static (String, Color?) _detalle(RemisionResumen r) => switch (r.estatus) {
    'con_atraso' => (_hora('Con atraso · salió', r.horaSalida), AppColors.warning),
    'con_incidencia' => ('Con incidencia', AppColors.error),
    'proximo_llegar' => ('Próximo a llegar', null),
    'salio_planta' => (_hora('Salió de planta', r.horaSalida), null),
    'en_camino' => (_hora('En camino · salió', r.horaSalida), null),
    'en_obra' => (_hora('Llegó a la obra', r.horaLlegadaObra), null),
    'descargando' => ('Descargando en obra', null),
    _ => (etapaRemision(r) == 0 ? 'Aún sin iniciar' : 'Cargando en planta', null),
  };
}

class _Linea extends StatelessWidget {
  final int etapa;
  final String? titulo;
  final String detalle;
  final Color? tono;

  const _Linea({required this.etapa, this.titulo, required this.detalle, required this.tono});

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final hecho = AppColors.accent;
    final pendiente = AppColors.border(context, alpha: 0.25);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titulo != null) ...[
          Text(titulo!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            for (var i = 0; i < _etapas.length; i++) ...[
              if (i > 0) Expanded(child: Container(height: 3, color: i <= etapa ? hecho : pendiente)),
              Container(
                width: i == etapa ? 18 : 12,
                height: i == etapa ? 18 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= etapa ? hecho : pendiente,
                  border: i == etapa ? Border.all(color: hecho.withValues(alpha: 0.35), width: 4) : null,
                ),
                child: i < etapa ? const Icon(Icons.check, size: 9, color: AppColors.onAccent) : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _etapas[etapa],
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detalle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: tono ?? mutedColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Read-only "Previa y programación" block for the pedido/cotización
/// details. [filas] null means the lookup hasn't answered (or failed):
/// nothing is drawn. An empty list says no previa was added yet.
class ProgramacionResumenCard extends StatelessWidget {
  final List<ProgramacionFila>? filas;

  const ProgramacionResumenCard({super.key, required this.filas});

  @override
  Widget build(BuildContext context) {
    final lista = filas;
    if (lista == null) return const SizedBox.shrink();
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final ordenadas = [...lista]..sort((a, b) => (a.fechaProgramada ?? '').compareTo(b.fechaProgramada ?? ''));

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Previa y programación',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 8),
          FieldGroup(
            cardColor: AppColors.card(context),
            borderColor: AppColors.border(context, alpha: 0.10),
            expand: true,
            child: ordenadas.isEmpty
                ? Text('Aún no hay previa ni programación.', style: TextStyle(fontSize: 13, color: mutedColor))
                : Column(
                    children: [
                      for (var i = 0; i < ordenadas.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _fila(ordenadas[i], textColor, mutedColor),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fila(ProgramacionFila f, Color textColor, Color mutedColor) {
    final detalle = [
      if (f.horaArranque != null) 'Arranque ${f.horaArranque}',
      if (f.personalRequerido != null) '${f.personalRequerido} de personal',
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fechaCorta(f.fechaProgramada),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
              ),
              if (detalle.isNotEmpty) Text(detalle, style: TextStyle(fontSize: 12.5, color: mutedColor)),
            ],
          ),
        ),
        EstatusBadge(label: estatusTexto(f.estatus), color: programacionTono(f.estatus)),
      ],
    );
  }
}
