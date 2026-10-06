import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/header_icon_button.dart';
import '../jefe_planta_mock.dart';
import '../jefe_planta_widgets.dart';
import 'programacion_widgets.dart';

/// "Programación" tab: the plant's production schedule for one day
/// (operaciones `GET /programacion-produccion?fecha=&plantaId=`) as a
/// timeline by hora de arranque, plus the pedidos still waiting to be
/// programmed. Programming/reprogramming goes through [ProgramarSheet]
/// (`POST`/`PUT /programacion-produccion`); approve/cancel through
/// `PATCH /programacion-produccion/{id}/estatus`. Design-only — runs on
/// [JefePlantaMock].
class ProgramacionScreen extends StatefulWidget {
  const ProgramacionScreen({super.key});

  @override
  State<ProgramacionScreen> createState() => _ProgramacionScreenState();
}

class _ProgramacionScreenState extends State<ProgramacionScreen> {
  late DateTime _dia;
  late List<DateTime> _dias;
  late Future<List<ProgramacionPedido>> _future;
  late Future<List<PedidoPlanta>> _porProgramar;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final hoy = DateTime(n.year, n.month, n.day);
    _dia = hoy;
    _dias = [for (var i = -1; i < 8; i++) hoy.add(Duration(days: i))];
    _cargar();
  }

  void _cargar() {
    setState(() {
      _future = JefePlantaMock.programacion(_dia);
      _porProgramar = JefePlantaMock.pedidosPorProgramar();
    });
  }

  Future<void> _refresh() async {
    _cargar();
    await Future.wait([_future, _porProgramar]);
  }

  void _seleccionarDia(DateTime d) {
    if (!_dias.any((x) => mismoDia(x, d))) {
      _dias = [for (var i = -1; i < 8; i++) d.add(Duration(days: i))];
    }
    _dia = d;
    _cargar();
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('es'),
    );
    if (picked != null) _seleccionarDia(picked);
  }

  Future<ProgramarInput?> _abrirProgramar(
    PedidoPlanta pedido, {
    ProgramacionPedido? fila,
  }) {
    return showModalBottomSheet<ProgramarInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProgramarSheet(
        pedido: pedido,
        fechaInicial: fila?.fechaProgramada ?? _dia,
        horaInicial: fila?.horaArranque,
        dosificadorInicial: fila?.dosificadorId,
        personalInicial: fila?.personalRequerido,
        editando: fila != null,
      ),
    );
  }

  Future<void> _programar(
    PedidoPlanta pedido, {
    ProgramacionPedido? fila,
  }) async {
    final input = await _abrirProgramar(pedido, fila: fila);
    if (input == null || !mounted) return;
    try {
      await JefePlantaMock.guardarProgramacion(
        id: fila?.id,
        pedido: pedido,
        fecha: input.fecha,
        horaArranque: input.horaArranque,
        dosificadorId: input.dosificadorId,
        personalRequerido: input.personalRequerido,
      );
      if (!mounted) return;
      AppSnack.success(
        context,
        '${pedido.folio} programado para ${fechaLarga(input.fecha)} a las ${input.horaArranque}',
      );
      _cargar();
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'No se pudo guardar la programación');
      }
    }
  }

  Future<void> _cambiarEstatus(ProgramacionPedido fila, String estatus) async {
    try {
      await JefePlantaMock.cambiarEstatus(fila.id, estatus);
      if (!mounted) return;
      AppSnack.success(
        context,
        estatus == estatusProgramacionAprobado
            ? '${fila.pedido.folio} aprobado'
            : '${fila.pedido.folio} cancelado',
      );
      _cargar();
    } catch (_) {
      if (mounted) {
        AppSnack.error(context, 'No se pudo actualizar la programación');
      }
    }
  }

  Future<void> _confirmarCancelar(ProgramacionPedido fila) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar programación'),
        content: Text(
          '¿Cancelar la programación de ${fila.pedido.folio}? El pedido volverá a "Por programar".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok == true) await _cambiarEstatus(fila, estatusProgramacionCancelada);
  }

  Future<void> _acciones(ProgramacionPedido fila) async {
    final textColor = AppColors.text(context);
    final puedeAprobar =
        fila.estatus == estatusProgramacionProgramado ||
        fila.estatus == estatusProgramacionPrevia;
    final activa = fila.estatus != estatusProgramacionCancelada;
    final accion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceAlt(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                title: '${fila.pedido.folio} · ${fila.horaArranque}',
                subtitle:
                    '${fila.pedido.clienteNombre} — ${fila.pedido.obraNombre}',
              ),
              const SizedBox(height: 12),
              if (puedeAprobar)
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  title: Text(
                    'Aprobar',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'También autoriza la logística del pedido',
                  ),
                  onTap: () => Navigator.of(context).pop('aprobar'),
                ),
              if (activa)
                ListTile(
                  leading: const Icon(
                    Icons.edit_calendar_outlined,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    'Reprogramar',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('reprogramar'),
                ),
              if (activa)
                ListTile(
                  leading: const Icon(
                    Icons.cancel_outlined,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('cancelar'),
                ),
              if (!activa)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Esta programación está cancelada.',
                    style: TextStyle(color: AppColors.mutedText(context)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (accion) {
      case 'aprobar':
        await _cambiarEstatus(fila, estatusProgramacionAprobado);
      case 'reprogramar':
        await _programar(fila.pedido, fila: fila);
      case 'cancelar':
        await _confirmarCancelar(fila);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final miPlanta = JefePlantaMock.planta(JefePlantaMock.miPlantaId);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          BottomNavBar.clearance(context) + 16,
        ),
        children: [
          JefePlantaTabHeader(
            icon: Icons.event_note_outlined,
            title: 'Programación',
            subtitle: miPlanta?.nombre ?? 'Tu planta',
            action: HeaderIconButton(
              icon: Icons.calendar_month_outlined,
              tooltip: 'Elegir fecha',
              onPressed: _elegirFecha,
            ),
          ),
          const SizedBox(height: 12),
          const DatosEjemploBanner(),
          const SizedBox(height: 16),
          SelectorDias(
            dias: _dias,
            seleccionado: _dia,
            onSelected: _seleccionarDia,
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<PedidoPlanta>>(
            future: _porProgramar,
            builder: (context, snapshot) {
              final pendientes = snapshot.data ?? const <PedidoPlanta>[];
              if (snapshot.connectionState != ConnectionState.done ||
                  pendientes.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Por programar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      EstatusPill(
                        label: '${pendientes.length}',
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pendientes.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) => PedidoPorProgramarCard(
                        pedido: pendientes[index],
                        onProgramar: () => _programar(pendientes[index]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          Text(
            fechaLarga(_dia),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<ProgramacionPedido>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const JefePlantaCargando();
              }
              if (snapshot.hasError) {
                return JefePlantaMensaje(
                  icon: Icons.error_outline,
                  mensaje: 'No se pudo cargar la programación',
                  onRetry: _cargar,
                );
              }
              final filas = snapshot.data!;
              if (filas.isEmpty) {
                return const JefePlantaMensaje(
                  icon: Icons.event_busy_outlined,
                  mensaje: 'No hay pedidos programados este día',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResumenDia(filas: filas),
                  const SizedBox(height: 16),
                  for (var i = 0; i < filas.length; i++)
                    ProgramacionTimelineItem(
                      fila: filas[i],
                      ultimo: i == filas.length - 1,
                      onTap: () => _acciones(filas[i]),
                    ),
                  Text(
                    'Toca un pedido para aprobar, reprogramar o cancelar.',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
