/// Las series de numeración del taller.
///
/// Cada una define su prefijo, cuántos dígitos usa y si el contador se
/// reinicia cada año. Los formatos son los que ya existían: cambiarlos
/// rompería la referencia con la que el cliente reclama.
enum DocumentoConsecutivo {
  factura('FACTURA', 'FAC', digitos: 4, porAnio: false),
  cotizacion('COTIZACION', 'COT', digitos: 4, porAnio: true),
  reserva('RESERVA', 'RES', digitos: 4, porAnio: true),
  // Sin año y a 4 dígitos porque es el formato que ya se veía en pantalla
  // (`ORD-0041`): cambiarlo rompería la referencia con la que el cliente
  // reclama su moto.
  orden('ORDEN', 'ORD', digitos: 4, porAnio: false),
  deuda('DEUDA', 'DEU', digitos: 3, porAnio: false),
  // Por año: lo que se devuelve se cuadra contra la caja del año, y el
  // número lo lee un cliente que trae la pieza de vuelta.
  devolucion('DEVOLUCION', 'DEV', digitos: 4, porAnio: true);

  const DocumentoConsecutivo(
    this.codigo,
    this.prefijo, {
    required this.digitos,
    required this.porAnio,
  });

  /// Lo que va en la columna `documento`.
  final String codigo;

  /// Lo que se ve delante del número: `FAC`, `COT`…
  final String prefijo;

  /// A cuántos dígitos se rellena con ceros.
  final int digitos;

  /// Si el contador arranca de nuevo cada año. Cuando es `true`, el año va
  /// dentro del número: `COT-2026-0001`.
  final bool porAnio;

  /// El periodo al que pertenece [fecha] en esta serie.
  int periodoDe(DateTime fecha) => porAnio ? fecha.year : 0;

  /// Arma el número visible a partir del contador.
  String formatear(int secuencia, {required int periodo}) {
    final relleno = secuencia.toString().padLeft(digitos, '0');
    return porAnio ? '$prefijo-$periodo-$relleno' : '$prefijo-$relleno';
  }
}
