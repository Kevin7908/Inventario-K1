/// Cómo se pagó. **Uno solo para todo el sistema.**
///
/// Antes había tres vocabularios para el mismo concepto: el enum `MetodoPago`
/// de facturas —en MAYÚSCULAS, sin Nequi ni Daviplata— y dos listas de texto
/// idénticas, `kMetodosPago` en reservas y `kMetodosPagoDeudor` en deudores,
/// capitalizadas. El mismo pago se guardaba como `'EFECTIVO'` o como
/// `'Efectivo'` según por dónde entrara, y ningún informe podía cruzarlos.
///
/// [codigo] es lo que viaja a la base y lo que validan los `CHECK`;
/// [etiqueta] es lo único que ve el usuario.
enum MetodoPago {
  efectivo('EFECTIVO', 'Efectivo'),
  transferencia('TRANSFERENCIA', 'Transferencia'),
  tarjeta('TARJETA', 'Tarjeta'),
  nequi('NEQUI', 'Nequi'),
  daviplata('DAVIPLATA', 'Daviplata'),
  credito('CREDITO', 'Crédito');

  const MetodoPago(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  /// Los que puede elegir quien **entrega dinero**: un abono de reserva o un
  /// pago de deuda.
  ///
  /// [credito] queda fuera porque no es una forma de pagar, sino de aplazar:
  /// solo tiene sentido como condición de una factura.
  static const List<MetodoPago> paraAbonos = [
    efectivo,
    transferencia,
    tarjeta,
    nequi,
    daviplata,
  ];

  /// Fragmento `IN (...)` para los `CHECK` del esquema.
  ///
  /// Se genera desde el enum para que agregar un método no obligue a acordarse
  /// de dos sitios. Las tablas lo interpolan en `customConstraints`.
  static String get listaSql =>
      values.map((m) => "'${m.codigo}'").join(', ');

  /// Igual que [listaSql] pero sin [credito]: para las tablas de abonos.
  static String get listaSqlAbonos =>
      paraAbonos.map((m) => "'${m.codigo}'").join(', ');

  /// Traduce lo guardado en la base. Cae en [efectivo], que es lo que había en
  /// las filas sin método explícito.
  static MetodoPago desdeCodigo(String? codigo) => values.firstWhere(
        (m) => m.codigo == (codigo ?? '').toUpperCase(),
        orElse: () => MetodoPago.efectivo,
      );
}
