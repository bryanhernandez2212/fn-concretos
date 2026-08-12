import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

/// Static placeholders for the driver's assigned unit until this is backed
/// by real `Vehiculo`/`VehiculoDocumento`/`VehiculoPendiente` data. Split by
/// role since Operador de Olla drives a revolvedora and Operador de Bomba
/// drives a pump truck — otherwise a bomba operator would see the wrong unit.
const _vehiculoPlacaOlla = 'DR-4521-A';
const _vehiculoModeloOlla = 'Revolvedora Freightliner M2 · 7 m³';
const _vehiculoPlacaBomba = 'BM-2290-C';
const _vehiculoModeloBomba = 'Bomba pluma Putzmeister BSF 36';

String get vehiculoPlaca => AuthService.rol == 'Operador de Bomba' ? _vehiculoPlacaBomba : _vehiculoPlacaOlla;
String get vehiculoModelo => AuthService.rol == 'Operador de Bomba' ? _vehiculoModeloBomba : _vehiculoModeloOlla;

enum VehiculoDocumentoEstado { vigente, porVencer, vencido }

extension VehiculoDocumentoEstadoStyle on VehiculoDocumentoEstado {
  String get label => switch (this) {
    VehiculoDocumentoEstado.vigente => 'Vigente',
    VehiculoDocumentoEstado.porVencer => 'Por vencer',
    VehiculoDocumentoEstado.vencido => 'Vencido',
  };

  Color get color => switch (this) {
    VehiculoDocumentoEstado.vigente => const Color(0xFF4CAF50),
    VehiculoDocumentoEstado.porVencer => const Color(0xFFFFA000),
    VehiculoDocumentoEstado.vencido => const Color(0xFFEF5350),
  };
}

class VehiculoDocumento {
  final String nombre;
  final String vigencia;
  final VehiculoDocumentoEstado estado;

  const VehiculoDocumento({required this.nombre, required this.vigencia, required this.estado});
}

const vehiculoDocumentos = [
  VehiculoDocumento(nombre: 'Tarjeta de circulación', vigencia: '14 mar 2026', estado: VehiculoDocumentoEstado.vigente),
  VehiculoDocumento(nombre: 'Póliza de seguro', vigencia: '02 sep 2025', estado: VehiculoDocumentoEstado.porVencer),
  VehiculoDocumento(nombre: 'Verificación vehicular', vigencia: '30 jun 2025', estado: VehiculoDocumentoEstado.vencido),
  VehiculoDocumento(nombre: 'Licencia federal', vigencia: '18 nov 2026', estado: VehiculoDocumentoEstado.vigente),
];

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
}

enum UrgenciaPendiente { baja, media, alta }

extension UrgenciaPendienteLabel on UrgenciaPendiente {
  String get label => switch (this) {
    UrgenciaPendiente.baja => 'Baja',
    UrgenciaPendiente.media => 'Media',
    UrgenciaPendiente.alta => 'Alta',
  };

  Color get color => switch (this) {
    UrgenciaPendiente.baja => const Color(0xFF4CAF50),
    UrgenciaPendiente.media => const Color(0xFFFFA000),
    UrgenciaPendiente.alta => const Color(0xFFEF5350),
  };
}
