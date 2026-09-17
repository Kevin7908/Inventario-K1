import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/proveedor_de_producto.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../provider/productos_provider.dart';

/// Los dos gestos que se hacen con un proveedor delante: coronarlo o sacarlo
/// de la lista.
///
/// Viven aquí y no en el panel porque es donde se está mirando **a ese**
/// proveedor: en la lista, un botón por fila multiplicaría por tres los
/// controles de un bloque que casi siempre solo se lee.
///
/// Quitar no borra nada de lo que trajo: las remisiones siguen en Compras, que
/// es donde vive el historial. Lo que se quita es «a este le compro esto».
///
/// Parámetros:
/// - [productoId]: de qué repuesto se está hablando.
/// - [proveedor]: el vínculo que se está mirando.
///
/// Ejemplo:
/// ```dart
/// AccionesProveedorProducto(productoId: id, proveedor: proveedor)
/// ```
class AccionesProveedorProducto extends ConsumerStatefulWidget {
  const AccionesProveedorProducto({
    super.key,
    required this.productoId,
    required this.proveedor,
  });

  final int productoId;
  final ProveedorDeProducto proveedor;

  @override
  ConsumerState<AccionesProveedorProducto> createState() =>
      _AccionesProveedorProductoState();
}

class _AccionesProveedorProductoState
    extends ConsumerState<AccionesProveedorProducto> {
  bool _trabajando = false;

  Future<void> _hacer(Future<Resultado> Function() accion) async {
    setState(() => _trabajando = true);
    final resultado = await accion();
    if (!mounted) return;

    switch (resultado) {
      case Exito():
        Navigator.of(context).pop();
      case Fallo(:final mensaje):
        setState(() => _trabajando = false);
        MensajeApp.error(context, mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositorioProductosProvider);
    final proveedor = widget.proveedor;

    return Row(
      children: [
        SiPuede(
          permiso: Permiso.productosEditar,
          child: BotonDestructivo(
            etiqueta: 'Quitar de la lista',
            icono: Icons.link_off_rounded,
            alPresionar: _trabajando
                ? null
                : () => unawaited(
                      _hacer(
                        () => repo.desvincularProveedor(
                          productoId: widget.productoId,
                          proveedorId: proveedor.proveedorId,
                        ),
                      ),
                    ),
          ),
        ),
        const Spacer(),
        if (!proveedor.esPrincipal)
          SiPuede(
            permiso: Permiso.productosEditar,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: BotonSecundario(
                etiqueta: 'Hacerlo principal',
                icono: Icons.star_outline_rounded,
                alPresionar: _trabajando
                    ? null
                    : () => unawaited(
                          _hacer(
                            () => repo.fijarProveedorPrincipal(
                              productoId: widget.productoId,
                              proveedorId: proveedor.proveedorId,
                            ),
                          ),
                        ),
              ),
            ),
          ),
        BotonSecundario(
          etiqueta: 'Cerrar',
          alPresionar: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
