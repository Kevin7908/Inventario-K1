import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_inventario.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/inventario_providers.dart';
import 'estilo_movimiento.dart';

/// «Movimientos recientes» de la ficha de un producto: los últimos ocho
/// renglones de su libro mayor.
///
/// Vive en el módulo de inventario y no en `share` porque observa un provider
/// y conoce `TipoMovimiento`. La ficha del producto lo importa.
///
/// Parámetros:
/// - [productoId]: de qué producto es el historial.
///
/// Ejemplo:
/// ```dart
/// PanelMovimientosProducto(productoId: producto.id!)
/// ```
class PanelMovimientosProducto extends ConsumerWidget {
  const PanelMovimientosProducto({super.key, required this.productoId});

  final int productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosDeProductoProvider(productoId));

    return PanelSeccion(
      titulo: 'Movimientos recientes',
      child: switch (movimientos) {
        AsyncData(value: final lista) when lista.isEmpty => const _Hueco(),
        AsyncData(value: final lista) => _Lista(movimientos: lista),
        AsyncError() => const _Hueco(
            texto: 'No se pudo leer el historial de este producto',
          ),
        _ => const PanelSinDatos.cargando(),
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.movimientos});

  final List<MovimientoInventario> movimientos;

  @override
  Widget build(BuildContext context) {
    // Son ocho como mucho —el límite lo pone el provider en SQL—, así que una
    // columna concreta es correcta aquí: no hay lista larga que construir.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final movimiento in movimientos)
          _Fila(key: ValueKey(movimiento.id), movimiento: movimiento),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({super.key, required this.movimiento});

  final MovimientoInventario movimiento;

  @override
  Widget build(BuildContext context) {
    final estilo =
        EstiloMovimiento.de(movimiento.tipo, entra: movimiento.entra);
    final notas = movimiento.notas;

    return FilaMovimiento(
      icono: estilo.icono,
      titulo: movimiento.tipo.etiqueta,
      detalle: notas == null || notas.isEmpty
          ? formatearFechaHora(movimiento.creadoEn)
          : '${formatearFecha(movimiento.creadoEn)} · $notas',
      importe: formatearCantidadMovimiento(movimiento.cantidad),
      color: estilo.color,
    );
  }
}

/// El hueco cuando no hay nada que contar. Es [PanelSinDatos] con el ícono
/// del módulo puesto: lo único que esta pantalla decide.
class _Hueco extends StatelessWidget {
  const _Hueco({this.texto = 'Aún no se registran movimientos'});

  final String texto;

  @override
  Widget build(BuildContext context) => PanelSinDatos(
        icono: Icons.swap_vert_rounded,
        texto: texto,
      );
}
