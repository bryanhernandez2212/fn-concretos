import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/field_group.dart';
import 'asesor_comercial_service.dart';
import 'visita.dart';
import 'visita_checkin_screen.dart';

/// Schedules a new Visita (`POST /visitas`) for [clienteId]/[obraId] —
/// reached right after `ObraFormScreen` registers a new obra, since the
/// advisor's next step is usually to log the visita they're already
/// standing at that site for. Pops with `true` once created, or `false`/
/// `null` if the advisor backs out without creating one (registering the
/// obra alone is still a complete, valid action on its own).
///
/// `POST /visitas` only *asigna* the visita (estatus `asignada`) — it's not
/// proof anyone was actually there, that's what `POST /visitas/{id}/checkin`
/// (geolocated) is for. This screen makes that an explicit up-front choice
/// rather than inferring it from the picked date: "Visita al instante" (the
/// advisor is standing there right now — fecha locked to today, chains
/// straight into `VisitaCheckinScreen` after creating) vs. "Programar
/// visita" (a future date, no check-in yet — there's nothing to geolocate
/// for a visit that hasn't happened).
class VisitaFormScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;
  final int obraId;
  final String obraNombre;

  const VisitaFormScreen({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
    required this.obraId,
    required this.obraNombre,
  });

  @override
  State<VisitaFormScreen> createState() => _VisitaFormScreenState();
}

class _VisitaFormScreenState extends State<VisitaFormScreen> {
  final _contactoNombreController = TextEditingController();
  final _contactoTelefonoController = TextEditingController();
  final _volumenController = TextEditingController();
  late DateTime _fecha;
  bool _instantanea = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _fecha = DateTime.now();
  }

  void _elegirModo(bool instantanea) {
    setState(() {
      _instantanea = instantanea;
      final hoy = DateTime.now();
      if (instantanea) {
        _fecha = hoy;
      } else if (_fecha.year == hoy.year && _fecha.month == hoy.month && _fecha.day == hoy.day) {
        _fecha = hoy.add(const Duration(days: 1));
      }
    });
  }

  @override
  void dispose() {
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    _volumenController.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: hoy.subtract(const Duration(days: 7)),
      lastDate: hoy.add(const Duration(days: 90)),
      locale: const Locale('es'),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(colorScheme: base.colorScheme.copyWith(primary: AppColors.accent, onPrimary: Colors.black)),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _submit() async {
    setState(() => _enviando = true);
    try {
      final asesor = await AsesorComercialService.miAsesor();
      if (asesor == null) {
        throw AuthException('No se encontró un asesor comercial vinculado a esta cuenta');
      }
      final visita = await AsesorComercialService.crearVisita(
        asesorId: asesor.id,
        obraId: widget.obraId,
        clienteId: widget.clienteId,
        fechaVisita: _fecha,
        contactoNombre: _contactoNombreController.text.trim(),
        contactoTelefono: _contactoTelefonoController.text.trim(),
        volumenAproximado: double.tryParse(_volumenController.text.trim()),
      );
      if (!mounted) return;
      AppSnack.success(context, 'Visita registrada');

      if (_instantanea) {
        await Navigator.of(context).push<Visita>(
          MaterialPageRoute(builder: (context) => VisitaCheckinScreen(visita: visita)),
        );
        if (!mounted) return;
      }
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'No se pudo registrar la visita');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  InputDecoration _decoration(String hint, Color mutedColor, Color fillColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: mutedColor),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final cardColor = AppColors.card(context);
    final borderColor = AppColors.border(context, alpha: 0.10);
    final fillColor = AppColors.border(context, alpha: 0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar visita'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
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
                Text(widget.obraNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text(widget.clienteNombre, style: TextStyle(fontSize: 13, color: mutedColor)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Visita al instante'),
                  selected: _instantanea,
                  onSelected: (_) => _elegirModo(true),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: _instantanea ? Colors.black : textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: fillColor,
                  side: BorderSide.none,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Programar visita'),
                  selected: !_instantanea,
                  onSelected: (_) => _elegirModo(false),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: !_instantanea ? Colors.black : textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: fillColor,
                  side: BorderSide.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _instantanea ? null : _pickFecha,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: mutedColor),
                  const SizedBox(width: 12),
                  Text(
                    _instantanea ? 'Hoy, ${DateFormat('d/MM/y').format(_fecha)}' : DateFormat('d/MM/y').format(_fecha),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  if (!_instantanea) ...[
                    const Spacer(),
                    Icon(Icons.expand_more, color: mutedColor),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactoNombreController,
            style: TextStyle(color: textColor),
            decoration: _decoration('Nombre de contacto en obra (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactoTelefonoController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: textColor),
            decoration: _decoration('Teléfono de contacto (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _volumenController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor),
            decoration: _decoration('Volumen aproximado en m³ (opcional)', mutedColor, fillColor),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : Text(
                      _instantanea ? 'Registrar visita y check-in' : 'Programar visita',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
