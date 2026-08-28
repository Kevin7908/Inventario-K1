import 'package:drift/drift.dart';

import '../../../share/database/app_db.dart';
import '../modelo/producto.dart';

class ProductoMapper {
  ProductoMapper._(); // clase utilitaria, no instanciar

  static Producto filaAModelo(TablaProductoData fila) {
    return Producto(
      id: fila.id,
      sku: fila.sku,
      nombre: fila.nombre,
      descripcion: fila.descripcion,
      categoriaId: fila.categoriaId,
      unidadMedidaId: fila.unidadMedidaId,
      proveedorId: fila.proveedorId,
      categoriaNombre: null,
      unidadMedidaNombre: null,
      proveedorNombre: null,
      precioCompra: fila.precioCompra,
      precioVenta: fila.precioVenta,
      precioVentaTaller: fila.precioVentaTaller,
      stockActual: fila.stockActual,
      stockMinimo: fila.stockMinimo,
      ubicacionBodega: fila.ubicacionBodega,
      imagenUrl: fila.imagenUrl,
      aplicaIva: fila.aplicaIva,
      activo: fila.activo,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  // Lectura con JOIN
  // Usada por: obtenerTodos, observarTodos, observarConStockBajo,
  //            obtenerActivos, obtenerConStockBajo, obtenerPorCategoria,
  //            obtenerPorProveedor, buscarPorNombreOSku.

  static Producto filaJoinAModelo(TypedResult resultado, AppDb db) {
    final fila = resultado.readTable(db.tablaProducto);

    // Leer tablas opcionales del JOIN — null si la FK no existe
    final categoria = resultado.readTableOrNull(db.tablaCategoria);
    // El proveedor aporta la fila de rol, pero su razón social está en
    // `personas`: por eso se lee esa y no `tablaProveedor`.
    final proveedor = resultado.readTableOrNull(db.tablaPersona);
    final unidad = resultado.readTableOrNull(db.tablaUnidadesMedida);

    return Producto(
      id: fila.id,
      sku: fila.sku,
      nombre: fila.nombre,
      descripcion: fila.descripcion,
      categoriaId: fila.categoriaId,
      unidadMedidaId: fila.unidadMedidaId,
      proveedorId: fila.proveedorId,
      // Nombres hidratados directamente desde SQL — O(N) real
      categoriaNombre: categoria?.nombre,
      unidadMedidaNombre: unidad != null
          ? '${unidad.nombre} (${unidad.abreviatura})'
          : null,
      proveedorNombre: proveedor?.nombres,
      precioCompra: fila.precioCompra,
      precioVenta: fila.precioVenta,
      precioVentaTaller: fila.precioVentaTaller,
      stockActual: fila.stockActual,
      stockMinimo: fila.stockMinimo,
      ubicacionBodega: fila.ubicacionBodega,
      imagenUrl: fila.imagenUrl,
      aplicaIva: fila.aplicaIva,
      activo: fila.activo,
      creadoEn: fila.creadoEn,
      actualizadoEn: fila.actualizadoEn,
    );
  }

  // Escritura
  // Convierte el modelo al Companion de Drift para INSERT / UPDATE.
  // Los nombres desnormalizados (categoriaNombre, proveedorNombre,
  // unidadMedidaNombre) se ignoran explícitamente: no existen en la tabla.
  static TablaProductoCompanion modeloACompanion(Producto p) {
    return TablaProductoCompanion(
      sku: Value(p.sku),
      nombre: Value(p.nombre),
      descripcion: Value(p.descripcion),
      categoriaId: Value(p.categoriaId),
      unidadMedidaId: Value(p.unidadMedidaId),
      proveedorId: Value(p.proveedorId),
      precioCompra: Value(p.precioCompra),
      precioVenta: Value(p.precioVenta),
      precioVentaTaller: Value(p.precioVentaTaller),
      // `stockActual` **no** se escribe desde aquí: el único que lo mueve es
      // `RepositorioInventario`, y lo hace junto al renglón que lo explica.
      // Guardar un producto no puede cambiar el inventario de rebote.
      stockMinimo: Value(p.stockMinimo),
      ubicacionBodega: Value(p.ubicacionBodega),
      imagenUrl: Value(p.imagenUrl),
      aplicaIva: Value(p.aplicaIva),
      activo: Value(p.activo),
      // `creadoEn` solo se manda si ya existe: en el alta lo pone el default
      // de la tabla. `actualizadoEn` se toca en todas las escrituras.
      creadoEn: p.creadoEn == null ? const Value.absent() : Value(p.creadoEn!),
      actualizadoEn: Value(DateTime.now()),
    );
  }
}