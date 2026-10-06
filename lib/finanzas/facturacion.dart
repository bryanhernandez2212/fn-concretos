/// Mirrors `PedidoFacturacionResumenResponse` (`GET /facturas/resumen-por-pedido`):
/// the most relevant prefactura/factura of a pedido, which is what the web's
/// "Facturación" column paints.
class PedidoFacturacionResumen {
  final int pedidoId;
  final int? prefacturaId;
  final String? prefacturaFolio;
  final String? prefacturaEstatus;
  final int? facturaId;
  final String? facturaEstatus;

  const PedidoFacturacionResumen({
    required this.pedidoId,
    this.prefacturaId,
    this.prefacturaFolio,
    this.prefacturaEstatus,
    this.facturaId,
    this.facturaEstatus,
  });

  factory PedidoFacturacionResumen.fromJson(Map<String, dynamic> json) {
    return PedidoFacturacionResumen(
      pedidoId: (json['pedidoId'] as num).toInt(),
      prefacturaId: (json['prefacturaId'] as num?)?.toInt(),
      prefacturaFolio: json['prefacturaFolio'] as String?,
      prefacturaEstatus: json['prefacturaEstatus'] as String?,
      facturaId: (json['facturaId'] as num?)?.toInt(),
      facturaEstatus: json['facturaEstatus'] as String?,
    );
  }
}

/// Mirrors `PrefacturaResponse` — only the fields the pedido screens use.
class Prefactura {
  final int id;
  final String folio;
  final String estatus;
  final double montoTotal;

  const Prefactura({required this.id, required this.folio, required this.estatus, required this.montoTotal});

  /// Same set the web treats as the pedido's live prefactura (`borrador`,
  /// `enviada`, `confirmada_cliente`); while one exists the web shows "Ver
  /// prefactura" instead of "Generar prefactura".
  bool get activa => const {'borrador', 'enviada', 'confirmada_cliente'}.contains(estatus);

  factory Prefactura.fromJson(Map<String, dynamic> json) {
    return Prefactura(
      id: (json['id'] as num).toInt(),
      folio: json['folio'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      montoTotal: (json['montoTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}
