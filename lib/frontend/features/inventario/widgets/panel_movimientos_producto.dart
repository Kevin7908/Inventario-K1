import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_inventario.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/inventario_providers.dart';
import 'estilo_movimiento.dart';

/// «Movimientos recientes» de la ficha de un producto: los últimos renglones
/// de su libro mayor.
///
/// **Enseña tres, no ocho.** Ocho llenaban media ficha con lo que casi siempre
/// es la misma venta repetida, y empujaban hacia abajo lo que sí se mira de un
/// vistazo. Tres alcanzan para saber si el stock se movió hoy; el resto está a
/// un clic, en el kardex completo del repuesto.
///
/// El límite de la consulta sigue siendo el del provider —el recorte lo hace
/// SQL, no la vista—; lo que decide este widget es cuántos de esos pinta.
///
/// Vive en el módulo de inventario y no en `share` porque observa un provider
/// y conoce `TipoMovimiento`. La ficha del producto lo importa.
///
/// Parámetros:
/// - [productoId]: de qué producto es el historial.
/// - [alVerTodos]: qué hacer con «Ver todos». En `null` el botón no aparece,
///   que es como se usa dentro del diálogo de vistazo rápido, donde no hay a
///   dónde navegar.
/// - [maximo]: cuántos renglones se pintan.
///
/// Ejemplo:
/// ```dart
/// PanelMovimientosProducto(
///   productoId: producto.id!,
///   alVerTodos: () => abrirKardex(producto),
/// )
/// ```
class PanelMovimientosProducto extends ConsumerWidget {
  const PanelMovimientosProducto({
    super.key,
    required this.productoId,
    this.alVerTodos,
    this.maximo = 3,
  });

  final int productoId;
  final VoidCallback? alVerTodos;
  final int maximo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosDeProductoProvider(productoId));
    final hayMas = (movimientos.value?.length ?? 0) > maximo;

    return PanelSeccion(
      titulo: 'Movimientos recientes',
      // El botón solo aparece si hay algo más que ver: con dos movimientos,
      // «Ver todos» lleva a la misma lista que ya está en pantalla.
      accion: alVerTodos == null || !hayMas
          ? null
          : BotonSecundario(
              etiqueta: 'Ver todos',
              icono: Icons.arrow_forward_rounded,
              alPresionar: alVerTodos,
            ),
      child: switch (movimientos) {
        AsyncData(value: final lista) when lista.isEmpty => const _Hueco(),
        AsyncData(value: final lista) =>
          _Lista(movimientos: lista.take(maximo).toList()),
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
    // Son tres como mucho —el widget ya recortó—, así que una columna concreta
    // es correcta aquí: no hay lista larga que construir.
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
