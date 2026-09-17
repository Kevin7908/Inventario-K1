import 'package:equatable/equatable.dart';

import '../../../../core/iva_app.dart';

enum EstadoStock { enStock, stockBajo, sinStock }


class Producto extends Equatable {

  final int? id;
  final String sku;

  /// El código de barras del empaque, si lo trae. Es aparte del [sku]: aquel
  /// lo inventa el taller y siempre está, este viene impreso de fábrica y
  /// falta en todo lo que llega a granel.
  final String? codigoBarras;

  final String nombre;
  final String? descripcion;

  final int? categoriaId;
  final int? unidadMedidaId;
  final int? proveedorId;

  // Relaciones — Nombres (solo lectura, vienen del JOIN)
  // No se incluyen en props de Equatable porque no son parte de la identidad
  // del producto; varían si se renombra una categoría sin tocar el producto.
  final String? categoriaNombre;
  final String? unidadMedidaNombre;
  final String? proveedorNombre;

  /// Los tres, en **pesos enteros**. Ver el docstring de `TablaProducto`: el
  /// peso colombiano no tiene decimales y `double` arrastraba error de coma
  /// flotante entre el POS y las cotizaciones.
  final int precioCompra;
  final int precioVenta;
  final int? precioVentaTaller;

  final double stockActual;
  final double stockMinimo;

  final String? ubicacionBodega;
  final String? imagenUrl;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

    const Producto({
    this.id,
    required this.sku,
    this.codigoBarras,
    required this.nombre,
    this.descripcion,
    // FKs (IDs) — se persisten en la tabla
    this.categoriaId,
    this.unidadMedidaId,
    this.proveedorId,
    // Nombres desnormalizados — hidratados por JOIN, nunca por la UI
    this.categoriaNombre,
    this.unidadMedidaNombre,
    this.proveedorNombre,
    // Precios y stock
    required this.precioCompra,
    required this.precioVenta,
    this.precioVentaTaller,
    required this.stockActual,
    required this.stockMinimo,
    // Metadata
    this.ubicacionBodega,
    this.imagenUrl,
    required this.activo,
    this.creadoEn,
    this.actualizadoEn,
  });

  // Equatable
  // La identidad se define por los campos de negocio clave.
  // Los nombres desnormalizados y las fechas NO participan en la igualdad:
  //   • categoriaNombre/proveedorNombre/unidadMedidaNombre → son cache de lectura
  //   • creadoEn/actualizadoEn → metadatos que no definen unicidad
  //
  // Cuando id == null (producto nuevo, no guardado aún), la igualdad cae
  // en sku + nombre, lo que evita duplicados falsos en listas/sets de la UI.
  @override
  List<Object?> get props => [
        id,
        sku,
        nombre,
        descripcion,
        categoriaId,
        unidadMedidaId,
        proveedorId,
        precioCompra,
        precioVenta,
        precioVentaTaller,
        stockActual,
        stockMinimo,
        ubicacionBodega,
        imagenUrl,
        activo,
      ];

  // copyWith
  // Permite actualizar campos individuales sin mutar la instancia original.
  // Los nombres desnormalizados se incluyen para que el repositorio pueda
  // reemplazar los nombres tras un JOIN sin perder los demás datos.
  Producto copyWith({
    int? id,
    String? sku,
    String? codigoBarras,
    String? nombre,
    String? descripcion,
    int? categoriaId,
    int? unidadMedidaId,
    int? proveedorId,
    String? categoriaNombre,
    String? unidadMedidaNombre,
    String? proveedorNombre,
    int? precioCompra,
    int? precioVenta,
    int? precioVentaTaller,
    double? stockActual,
    double? stockMinimo,
    String? ubicacionBodega,
    String? imagenUrl,
    bool? activo,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return Producto(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      categoriaId: categoriaId ?? this.categoriaId,
      unidadMedidaId: unidadMedidaId ?? this.unidadMedidaId,
      proveedorId: proveedorId ?? this.proveedorId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      unidadMedidaNombre: unidadMedidaNombre ?? this.unidadMedidaNombre,
      proveedorNombre: proveedorNombre ?? this.proveedorNombre,
      precioCompra: precioCompra ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      precioVentaTaller: precioVentaTaller ?? this.precioVentaTaller,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      ubicacionBodega: ubicacionBodega ?? this.ubicacionBodega,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  // Getters computados
  // Lógica de dominio pura — no dependen de Flutter ni de la BD.

  /// Estado de stock calculado a partir de stockActual y stockMinimo.
  EstadoStock get estadoStock {
    if (stockActual <= 0) return EstadoStock.sinStock;
    if (stockActual <= stockMinimo) return EstadoStock.stockBajo;
    return EstadoStock.enStock;
  }

  /// Alias booleano para compatibilidad con filtros del ViewModel.
  bool get tieneStockBajo => estadoStock == EstadoStock.stockBajo;

  /// Alias booleano para compatibilidad con filtros del ViewModel.
  bool get sinStock => estadoStock == EstadoStock.sinStock;

  /// Cuánto IVA se le **suma** a [precioVenta], según la tasa global [tasaIva].
  ///
  /// [precioVenta] es la base gravable: el precio del catálogo es lo que vale
  /// la mercancía y el impuesto se agrega al facturar (ver `iva_app.dart`).
  /// Es informativo —para ver en la ficha en cuánto sale con impuesto—; los
  /// documentos lo liquidan sobre su propia base, ya descontada.
  ///
  /// **Ya no hay `aplica_iva` por producto.** La columna existía para poder
  /// marcar exento uno suelto, y en la práctica dejaba dos productos idénticos
  /// facturando distinto según cómo se hubiera creado cada uno. La tasa del
  /// negocio es una sola y se configura en un sitio.
  int get ivaDelPrecio => ivaSobre(precioVenta);

  /// Lo que costaría con el impuesto ya sumado.
  int get precioConIva => precioVenta + ivaDelPrecio;

  /// Margen de ganancia en porcentaje sobre el precio de compra.
  double get margenGanancia => precioCompra > 0
      ? ((precioVenta - precioCompra) / precioCompra) * 100
      : 0;

  @override
  String toString() => 'Producto(id: $id, sku: $sku, nombre: $nombre)';
}