import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum VehiculoDocumentoEstado { vigente, porVencer, vencido }

extension VehiculoDocumentoEstadoStyle on VehiculoDocumentoEstado {
  String get label => switch (this) {
    VehiculoDocumentoEstado.vigente => 'Vigente',
    VehiculoDocumentoEstado.porVencer => 'Por vencer',
    VehiculoDocumentoEstado.vencido => 'Vencido',
  };

  Color get color => switch (this) {
    VehiculoDocumentoEstado.vigente => AppColors.success,
    VehiculoDocumentoEstado.porVencer => AppColors.warning,
    VehiculoDocumentoEstado.vencido => AppColors.error,
  };
}

/// Derives display status from a document's real `vigencia` date (see
/// `VehiculoDocumentoResumen`). A null `vigencia` (nothing tracked for that
/// document) reads as vigente — nothing to warn about — rather than
/// fabricating urgency out of missing data.
VehiculoDocumentoEstado estadoDeVigencia(DateTime? vigencia) {
  if (vigencia == null) return VehiculoDocumentoEstado.vigente;
  final hoy = DateTime.now();
  if (vigencia.isBefore(hoy)) return VehiculoDocumentoEstado.vencido;
  if (vigencia.difference(hoy).inDays <= 30) return VehiculoDocumentoEstado.porVencer;
  return VehiculoDocumentoEstado.vigente;
}

enum TipoPendiente { fallaMecanica, llanta, mantenimiento, otro }

extension TipoPendienteLabel on TipoPendiente {
  String get label => switch (this) {
    TipoPendiente.fallaMecanica => 'Falla mecánica',
    TipoPendiente.llanta => 'Llanta',
    TipoPendiente.mantenimiento => 'Mantenimiento',
    TipoPendiente.otro => 'Otro',
  };

  IconData get icon => switch (this) {
    TipoPendiente.fallaMecanica => Icons.build_outlined,
    TipoPendiente.llanta => Icons.tire_repair_outlined,
    TipoPendiente.mantenimiento => Icons.handyman_outlined,
    TipoPendiente.otro => Icons.report_problem_outlined,
  };

  /// String sent as `VehiculoPendienteRequest.tipoPendiente`. The API docs
  /// type this as a free-form string (no enum constraint), so these are a
  /// best guess pending a live round-trip to confirm.
  String get backendValue => switch (this) {
    TipoPendiente.fallaMecanica => 'falla_mecanica',
    TipoPendiente.llanta => 'llanta',
    TipoPendiente.mantenimiento => 'mantenimiento',
    TipoPendiente.otro => 'otro',
  };
}
