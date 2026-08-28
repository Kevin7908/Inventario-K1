import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_detalle.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/features/inventario/repositorio/repositorio_inventario.dart';

/// Un libro mayor de mentira: responde lo que le digan sin tocar SQLite.
///
/// Hace falta porque los tests que lo usan miran la pantalla, no la base. Lo
/// del backend ya está cubierto en `repositorio_inventario_test.dart` contra
/// Drift en memoria, con las FK activas.
class RepositorioInventarioFalso implements RepositorioInventario {
  RepositorioInventarioFalso({this.movimientos = const []});

  /// Lo que devuelve `observarPorProducto`, para cualquier producto.
  List<MovimientoInventario> movimientos;

  /// Una entrada por llamada a `registrarEntradaCompra`.
  final List<({int productoId, double cantidad, String? notas})> entradas = [];

  @override
  Stream<List<MovimientoInventario>> observarPorProducto(
    int productoId, {
    int? limite,
  }) =>
      Stream.value(
        limite == null ? movimientos : movimientos.take(limite).toList(),
      );

  @override
  Stream<PaginaMovimientos> observarPagina({
    required FiltroMovimientos filtro,
    required int pagina,
    required int tamano,
  }) =>
      Stream.value(PaginaMovimientos(
        items: [
          for (final m in movimientos)
            MovimientoDetalle(
              movimiento: m,
              productoNombre: 'Producto de prueba',
              productoSku: 'PRU-1',
              usuario: 'Usuario de prueba',
            ),
        ],
        total: movimientos.length,
      ));

  @override
  Future<void> registrarEntradaCompra({
    required int productoId,
    required double cantidad,
    String? notas,
  }) async {
    entradas.add((productoId: productoId, cantidad: cantidad, notas: notas));
  }

  @override
  Future<void> registrar(SolicitudMovimiento solicitud) async {}

  @override
  Future<void> registrarVarios(List<SolicitudMovimiento> solicitudes) async {}

  @override
  Future<double> stockReconstruido(int productoId) async =>
      movimientos.fold<double>(0, (suma, m) => suma + m.cantidad);

  @override
  Future<Map<int, double>> descuadres() async => const {};
}

/// Un movimiento cualquiera, para los tests que miran pantallas.
MovimientoInventario movimientoDePrueba({
  int id = 1,
  int productoId = 1,
  TipoMovimiento tipo = TipoMovimiento.salidaVenta,
  double cantidad = -2,
  String? notas,
  DateTime? creadoEn,
}) =>
    MovimientoInventario(
      id: id,
      productoId: productoId,
      tipo: tipo,
      cantidad: cantidad,
      notas: notas,
      creadoEn: creadoEn ?? DateTime(2026, 8, 20, 10, 30),
    );
