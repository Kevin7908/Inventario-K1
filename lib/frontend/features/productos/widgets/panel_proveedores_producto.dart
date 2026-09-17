import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/productos/modelo/proveedor_de_producto.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/productos_provider.dart';
import '../../autenticacion/widgets/si_puede.dart';
import 'dialogo_compras_proveedor.dart';
import 'dialogo_vincular_proveedor.dart';

/// «Quién me lo vende», con el último costo de cada uno.
///
/// Sustituye a los dos bloques que había antes en la ficha —«Proveedor», que
/// enseñaba uno solo, y «Última compra», que enseñaba una sola— porque los dos
/// respondían a medias la única pregunta que se hace mirando esto: **a quién
/// le pido esta pieza y a cómo me la deja**. Con una columna por producto, la
/// segunda remisión borraba el precio de la primera y no quedaba con qué
/// comparar.
///
/// Tocar un proveedor abre todas las veces que trajo este repuesto, que es lo
/// que dice si subió.
///
/// Vive en el módulo de Productos y no en `share` porque observa un provider y
/// conoce el modelo de dominio, que es la misma regla de
/// `PanelMovimientosProducto`.
///
/// Parámetros:
/// - [productoId]: de qué producto es la ficha.
///
/// Ejemplo:
/// ```dart
/// PanelProveedoresProducto(productoId: producto.id!)
/// ```
class PanelProveedoresProducto extends ConsumerWidget {
  const PanelProveedoresProducto({super.key, required this.productoId});

  final int productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedores = ref.watch(proveedoresDeProductoProvider(productoId));

    // Agregar uno es orden, no control: la compuerta que vale está en
    // `vincularProveedor`. Esto evita ofrecer un gesto que el repositorio va
    // a rechazar.
    final agregar = SiPuede(
      permiso: Permiso.productosEditar,
      child: BotonSecundario(
        etiqueta: 'Agregar',
        icono: Icons.add,
        alPresionar: () => unawaited(
          DialogoVincularProveedor.mostrar(
            context,
            productoId: productoId,
            yaVinculados: {
              for (final p in proveedores.value ?? const []) p.proveedorId,
            },
          ),
        ),
      ),
    );

    return PanelSeccion(
      titulo: 'Quién me lo vende',
      accion: agregar,
      child: switch (proveedores) {
        AsyncData(value: final lista) when lista.isEmpty => const _Hueco(),
        AsyncData(value: final lista) =>
          _Lista(productoId: productoId, proveedores: lista),
        AsyncError() => const _Hueco(
            texto: 'No se pudo leer la lista de proveedores',
          ),
        _ => const PanelSinDatos.cargando(),
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.productoId, required this.proveedores});

  final int productoId;
  final List<ProveedorDeProducto> proveedores;

  @override
  Widget build(BuildContext context) {
    // Son los proveedores de un repuesto: tres o cuatro. Una columna concreta
    // es correcta y evita el alto acotado que pediría un `builder`.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final proveedor in proveedores)
          Padding(
            key: ValueKey(proveedor.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _Fila(productoId: productoId, proveedor: proveedor),
          ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.productoId, required this.proveedor});

  final int productoId;
  final ProveedorDeProducto proveedor;

  @override
  Widget build(BuildContext context) {
    // Un costo en 0 sin compras no es «me lo regala»: es que nunca se le ha
    // comprado por remisión, y hay que decirlo así.
    final costo = proveedor.tieneCompras
        ? '${formatearPrecio(proveedor.ultimoCosto)} · '
            'última compra ${formatearHaceCuanto(proveedor.fechaUltimaCompra!)}'
        : 'Sin remisiones registradas todavía';

    final referencia = (proveedor.referenciaProveedor ?? '').trim();

    // «Principal» va en el subtítulo y no en `etiquetaAccion`: ese parámetro
    // de `FichaResumen` es el tooltip —dice qué pasa al tocar— y no se pinta.
    return FichaResumen(
      titulo: proveedor.proveedorNombre,
      subtitulo: [
        if (proveedor.esPrincipal) 'Principal',
        costo,
        if (referencia.isNotEmpty) 'Ref. $referencia',
      ].join('  ·  '),
      inicial: inicialDe(proveedor.proveedorNombre),
      etiquetaAccion: 'Ver lo que ha traído de este repuesto',
      iconoAccion: Icons.receipt_long_outlined,
      alPresionar: () => DialogoComprasProveedor.mostrar(
        context,
        productoId: productoId,
        proveedor: proveedor,
      ),
    );
  }
}

class _Hueco extends StatelessWidget {
  const _Hueco({this.texto = 'Todavía no se le compra a nadie'});

  final String texto;

  @override
  Widget build(BuildContext context) => PanelSinDatos(
        icono: Icons.local_shipping_outlined,
        texto: texto,
      );
}
