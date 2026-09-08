import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_detalle.dart';
import '../../../share/share.dart';
import '../provider/inventario_providers.dart';
import 'columnas_tabla_movimiento.dart';

/// El libro mayor: cuándo se movió, qué producto, por qué, cuánto y quién.
///
/// Observa `movimientosPaginaProvider` ella sola para que escribir en el
/// buscador no reconstruya el encabezado ni los filtros (`CLAUDE.md` §3).
class TablaMovimientos extends ConsumerWidget {
  const TablaMovimientos({super.key, required this.alLimpiarFiltros});

  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosPaginaProvider);
    final hayFiltro = ref.watch(movimientosProvider).value?.hayFiltro ?? false;

    if (movimientos.isEmpty) {
      return _Vacio(hayFiltro: hayFiltro, alLimpiarFiltros: alLimpiarFiltros);
    }

    return TablaGenerica<MovimientoDetalle>(
      items: movimientos,
      columnas: columnasTablaMovimiento(),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayFiltro, required this.alLimpiarFiltros});

  final bool hayFiltro;
  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    if (!hayFiltro) {
      return const EstadoVacio(
        icono: Icons.swap_vert_rounded,
        titulo: 'Todavía no se ha movido nada',
        pista: 'Cada venta, ajuste o entrada de mercancía deja aquí su '
            'renglón.',
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const EstadoVacio(
          icono: Icons.filter_alt_off_outlined,
          titulo: 'Ningún movimiento con esos filtros',
          pista: 'Prueba con otro rango de fechas o quita el tipo.',
        ),
        BotonSecundario(
          etiqueta: 'Quitar los filtros',
          icono: Icons.close_rounded,
          alPresionar: alLimpiarFiltros,
        ),
      ],
    );
  }
}
