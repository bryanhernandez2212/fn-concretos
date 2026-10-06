import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/info_pill.dart';
import '../jefe_planta_mock.dart';
import '../jefe_planta_widgets.dart';

const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String fechaLarga(DateTime d) =>
    '${_diasSemana[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';

Color colorEstatusProgramacion(String estatus) => switch (estatus) {
  estatusProgramacionAprobado => AppColors.success,
  estatusProgramacionCancelada => AppColors.error,
  estatusProgramacionPrevia => AppColors.warning,
  _ => AppColors.accent,
};

/// Horizontal day picker for the programación day view.
class SelectorDias extends StatelessWidget {
  final List<DateTime> dias;
  final DateTime seleccionado;
  final ValueChanged<DateTime> onSelected;

  const SelectorDias({
    super.key,
    required this.dias,
    required this.seleccionado,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final hoy = DateTime.now();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dias.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final d = dias[index];
          final sel = mismoDia(d, seleccionado);
          final esHoy = mismoDia(d, hoy);
          return GestureDetector(
            onTap: () => onSelected(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              decoration: BoxDecoration(
                color: sel ? AppColors.accent : AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel ? AppColors.accent : AppColors.border(context),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    esHoy ? 'Hoy' : _diasSemana[d.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppColors.onAccent : mutedColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: sel ? AppColors.onAccent : textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Totals strip for the selected day.
class ResumenDia extends StatelessWidget {
  final List<ProgramacionPedido> filas;

  const ResumenDia({super.key, required this.filas});

  @override
  Widget build(BuildContext context) {
    final activas = filas
        .where((f) => f.estatus != estatusProgramacionCancelada)
        .toList();
    final volumen = activas.fold<double>(0, (a, f) => a + f.pedido.volumenM3);
    final aprobadas = activas
        .where((f) => f.estatus == estatusProgramacionAprobado)
        .length;
    Widget dato(String valor, String label) => Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.mutedText(context)),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          dato('${activas.length}', 'Pedidos'),
          dato(m3(volumen), 'Volumen'),
          dato('$aprobadas/${activas.length}', 'Aprobados'),
        ],
      ),
    );
  }
}

/// One programación row on the day timeline: hora on the left rail, pedido
/// card on the right.
class ProgramacionTimelineItem extends StatelessWidget {
  final ProgramacionPedido fila;
  final bool ultimo;
  final VoidCallback onTap;

  const ProgramacionTimelineItem({
    super.key,
    required this.fila,
    required this.ultimo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    final color = colorEstatusProgramacion(fila.estatus);
    final cancelada = fila.estatus == estatusProgramacionCancelada;
    final dosificador = JefePlantaMock.dosificador(fila.dosificadorId);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  fila.horaArranque,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                if (!ultimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border(context, alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: cancelada ? 0.5 : 1,
                child: Material(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onTap,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 4, color: color),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          fila.pedido.folio,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: mutedColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        EstatusPill(
                                          label: etiquetaEstatusProgramacion(
                                            fila.estatus,
                                          ),
                                          color: color,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      fila.pedido.clienteNombre,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      fila.pedido.obraNombre,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: mutedColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fila.pedido.producto,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        InfoPill(
                                          icon: Icons.water_drop_outlined,
                                          text: m3(fila.pedido.volumenM3),
                                          mutedColor: mutedColor,
                                          textColor: textColor,
                                        ),
                                        if (dosificador != null)
                                          InfoPill(
                                            icon: Icons
                                                .precision_manufacturing_outlined,
                                            text: dosificador.nombre,
                                            mutedColor: mutedColor,
                                            textColor: textColor,
                                          ),
                                        if (fila.personalRequerido != null)
                                          InfoPill(
                                            icon: Icons.groups_outlined,
                                            text:
                                                '${fila.personalRequerido} personas',
                                            mutedColor: mutedColor,
                                            textColor: textColor,
                                          ),
                                        if (fila.logisticaAutorizada)
                                          InfoPill(
                                            icon: Icons.verified_outlined,
                                            text: 'Logística',
                                            mutedColor: mutedColor,
                                            textColor: textColor,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pedido still without programación, with its "Programar" button.
class PedidoPorProgramarCard extends StatelessWidget {
  final PedidoPlanta pedido;
  final VoidCallback onProgramar;

  const PedidoPorProgramarCard({
    super.key,
    required this.pedido,
    required this.onProgramar,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                pedido.folio,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                m3(pedido.volumenM3),
                style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pedido.clienteNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
          ),
          Text(
            pedido.obraNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: mutedColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Solicitado: ${fechaLarga(pedido.fechaSolicitada)}',
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onProgramar,
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text(
                'Programar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: botonPrimarioJp().copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgramarInput {
  final DateTime fecha;
  final String horaArranque;
  final int? dosificadorId;
  final int personalRequerido;

  const ProgramarInput({
    required this.fecha,
    required this.horaArranque,
    required this.dosificadorId,
    required this.personalRequerido,
  });
}

/// Bottom sheet with the `ProgramacionRequest` fields (fecha, hora de
/// arranque, dosificador, personal). Pops a [ProgramarInput].
class ProgramarSheet extends StatefulWidget {
  final PedidoPlanta pedido;
  final DateTime fechaInicial;
  final String? horaInicial;
  final int? dosificadorInicial;
  final int? personalInicial;
  final bool editando;

  const ProgramarSheet({
    super.key,
    required this.pedido,
    required this.fechaInicial,
    this.horaInicial,
    this.dosificadorInicial,
    this.personalInicial,
    this.editando = false,
  });

  @override
  State<ProgramarSheet> createState() => _ProgramarSheetState();
}

class _ProgramarSheetState extends State<ProgramarSheet> {
  late DateTime _fecha = widget.fechaInicial;
  late TimeOfDay? _hora = _parseHora(widget.horaInicial);
  late int? _dosificadorId = widget.dosificadorInicial;
  late int _personal = widget.personalInicial ?? 2;

  static TimeOfDay? _parseHora(String? h) {
    if (h == null) return null;
    final p = h.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String? get _horaTexto => _hora == null
      ? null
      : '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 90)),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _elegirHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final mutedColor = AppColors.mutedText(context);

    Widget selector({
      required IconData icon,
      required String label,
      required String? valor,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color: AppColors.border(context, alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontSize: 11.5, color: mutedColor),
                        ),
                        Text(
                          valor ?? 'Elegir',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: valor == null ? mutedColor : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: widget.editando
                  ? 'Reprogramar ${widget.pedido.folio}'
                  : 'Programar ${widget.pedido.folio}',
              subtitle:
                  '${widget.pedido.clienteNombre} · ${m3(widget.pedido.volumenM3)}',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                selector(
                  icon: Icons.calendar_today_outlined,
                  label: 'Fecha',
                  valor: fechaLarga(_fecha),
                  onTap: _elegirFecha,
                ),
                const SizedBox(width: 10),
                selector(
                  icon: Icons.schedule,
                  label: 'Hora de arranque',
                  valor: _horaTexto,
                  onTap: _elegirHora,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Dosificador',
              style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in JefePlantaMock.dosificadores)
                  ChoiceChip(
                    label: Text(d.nombre),
                    selected: _dosificadorId == d.id,
                    showCheckmark: false,
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.border(context, alpha: 0.06),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _dosificadorId == d.id
                          ? AppColors.onAccent
                          : textColor,
                    ),
                    onSelected: (_) => setState(() => _dosificadorId = d.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Personal requerido',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: _personal > 1
                      ? () => setState(() => _personal--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$_personal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => setState(() => _personal++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hora == null
                    ? null
                    : () => Navigator.of(context).pop(
                        ProgramarInput(
                          fecha: _fecha,
                          horaArranque: _horaTexto!,
                          dosificadorId: _dosificadorId,
                          personalRequerido: _personal,
                        ),
                      ),
                style: botonPrimarioJp(),
                child: Text(
                  _hora == null
                      ? 'Elige la hora de arranque'
                      : (widget.editando ? 'Guardar cambios' : 'Programar'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
