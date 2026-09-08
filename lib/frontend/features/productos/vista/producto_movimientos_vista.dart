import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_detalle.dart';
import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share/share.dart';
import '../../inventario/provider/inventario_providers.dart';
import '../../inventario/widgets/columnas_tabla_movimiento.dart';

/// Todo lo que le ha pasado al stock de un repuesto.
///
/// Es a donde lleva el «Ver todos» de la ficha: el panel de ahí enseña los tres
/// últimos movimientos y esta pantalla, el libro mayor entero de esa pieza,
/// paginado.
///
/// **Vive en el módulo de Productos y no en el de Movimientos**, aunque la
/// tabla sea la misma. La navegación de la app es un `IndexedStack` sin router,
/// así que saltar de la ficha a otra sección no tendría vuelta atrás; y la
/// pantalla de Movimientos tiene sus propios filtros puestos por quien la esté
/// mirando, que abrir una ficha no puede cambiarle por debajo. Lo que sí se
/// comparte son las columnas (`columnasTablaMovimiento`), para que las dos
/// digan lo mismo.
///
/// La columna «Producto» se omite: todas las filas son del mismo repuesto y
/// repetir su nombre quince veces solo quita ancho a lo que sí cambia.
///
/// Parámetros:
/// - [producto]: de quién es el historial. Se recibe entero y no solo el id
///   para poder titular la pantalla sin otra consulta.
/// - [alVolver]: cómo se regresa a la ficha.
///
/// Ejemplo:
/// ```dart
/// ProductoMovimientosVista(producto: producto, alVolver: _cerrarKardex)
/// ```
class ProductoMovimientosVista extends ConsumerWidget {
  const ProductoMovimientosVista({
    super.key,
    required this.producto,
    required this.alVolver,
    this.padding = const EdgeInsets.fromLTRB(32, 24, 32, 24),
  });

  final Producto producto;
  final VoidCallback alVolver;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = kardexProductoProvider(producto.id!);
    final pagina = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BotonVolver(etiqueta: 'Volver a la ficha', alPresionar: alVolver),
          const SizedBox(height: 18),
          _Encabezado(producto: producto, total: pagina.value?.total ?? 0),
          const SizedBox(height: 18),
          // `Expanded` y no un `SingleChildScrollView`: `TablaGenerica` tiene
          // encabezado fijo y exige padre acotado (`CLAUDE.md` §4).
          Expanded(
            child: switch (pagina) {
              AsyncData(value: final datos) when datos.items.isEmpty =>
                const _Vacio(),
              AsyncData(value: final datos) => TablaGenerica<MovimientoDetalle>(
                  items: datos.items,
                  columnas: columnasTablaMovimiento(mostrarProducto: false),
                ),
              AsyncError(:final error) => EstadoVacio(
                  icono: Icons.error_outline,
                  titulo: 'No se pudo leer el historial',
                  pista: '$error',
                ),
              _ => const Center(
                  child: CircularProgressIndicator(color: ColoresApp.goGreen),
                ),
            },
          ),
          if (pagina.value case final datos?
              when datos.total > KardexProductoNotifier.tamanoPagina) ...[
            const SizedBox(height: 14),
            PaginacionWidget(
              paginaActual: notifier.pagina,
              totalPaginas:
                  (datos.total + KardexProductoNotifier.tamanoPagina - 1) ~/
                      KardexProductoNotifier.tamanoPagina,
              totalItems: datos.total,
              itemsPorPagina: KardexProductoNotifier.tamanoPagina,
              alCambiarPagina: notifier.irAPagina,
            ),
          ],
        ],
      ),
    );
  }
}

/// De qué repuesto es el historial y cuántos renglones tiene.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.producto, required this.total});

  final Producto producto;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Movimientos de ${producto.nombre}',
                style: TipografiaApp.heading2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'SKU ${producto.sku}',
                style: TipografiaApp.monoespaciada(
                  TipografiaApp.caption.copyWith(
                    color: ColoresApp.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IndicadorEstado(
          etiqueta: total == 1 ? '1 movimiento' : '$total movimientos',
          color: ColoresApp.castletonGreen,
          colorFondo: ColoresApp.greenChipBg,
        ),
      ],
    );
  }
}

/// Un repuesto recién dado de alta con stock en cero no tiene ni el ajuste
/// inicial: no es un error, es que todavía no ha pasado nada.
class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) => const EstadoVacio(
        icono: Icons.swap_vert_rounded,
        titulo: 'Aún no se registran movimientos',
        pista: 'Aquí aparecerá cada entrada y cada salida de este repuesto.',
      );
}
