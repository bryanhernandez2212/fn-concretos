import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/contacto_card.dart';
import '../widgets/evidencia_viewer_screen.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_widgets.dart';
import 'cotizacion_form_screen.dart';
import 'solicitud_diseno_screen.dart';
import 'visita.dart';
import 'visita_checkin_screen.dart';

/// Detail for a single Visita. There's no `GET /visitas/{id}` in
/// `comercial-service`, so this screen works off the [Visita] passed in from
/// the list and the fresh copy [VisitaCheckinScreen] returns after check-in
/// — never re-fetches. Always pops with `true` so `VisitasScreen` refreshes
/// (cheap even when nothing changed).
class VisitaDetailScreen extends StatefulWidget {
  final Visita visita;

  const VisitaDetailScreen({super.key, required this.visita});

  @override
  State<VisitaDetailScreen> createState() => _VisitaDetailScreenState();
}

class _VisitaDetailScreenState extends State<VisitaDetailScreen> {
  late Visita _visita;

  @override
  void initState() {
    super.initState();
    _visita = widget.visita;
  }

  Future<void> _registrarCheckin() async {
    final actualizada = await Navigator.of(context).push<Visita>(
      MaterialPageRoute(builder: (context) => VisitaCheckinScreen(visita: _visita)),
    );
    if (actualizada != null) setState(() => _visita = actualizada);
  }

  void _solicitarDisenoEspecial() {
    final clienteId = _visita.clienteId;
    if (clienteId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SolicitudDisenoScreen(clienteId: clienteId, obraId: _visita.obraId),
      ),
    );
  }

  void _generarCotizacion() {
    final clienteId = _visita.clienteId;
    if (clienteId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CotizacionFormScreen(
          clienteId: clienteId,
          clienteNombre: _visita.clienteNombre ?? 'Cliente sin nombre',
          obraId: _visita.obraId,
          obraNombre: _visita.obraNombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visita'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          FieldGroup(
            cardColor: cardColor,
            borderColor: borderColor,
            expand: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _visita.obraNombre ?? 'Obra sin nombre',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
                      ),
                    ),
                    EstatusChip(estatus: _visita.estatus),
                  ],
                ),
                if (_visita.clienteNombre != null) ...[
                  const SizedBox(height: 6),
                  Text(_visita.clienteNombre!, style: TextStyle(fontSize: 13.5, color: mutedColor)),
                ],
                const SizedBox(height: 12),
                Text('Fecha: ${_visita.fechaVisita}', style: TextStyle(fontSize: 13, color: mutedColor)),
                if (_visita.horaCheckin != null)
                  Text('Check-in: ${_visita.horaCheckin}', style: TextStyle(fontSize: 13, color: mutedColor)),
                if (_visita.volumenAproximado != null)
                  Text('Volumen aproximado: ${_visita.volumenAproximado} m³', style: TextStyle(fontSize: 13, color: mutedColor)),
              ],
            ),
          ),
          if (_visita.contactoNombre != null) ...[
            const SizedBox(height: 16),
            ContactoCard(
              nombre: _visita.contactoNombre!,
              telefono: _visita.contactoTelefono,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ],
          if (_visita.fotoEvidenciaUrl != null) ...[
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EvidenciaViewerScreen(url: _visita.fotoEvidenciaUrl!, label: 'Evidencia de check-in'),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(_visita.fotoEvidenciaUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_visita.estatus == 'asignada')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _registrarCheckin,
                icon: const Icon(Icons.my_location),
                label: const Text('Registrar check-in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          if (_visita.estatus == 'visitada' && _visita.clienteId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generarCotizacion,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Generar cotización'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          if (_visita.clienteId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _solicitarDisenoEspecial,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Solicitar diseño especial'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
