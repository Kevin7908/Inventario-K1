import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_inventario.dart';
import '../../../../core/formato.dart';
import '../../../share2/share2.dart';
import '../provider/inventario_providers.dart';
import 'estilo_movimiento.dart';

/// «Movimientos recientes» de la ficha de un producto: los últimos ocho
/// renglones de su libro mayor.
///
/// Vive en el módulo de inventario y no en `share2` porque observa un provider
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
        AsyncData(value: final lista) when lista.isEmpty => const _SinNada(),
        AsyncData(value: final lista) => _Lista(movimientos: lista),
        AsyncError() => const _SinNada(
            texto: 'No se pudo leer el historial de este producto',
          ),
        _ => const _Cargando(),
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

/// El hueco cuando no hay nada que contar, con el mismo cajón que traía el
/// marcador del diseño.
class _SinNada extends StatelessWidget {
  const _SinNada({this.texto = 'Aún no se registran movimientos'});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return _Caja(
      child: Column(
        children: [
          const Icon(
            Icons.swap_vert_rounded,
            size: 26,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            style: TipografiaApp.caption.copyWith(
              color: ColoresApp.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const _Caja(
      child: SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borderFila),
      ),
      child: Center(child: child),
    );
  }
}
