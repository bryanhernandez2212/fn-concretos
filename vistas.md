1. Operador de olla (chofer de revolvedora)

- Mis entregas del día — lista de Remision asignadas a su vehículo/turno.
- Avanzar hito de entrega — botones para mover la remisión por su máquina de estados real (RemisionService.avanzarHito, ya tiene 9 hitos): salida de planta → en ruta → llegada a obra → descarga → entrega completa, etc.
- Firma digital de entrega — captura la firma del cliente en obra (RemisionFirma, ya existe el endpoint).
- Foto/evidencia de entrega — adjuntar fotos (RemisionArchivo, ya existe el endpoint de adjuntos).
- Ubicación en vivo — el GPS del teléfono alimentando SeguimientoGps (el backend ya calcula retraso automático comparando hora de salida contra tolerancia configurada — esto le da valor inmediato a dirección sin que nadie llame por teléfono a preguntar "¿ya llegaste?").
- Reportar pendiente del vehículo — falla, llanta, necesidad de mantenimiento (VehiculoPendiente, ya existe).
- Ver documentos del vehículo — vigencia de seguro/tarjeta de circulación (VehiculoSeguro/VehiculoDocumento), útil para que el chofer no salga con papeles vencidos.

2. Operador de bomba

Mismo bloque de remisión/hitos/firma/foto/GPS que el operador de olla (es la misma Remision, la bomba también participa en el ciclo de entrega vía AsignacionOllaBomba), más:

- Reporte de dosificación real en obra — esta es la función que hoy no existe en el backend: la entidad InformePesadora ya está modelada (cemento/arena/grava/agua/aditivo/acelerante) pero no tiene service/controller/DTO. Si quieres que la app capture lo realmente bombeado/vaciado en obra, esto hay que construirlo primero — te lo marco como prerequisito, no como algo ya disponible.
- Reportar pendiente/incidencia de bomba — mismo mecanismo de VehiculoPendiente.


3. Dirección (autorización de pedidos a crédito)


- Bandeja de pedidos pendientes de autorizar — filtrado por pedidos.autorizar_credito (ya existe el permiso y el endpoint AutorizacionService.autorizarPago).
- Detalle del pedido 
- antes de autorizar — cliente, obra, monto, condición de pago, y aquí hay un hueco real: el "estado de cuenta" del cliente (ClienteService.estadoCuenta) hoy es un stub que siempre responde "finanzas-service aún no está disponible", y límiteCredito/díasCredito se capturan pero nadie los compara contra el pedido. Es decir: hoy dirección autorizaría "a ciegas" respecto al saldo real del cliente — vale la pena resolver esto antes de poner el botón de autorizar en un celular.
- Autorizar o rechazar con motivo — ya existe (motivoRechazo al rechazar).
- Autorización de logística — segundo paso, distinto permiso (pedidos.autorizar_logistica), también ya existe.
- Seguimiento del pedido ya autorizado — avance de entrega (PedidoService.avance), aunque el campo seguimientoEntregaDisponible está hoy fijo en false (placeholder, sin integración real de tracking todavía — se resolvería solo con lo que ya vas a construir para la app de campo).


