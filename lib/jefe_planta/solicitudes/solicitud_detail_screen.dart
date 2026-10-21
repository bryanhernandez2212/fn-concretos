import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/field_group.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/app_feedback.dart';
import '../jefe_planta_service.dart';
import '../jefe_planta_widgets.dart';
import '../../auth/auth_service.dart';
import 'generar_oc_screen.dart';
import 'solicitudes_widgets.dart';

/// Read-only detail of one solicitud de compra plus its bitácora
/// (`GET /solicitudes-compra/{id}/bitacora`). The jefe de planta only
/// raises solicitudes; Dirección authorizes or rejects them on the web. Once
/// autorizada, "Generar OC" (needs `ordenes_compra.crear`) is the next step,
/// as on the web. Pops `true` when an OC was generated.
class SolicitudDetailScreen extends StatefulWidget {
  final SolicitudCompra solicitud;

  const SolicitudDetailScreen({super.key, required this.solicitud});

  @override
  State<SolicitudDetailScreen> createState() => _SolicitudDetailScreenState();
}

class _SolicitudDetailScreenState extends State<SolicitudDetailScreen> {
  late Future<List<BitacoraSolicitud>> _bitacora;
  ContextoPlanta? _contexto;

  @override
  void initState() {
    super.initState();
    _bitacora = JefePlantaService.bitacora(widget.solicitud.id);
    JefePlantaService.contexto().then((c) {
      if (mounted) setState(() => _contexto = c);
    });
  }

  Future<void> _generarOc() async {
    final oc = await Navigator.of(context).push<OrdenCompraGenerada>(
      MaterialPageRoute(
        builder: (context) => GenerarOcScreen(solicitud: widget.solicitud),
      ),
    );
    if (oc == null || !mounted) return;
    if (oc.avisoEnvio != null) {
      AppSnack.info(context, oc.avisoEnvio!);
    } else {
      AppSnack.success(
        context,
        '${oc.folio} generada y enviada a autorización',
      );
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _abrirCotizacion(String url) async {
    final uri = Uri.tryParse(url);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) AppSnack.error(context, 'No se pudo abrir el archivo');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

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
                      s.area ?? 'Sin área',
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
                if (s.motivo != null) ...[
                  Text(
                    'Motivo',
                    style: TextStyle(fontSize: 13, color: mutedColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.motivo!,
                    style: TextStyle(fontSize: 14.5, color: textColor),
                  ),
                  const Divider(height: 24),
                ],
                DatoRow(
                  label: 'Planta',
                  value:
                      _contexto?.nombrePlanta(s.plantaId) ??
                      (s.plantaId == null ? 'Sin planta' : '#${s.plantaId}'),
                ),
                if (s.vehiculoId != null)
                  DatoRow(label: 'Vehículo', value: '#${s.vehiculoId}'),
                if (s.createdAt != null)
                  DatoRow(
                    label: 'Creada',
                    value: fechaHoraJp(s.createdAt!.toLocal()),
                  ),
                DatoRow(
                  label: 'Solicitante',
                  value:
                      s.creadoPorUsuario ??
                      (s.solicitanteId == null
                          ? 'Sin especificar'
                          : '#${s.solicitanteId}'),
                ),
                if (s.ordenCompraFolio != null)
                  DatoRow(label: 'Orden de compra', value: s.ordenCompraFolio!),
                if (s.cotizacionAdjuntaUrl == null)
                  const DatoRow(label: 'Cotización adjunta', value: 'No'),
                if (s.cotizacionAdjuntaUrl != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _abrirCotizacion(s.cotizacionAdjuntaUrl!),
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Ver cotización adjunta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                          color: AppColors.border(context, alpha: 0.15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (s.estatus == estatusSolicitudAutorizada &&
              AuthService.permisos.contains(permisoCrearOrdenCompra)) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generarOc,
                style: botonPrimarioJp(),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text(
                  'Generar OC',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
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
              if (snapshot.hasError) {
                return const JefePlantaMensaje(
                  icon: Icons.history,
                  mensaje: 'No se pudo cargar la bitácora',
                );
              }
              if (snapshot.data!.isEmpty) {
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
