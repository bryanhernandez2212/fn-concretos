import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../catalogo/catalogo_service.dart';
import '../../catalogo/conciliacion_agregados.dart';
import '../../finanzas/conciliacion_proveedor.dart';
import '../../finanzas/finanzas_service.dart';
import '../../jefe_planta/jefe_planta_service.dart' show Proveedor;
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/header_icon_button.dart';
import '../../widgets/notification_bell_button.dart';
import 'abrir_conciliacion_sheet.dart';
import 'agregado_detail_screen.dart';
import 'conciliacion_agregados_widgets.dart';
import 'conciliacion_proveedor_detail_screen.dart';
import 'registrar_vale_sheet.dart';

const _accentYellow = AppColors.accent;

/// Dirección's "Conciliados" tab with 3 sections:
/// 1. "Entrada de Mercancía" — catálogo y detalle de materiales, insumos y servicios.
/// 2. "Conciliación de Proveedores" — conciliación periódica vale vs comprobante de pago.
/// 3. "Vales de Entrada" — vales de entrada de arena/grava/agua entregados por proveedores.
class ConciliacionAgregadosScreen extends StatefulWidget {
  const ConciliacionAgregadosScreen({super.key});

  @override
  State<ConciliacionAgregadosScreen> createState() =>
      _ConciliacionAgregadosScreenState();
}

class _ConciliacionAgregadosScreenState
    extends State<ConciliacionAgregadosScreen> {
  // 0 = Vales de Entrada, 1 = Entrada de Mercancía, 2 = Conciliación de Proveedores
  int _seccionPrincipal = 0;

  // ---------------------------------------------------------------------------
  // 1. Vales de Entrada state
  // ---------------------------------------------------------------------------
  late Future<List<ValeEntradaMaterial>> _valesFuture = _cargarVales();
  String _filtroEstatusVale = 'todos';
  Proveedor? _filtroProveedorVale;
  String _busquedaVales = '';

  // ---------------------------------------------------------------------------
  // 2. Entrada de Mercancía state
  // ---------------------------------------------------------------------------
  int _subTab = 0; // 0 = materiales, 1 = insumos, 2 = servicios
  late Future<List<MaterialAgregado>> _materialesFuture = _cargarMateriales();
  late Future<List<InsumoAgregado>> _insumosFuture = _cargarInsumos();
  late Future<List<ServicioAgregado>> _serviciosFuture = _cargarServicios();
  String _busqueda = '';

  final bool _puedeAdministrar =
      AuthService.permisos.contains('catalogo.administrar');

  // ---------------------------------------------------------------------------
  // 3. Conciliación de Proveedores state
  // ---------------------------------------------------------------------------
  late Future<List<Proveedor>> _proveedoresFuture = _cargarProveedores();
  Proveedor? _proveedorSeleccionado;
  Future<List<ConciliacionProveedor>>? _conciliacionesFuture;

  @override
  void initState() {
    super.initState();
    _iniciarProveedores();
  }

  Future<void> _iniciarProveedores() async {
    final proveedores = await _proveedoresFuture;
    if (mounted && proveedores.isNotEmpty && _proveedorSeleccionado == null) {
      setState(() {
        _proveedorSeleccionado = proveedores.first;
        _conciliacionesFuture = _cargarConciliaciones(proveedores.first.id);
      });
    }
  }

  Future<List<MaterialAgregado>> _cargarMateriales() =>
      CatalogoService.materiales();

  Future<List<InsumoAgregado>> _cargarInsumos() => CatalogoService.insumos();

  Future<List<ServicioAgregado>> _cargarServicios() =>
      CatalogoService.servicios();

  Future<List<Proveedor>> _cargarProveedores() => FinanzasService.proveedores();

  Future<List<ConciliacionProveedor>> _cargarConciliaciones(int proveedorId) =>
      FinanzasService.conciliacionesProveedor(proveedorId: proveedorId);

  Future<List<ValeEntradaMaterial>> _cargarVales() {
    return FinanzasService.valesEntradaMaterial(
      proveedorId: _filtroProveedorVale?.id,
      estatus: _filtroEstatusVale == 'todos' ? null : _filtroEstatusVale,
    );
  }

  void _refresh() {
    setState(() {
      if (_seccionPrincipal == 0) {
        _valesFuture = _cargarVales();
      } else if (_seccionPrincipal == 1) {
        _materialesFuture = _cargarMateriales();
        _insumosFuture = _cargarInsumos();
        _serviciosFuture = _cargarServicios();
      } else {
        _proveedoresFuture = _cargarProveedores();
        if (_proveedorSeleccionado != null) {
          _conciliacionesFuture = _cargarConciliaciones(_proveedorSeleccionado!.id);
        }
      }
    });
  }

  void _refreshActualAgregados() {
    setState(() {
      switch (_subTab) {
        case 0:
          _materialesFuture = _cargarMateriales();
          break;
        case 1:
          _insumosFuture = _cargarInsumos();
          break;
        case 2:
          _serviciosFuture = _cargarServicios();
          break;
      }
    });
  }

  void _refreshConciliaciones() {
    if (_proveedorSeleccionado != null) {
      setState(() {
        _conciliacionesFuture = _cargarConciliaciones(_proveedorSeleccionado!.id);
      });
    }
  }

  void _refreshVales() {
    setState(() {
      _valesFuture = _cargarVales();
    });
  }

  TipoAgregado get _tipoActual {
    switch (_subTab) {
      case 0:
        return TipoAgregado.material;
      case 1:
        return TipoAgregado.insumo;
      case 2:
        return TipoAgregado.servicio;
      default:
        return TipoAgregado.material;
    }
  }

  Future<void> _abrirNuevoAgregado() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AgregadoDetailScreen(tipo: _tipoActual),
      ),
    );
    if (creado == true) _refreshActualAgregados();
  }

  Future<void> _abrirNuevaConciliacion() async {
    final proveedores = await _proveedoresFuture;
    if (!mounted) return;

    final nueva = await showModalBottomSheet<ConciliacionProveedor>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AbrirConciliacionSheet(
        proveedores: proveedores,
        proveedorInicial: _proveedorSeleccionado,
      ),
    );

    if (nueva != null && mounted) {
      final match = proveedores.where((p) => p.id == nueva.proveedorId).firstOrNull;
      if (match != null) {
        setState(() {
          _proveedorSeleccionado = match;
          _conciliacionesFuture = _cargarConciliaciones(match.id);
        });
      } else {
        _refreshConciliaciones();
      }
    }
  }

  Future<void> _abrirRegistrarVale() async {
    final proveedores = await _proveedoresFuture;
    if (!mounted) return;

    final creado = await showModalBottomSheet<ValeEntradaMaterial>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RegistrarValeSheet(
        proveedores: proveedores,
        proveedorInicial: _filtroProveedorVale ?? _proveedorSeleccionado,
      ),
    );

    if (creado != null && mounted) {
      AppSnack.success(context, 'Vale registrado con éxito');
      _refreshVales();
    }
  }

  Future<void> _cambiarEstatusVale(ValeEntradaMaterial vale) async {
    const opciones = [
      ('registrado', 'Registrado', Colors.blue),
      ('conciliado', 'Conciliado', AppColors.success),
      ('con_diferencia', 'Con diferencia', AppColors.warning),
      ('autorizado_pago', 'Autorizado pago', AppColors.success),
    ];

    final nuevoEstatus = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.mutedText(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Cambiar estatus del vale #${vale.folioVale ?? vale.id}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 12),
                ...opciones.map((op) {
                  final seleccionado = (vale.estatus ?? 'registrado').toLowerCase() == op.$1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 6,
                      backgroundColor: op.$3,
                    ),
                    title: Text(
                      op.$2,
                      style: TextStyle(
                        fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w500,
                        color: seleccionado ? AppColors.accent : AppColors.text(context),
                      ),
                    ),
                    trailing: seleccionado
                        ? const Icon(Icons.check, color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(op.$1),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (nuevoEstatus == null || nuevoEstatus == vale.estatus) return;

    try {
      await FinanzasService.cambiarEstatusValeEntradaMaterial(vale.id, estatus: nuevoEstatus);
      if (mounted) {
        AppSnack.success(context, 'Estatus actualizado a ${etiquetaEstatusVale(nuevoEstatus)}');
        _refreshVales();
      }
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    String subtitulo;
    switch (_seccionPrincipal) {
      case 0:
        subtitulo = 'Vales de entrega de arena, grava y agua';
        break;
      case 1:
        subtitulo = 'Materiales, insumos y servicios';
        break;
      case 2:
      default:
        subtitulo = 'Conciliación periódica con proveedores';
        break;
    }

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          BottomNavBar.clearance(context) + 16,
        ),
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentYellow.withValues(alpha: 0.18),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: _accentYellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conciliados',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 13, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_seccionPrincipal == 0)
                HeaderIconButton(
                  icon: Icons.add,
                  tooltip: 'Registrar vale',
                  onPressed: _abrirRegistrarVale,
                )
              else if (_seccionPrincipal == 1 && _puedeAdministrar)
                HeaderIconButton(
                  icon: Icons.add,
                  tooltip: 'Nuevo agregado',
                  onPressed: _abrirNuevoAgregado,
                )
              else if (_seccionPrincipal == 2)
                HeaderIconButton(
                  icon: Icons.add,
                  tooltip: 'Abrir conciliación',
                  onPressed: _abrirNuevaConciliacion,
                ),
              const SizedBox(width: 8),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 18),

          // Primary Section Toggle (3 Sections: Vales, Entrada Mercancía, Proveedores)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _seccionPill(
                    index: 0,
                    label: 'Vales de Entrada',
                    icon: Icons.local_shipping_outlined,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                  const SizedBox(width: 4),
                  _seccionPill(
                    index: 1,
                    label: 'Entrada Mercancía',
                    icon: Icons.receipt_outlined,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                  const SizedBox(width: 4),
                  _seccionPill(
                    index: 2,
                    label: 'Conciliación Proveedores',
                    icon: Icons.handshake_outlined,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Body depending on selected section
          if (_seccionPrincipal == 0) ...[
            _buildValesEntradaSection(textColor, mutedColor),
          ] else if (_seccionPrincipal == 1) ...[
            _buildEntradaMercanciaSection(textColor, mutedColor),
          ] else ...[
            _buildConciliacionProveedoresSection(textColor, mutedColor),
          ],
        ],
      ),
    );
  }

  Widget _seccionPill({
    required int index,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color mutedColor,
  }) {
    final active = _seccionPrincipal == index;
    return GestureDetector(
      onTap: () => setState(() => _seccionPrincipal = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _accentYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.black : mutedColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.black : mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECCIÓN 1: Entrada de Mercancía
  // ===========================================================================
  Widget _buildEntradaMercanciaSection(Color textColor, Color mutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        TextField(
          onChanged: (v) => setState(() => _busqueda = v),
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre…',
            hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.search, color: mutedColor, size: 20),
            filled: true,
            fillColor: textColor.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Sub-tabs (Materiales, Insumos, Servicios)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              _subTabChip(0, 'Materiales', Icons.terrain, textColor, mutedColor),
              _subTabChip(1, 'Insumos', Icons.build_circle_outlined, textColor, mutedColor),
              _subTabChip(2, 'Servicios', Icons.miscellaneous_services, textColor, mutedColor),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildAgregadosList(),
      ],
    );
  }

  Widget _subTabChip(
    int index,
    String label,
    IconData icon,
    Color textColor,
    Color mutedColor,
  ) {
    final active = _subTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _subTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? _accentYellow.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? _accentYellow : mutedColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? textColor : mutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgregadosList() {
    switch (_subTab) {
      case 0:
        return _buildMateriales();
      case 1:
        return _buildInsumos();
      case 2:
        return _buildServicios();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMateriales() {
    return FutureBuilder<List<MaterialAgregado>>(
      future: _materialesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AgregadoErrorPlaceholder(
            mensaje: 'No se pudieron cargar los materiales',
            onRetry: _refreshActualAgregados,
          );
        }
        final items = (snapshot.data ?? [])
            .where((m) =>
                _busqueda.isEmpty ||
                m.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
                (m.descripcion?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false))
            .toList();

        if (items.isEmpty) {
          return AgregadoVacioPlaceholder(
            tipo: 'materiales',
            busqueda: _busqueda,
            onCrear: _puedeAdministrar ? _abrirNuevoAgregado : null,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return MaterialCard(
              material: item,
              onTap: () async {
                final modificado = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AgregadoDetailScreen(
                      tipo: TipoAgregado.material,
                      id: item.id,
                    ),
                  ),
                );
                if (modificado == true) _refreshActualAgregados();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInsumos() {
    return FutureBuilder<List<InsumoAgregado>>(
      future: _insumosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AgregadoErrorPlaceholder(
            mensaje: 'No se pudieron cargar los insumos',
            onRetry: _refreshActualAgregados,
          );
        }
        final items = (snapshot.data ?? [])
            .where((i) =>
                _busqueda.isEmpty ||
                i.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
                (i.categoria?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false))
            .toList();

        if (items.isEmpty) {
          return AgregadoVacioPlaceholder(
            tipo: 'insumos',
            busqueda: _busqueda,
            onCrear: _puedeAdministrar ? _abrirNuevoAgregado : null,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return InsumoCard(
              insumo: item,
              onTap: () async {
                final modificado = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AgregadoDetailScreen(
                      tipo: TipoAgregado.insumo,
                      id: item.id,
                    ),
                  ),
                );
                if (modificado == true) _refreshActualAgregados();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildServicios() {
    return FutureBuilder<List<ServicioAgregado>>(
      future: _serviciosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AgregadoErrorPlaceholder(
            mensaje: 'No se pudieron cargar los servicios',
            onRetry: _refreshActualAgregados,
          );
        }
        final items = (snapshot.data ?? [])
            .where((s) =>
                _busqueda.isEmpty ||
                s.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
                (s.descripcion?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false))
            .toList();

        if (items.isEmpty) {
          return AgregadoVacioPlaceholder(
            tipo: 'servicios',
            busqueda: _busqueda,
            onCrear: _puedeAdministrar ? _abrirNuevoAgregado : null,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ServicioCard(
              servicio: item,
              onTap: () async {
                final modificado = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AgregadoDetailScreen(
                      tipo: TipoAgregado.servicio,
                      id: item.id,
                    ),
                  ),
                );
                if (modificado == true) _refreshActualAgregados();
              },
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // SECCIÓN 2: Conciliación de Proveedores
  // ===========================================================================
  Widget _buildConciliacionProveedoresSection(Color textColor, Color mutedColor) {
    return FutureBuilder<List<Proveedor>>(
      future: _proveedoresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _proveedorSeleccionado == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError && _proveedorSeleccionado == null) {
          return AgregadoErrorPlaceholder(
            mensaje: 'No se pudieron cargar los proveedores',
            onRetry: () {
              setState(() {
                _proveedoresFuture = _cargarProveedores();
              });
            },
          );
        }

        final proveedores = snapshot.data ?? [];
        if (proveedores.isEmpty && _proveedorSeleccionado == null) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.person_off_outlined, size: 40, color: mutedColor),
                  const SizedBox(height: 10),
                  Text(
                    'No hay proveedores activos',
                    style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider selector card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_outlined, size: 22, color: _accentYellow),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proveedor seleccionado',
                          style: TextStyle(fontSize: 11, color: mutedColor),
                        ),
                        const SizedBox(height: 2),
                        DropdownButton<Proveedor>(
                          value: _proveedorSeleccionado ??
                              (proveedores.isNotEmpty ? proveedores.first : null),
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          icon: Icon(Icons.arrow_drop_down, color: mutedColor),
                          items: proveedores.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (p) {
                            if (p != null) {
                              setState(() {
                                _proveedorSeleccionado = p;
                                _conciliacionesFuture = _cargarConciliaciones(p.id);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Header for conciliaciones list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conciliaciones Periódicas',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: _abrirNuevaConciliacion,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Abrir período', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: _accentYellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Conciliaciones List
            if (_conciliacionesFuture == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              FutureBuilder<List<ConciliacionProveedor>>(
                future: _conciliacionesFuture,
                builder: (context, concSnap) {
                  if (concSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (concSnap.hasError) {
                    return AgregadoErrorPlaceholder(
                      mensaje: 'Error al consultar las conciliaciones: ${concSnap.error}',
                      onRetry: _refreshConciliaciones,
                    );
                  }

                  final conciliaciones = concSnap.data ?? [];
                  if (conciliaciones.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inventory_outlined,
                                size: 44, color: mutedColor),
                            const SizedBox(height: 12),
                            Text(
                              'Sin conciliaciones registradas',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No hay conciliaciones abiertas para este proveedor en el período.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: mutedColor),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentYellow,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _abrirNuevaConciliacion,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Abrir Primera Conciliación',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: conciliaciones.length,
                    itemBuilder: (context, index) {
                      final c = conciliaciones[index];
                      return ConciliacionProveedorCard(
                        conciliacion: c,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ConciliacionProveedorDetailScreen(
                                conciliacion: c,
                              ),
                            ),
                          );
                          _refreshConciliaciones();
                        },
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // SECCIÓN 3: Vales de Entrada (vale-entrada-material-controller)
  // ===========================================================================
  Widget _buildValesEntradaSection(Color textColor, Color mutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          onChanged: (v) => setState(() => _busquedaVales = v),
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar por folio, material, transportista o placas…',
            hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.search, color: mutedColor, size: 20),
            filled: true,
            fillColor: textColor.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Status filters horizontal row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _valeStatusFilterChip('todos', 'Todos'),
              const SizedBox(width: 8),
              _valeStatusFilterChip('registrado', 'Registrados'),
              const SizedBox(width: 8),
              _valeStatusFilterChip('conciliado', 'Conciliados'),
              const SizedBox(width: 8),
              _valeStatusFilterChip('con_diferencia', 'Con diferencia'),
              const SizedBox(width: 8),
              _valeStatusFilterChip('autorizado_pago', 'Autorizados'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Vales List
        FutureBuilder<List<ValeEntradaMaterial>>(
          future: _valesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return AgregadoErrorPlaceholder(
                mensaje: 'No se pudieron consultar los vales: ${snapshot.error}',
                onRetry: _refreshVales,
              );
            }

            final query = _busquedaVales.toLowerCase().trim();
            final vales = (snapshot.data ?? []).where((v) {
              if (query.isEmpty) return true;
              final folio = (v.folioVale ?? '').toLowerCase();
              final mat = (v.material ?? '').toLowerCase();
              final chofer = (v.transportista ?? '').toLowerCase();
              final placas = (v.placas ?? '').toLowerCase();
              final prov = (v.proveedorNombre ?? '').toLowerCase();
              return folio.contains(query) ||
                  mat.contains(query) ||
                  chofer.contains(query) ||
                  placas.contains(query) ||
                  prov.contains(query);
            }).toList();

            if (vales.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 44, color: mutedColor),
                      const SizedBox(height: 12),
                      Text(
                        _busquedaVales.isNotEmpty
                            ? 'No se encontraron vales con "$_busquedaVales"'
                            : 'Sin vales de entrada registrados',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _busquedaVales.isNotEmpty
                            ? 'Intenta con otro término de búsqueda.'
                            : 'Registra un vale de entrada de material con el botón de abajo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: mutedColor),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentYellow,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _abrirRegistrarVale,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Registrar Primer Vale',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vales.length,
              itemBuilder: (context, index) {
                final v = vales[index];
                return ValeEntradaCard(
                  vale: v,
                  onCambiarEstatus: () => _cambiarEstatusVale(v),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _valeStatusFilterChip(String value, String label) {
    final active = _filtroEstatusVale == value;
    final color = active ? _accentYellow : AppColors.card(context);
    final textCol = active ? Colors.black : AppColors.text(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _filtroEstatusVale = value;
          _valesFuture = _cargarVales();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _accentYellow : AppColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: textCol,
          ),
        ),
      ),
    );
  }
}
