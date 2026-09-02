import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../direccion/pedido.dart';
import '../theme/app_colors.dart';
import 'asesor_comercial_widgets.dart';
import 'obra_form_screen.dart';

/// Second step of Asesor Comercial's "registrar visita" flow (after
/// `ClientePickerScreen`) — picks an obra that's already in the system for a
/// repeat visit (`ComercialService.buscarObras`), or falls through to
/// `ObraFormScreen` for a brand-new one via "Registrar obra nueva". Since
/// `ObraFormScreen` already chains into `VisitaFormScreen` and pops the
/// whole stack itself once done, that path pops this screen with `null`
/// rather than an [Obra] — the caller only needs to push `VisitaFormScreen`
/// itself when an *existing* obra was picked here.
class ObraPickerScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;

  const ObraPickerScreen({super.key, required this.clienteId, required this.clienteNombre});

  @override
  State<ObraPickerScreen> createState() => _ObraPickerScreenState();
}

class _ObraPickerScreenState extends State<ObraPickerScreen> {
  final _queryController = TextEditingController();
  Future<List<Obra>>? _future;
  bool _buscoAlMenosUnaVez = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _buscoAlMenosUnaVez = true;
      _future = ComercialService.buscarObras(nombre: _queryController.text.trim());
    });
  }

  Future<void> _nuevaObra() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ObraFormScreen(clienteId: widget.clienteId, clienteNombre: widget.clienteNombre),
      ),
    );
    if (mounted) Navigator.of(context).pop();
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
        title: const Text('Elegir obra'),
        backgroundColor: AppColors.surfaceAlt(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _queryController,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                hintText: 'Buscar obra por nombre',
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
                prefixIcon: Icon(Icons.search, color: mutedColor),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _buscar),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _nuevaObra,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Registrar obra nueva'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: !_buscoAlMenosUnaVez
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: EmptyState(
                      message: 'Busca la obra a visitar, o regístrala si es nueva',
                      icon: Icons.search,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      mutedColor: mutedColor,
                    ),
                  )
                : FutureBuilder<List<Obra>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ErrorState(
                            message: snapshot.error is AuthException
                                ? (snapshot.error as AuthException).message
                                : 'No se pudo buscar obras',
                            onRetry: _buscar,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            mutedColor: mutedColor,
                          ),
                        );
                      }
                      final obras = snapshot.data!;
                      if (obras.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: EmptyState(
                            message: 'Sin resultados. Regístrala si es nueva.',
                            icon: Icons.location_off_outlined,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            mutedColor: mutedColor,
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: obras.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final obra = obras[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(context).pop(obra),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(obra.nombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                                        if (obra.direccion.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(obra.direccion, style: TextStyle(fontSize: 12.5, color: mutedColor)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: mutedColor),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
