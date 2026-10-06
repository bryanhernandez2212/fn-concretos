import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/field_group.dart';
import '../jefe_planta_mock.dart';
import '../jefe_planta_widgets.dart';
import 'solicitudes_widgets.dart';

/// Read-only detail of one solicitud de compra plus its bitácora
/// (`GET /solicitudes-compra/{id}/bitacora`). The jefe de planta only
/// raises solicitudes; authorizing/rejecting happens elsewhere.
class SolicitudDetailScreen extends StatefulWidget {
  final SolicitudCompra solicitud;

  const SolicitudDetailScreen({super.key, required this.solicitud});

  @override
  State<SolicitudDetailScreen> createState() => _SolicitudDetailScreenState();
}

class _SolicitudDetailScreenState extends State<SolicitudDetailScreen> {
  late Future<List<BitacoraSolicitud>> _bitacora;

  @override
  void initState() {
    super.initState();
    _bitacora = JefePlantaMock.bitacora(widget.solicitud);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final planta = JefePlantaMock.planta(s.plantaId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitud SC-${s.id}'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const DatosEjemploBanner(),
          const SizedBox(height: 16),
          FieldGroup(
            expand: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconoArea(s.area), size: 18, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(
                      s.area,
                      style: TextStyle(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    EstatusPill(
                      label: etiquetaEstatusSolicitud(s.estatus),
                      color: colorEstatusSolicitud(s.estatus),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  s.concepto,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                if (s.montoEstimado != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    monedaJp.format(s.montoEstimado),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Monto estimado',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FieldGroup(
            expand: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivo',
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
                const SizedBox(height: 6),
                Text(
                  s.motivo,
                  style: TextStyle(fontSize: 14.5, color: textColor),
                ),
                const Divider(height: 24),
                DatoRow(
                  label: 'Planta',
                  value: planta?.nombre ?? '#${s.plantaId}',
                ),
                if (s.vehiculoId != null)
                  DatoRow(label: 'Vehículo', value: '#${s.vehiculoId}'),
                DatoRow(label: 'Creada', value: fechaCortaJp(s.createdAt)),
                DatoRow(
                  label: 'Solicitante',
                  value: s.creadoPorUsuario ?? '#${s.solicitanteId}',
                ),
                DatoRow(
                  label: 'Cotización adjunta',
                  value: s.cotizacionAdjuntaUrl != null ? 'Sí' : 'No',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bitácora',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<BitacoraSolicitud>>(
            future: _bitacora,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const JefePlantaCargando();
              }
              if (snapshot.hasError || snapshot.data!.isEmpty) {
                return const JefePlantaMensaje(
                  icon: Icons.history,
                  mensaje: 'Sin movimientos registrados',
                );
              }
              return FieldGroup(
                expand: true,
                child: BitacoraTimeline(pasos: snapshot.data!),
              );
            },
          ),
        ],
      ),
    );
  }
}
