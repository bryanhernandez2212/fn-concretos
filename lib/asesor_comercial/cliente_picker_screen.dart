import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../direccion/comercial_service.dart';
import '../direccion/pedido.dart';
import '../theme/app_colors.dart';
import 'asesor_comercial_widgets.dart';
import 'cliente_form_screen.dart';

/// First step of Asesor Comercial's "agregar obra" flow — picks (via
/// `ComercialService.buscarClientes`) or creates (`ClienteFormScreen`) the
/// cliente that will own the new obra, since `POST /obras` requires a
/// `clientePrincipalId`. Pops with the chosen/created [Cliente], or `null`
/// if cancelled.
class ClientePickerScreen extends StatefulWidget {
  const ClientePickerScreen({super.key});

  @override
  State<ClientePickerScreen> createState() => _ClientePickerScreenState();
}

class _ClientePickerScreenState extends State<ClientePickerScreen> {
  final _queryController = TextEditingController();
  Future<List<Cliente>>? _future;
  bool _buscoAlMenosUnaVez = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _buscoAlMenosUnaVez = true;
      _future = ComercialService.buscarClientes(q: _queryController.text.trim());
    });
  }

  Future<void> _nuevoCliente() async {
    final creado = await Navigator.of(context).push<Cliente>(
      MaterialPageRoute(builder: (context) => const ClienteFormScreen()),
    );
    if (creado != null && mounted) Navigator.of(context).pop(creado);
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
        title: const Text('Elegir cliente'),
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
                hintText: 'Buscar por nombre o número de cliente',
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
                onPressed: _nuevoCliente,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Registrar cliente nuevo'),
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
                      message: 'Busca un cliente para vincular la obra, o registra uno nuevo',
                      icon: Icons.search,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      mutedColor: mutedColor,
                    ),
                  )
                : FutureBuilder<List<Cliente>>(
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
                                : 'No se pudo buscar clientes',
                            onRetry: _buscar,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            mutedColor: mutedColor,
                          ),
                        );
                      }
                      final clientes = snapshot.data!;
                      if (clientes.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: EmptyState(
                            message: 'Sin resultados. Registra el cliente si es nuevo.',
                            icon: Icons.person_off_outlined,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            mutedColor: mutedColor,
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: clientes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final cliente = clientes[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(context).pop(cliente),
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
                                        Text(cliente.nombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                                        const SizedBox(height: 2),
                                        Text(cliente.estatus, style: TextStyle(fontSize: 12.5, color: mutedColor)),
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
