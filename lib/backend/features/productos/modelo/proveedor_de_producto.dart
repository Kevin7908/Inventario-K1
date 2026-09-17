import 'package:equatable/equatable.dart';

/// Uno de los proveedores que le venden un repuesto al taller, ya resuelto
/// con su nombre.
///
/// Es la fila de `producto_proveedores` más lo que hace falta para pintarla
/// sin volver a consultar: el nombre del proveedor y su teléfono, que es lo
/// que se necesita cuando la ficha responde «¿a quién le pido esto?».
///
/// [ultimoCosto] es a cómo lo dejó **ese** proveedor la última vez. Es lo que
/// permite comparar antes de pedir, que es la razón de que la tabla exista:
/// con la columna única de antes, cada remisión pisaba el costo anterior y no
/// quedaba con qué comparar.
class ProveedorDeProducto extends Equatable {
  const ProveedorDeProducto({
    required this.id,
    required this.productoId,
    required this.proveedorId,
    required this.proveedorNombre,
    this.proveedorTelefono,
    this.referenciaProveedor,
    this.ultimoCosto = 0,
    this.fechaUltimaCompra,
    this.esPrincipal = false,
  });

  /// El id del vínculo, no el del proveedor.
  final int id;

  final int productoId;
  final int proveedorId;
  final String proveedorNombre;
  final String? proveedorTelefono;

  /// El código con el que ese proveedor llama a la pieza. No es el SKU del
  /// taller: es lo que hay que decirle para que mande la correcta.
  final String? referenciaProveedor;

  final int ultimoCosto;
  final DateTime? fechaUltimaCompra;
  final bool esPrincipal;

  /// `true` si alguna vez se le compró por remisión. Sin esto, un costo en 0
  /// se lee como «me lo regala» en vez de «nunca le he comprado».
  bool get tieneCompras => fechaUltimaCompra != null;

  @override
  List<Object?> get props => [
        id,
        productoId,
        proveedorId,
        proveedorNombre,
        proveedorTelefono,
        referenciaProveedor,
        ultimoCosto,
        fechaUltimaCompra,
        esPrincipal,
      ];
}
