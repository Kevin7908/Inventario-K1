import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/enum/enum_compras.dart';
import '../../../../backend/features/compras/modelo/compra_resumen.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/compras_providers.dart';

/// Color de cada estado de una compra, en un solo sitio.
///
/// Conoce `EstadoCompra`, que es dominio, así que no cabe en share.
({Color color, Color fondo}) colorDeEstadoCompra(EstadoCompra estado) =>
    switch (estado) {
      EstadoCompra.registrada => (
          color: ColoresApp.statusSuccess,
          fondo: ColoresApp.statusSuccessBg,
        ),
      EstadoCompra.anulada => (
          color: ColoresApp.statusDanger,
          fondo: ColoresApp.statusDangerBg,
        ),
    };

/// La tabla de compras: cuándo llegó, de quién, con qué factura y cuánto
/// costó.
///
/// Observa `comprasPaginaProvider` ella sola para que escribir en el buscador
/// no reconstruya el encabezado ni los filtros (`CLAUDE.md` §3).
class TablaCompras extends ConsumerWidget {
  const TablaCompras({
    super.key,
    required this.alLimpiarFiltros,
    required this.alAbrir,
  });

  final VoidCallback alLimpiarFiltros;

  /// Abrir la remisión lleva a su ficha, que es donde se trabaja. La
  /// navegación la resuelve la pantalla: la tabla solo avisa.
  final ValueChanged<int> alAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compras = ref.watch(comprasPaginaProvider);
    final hayFiltro = ref.watch(comprasProvider).value?.hayFiltro ?? false;

    if (compras.isEmpty) {
      return _Vacio(hayFiltro: hayFiltro, alLimpiarFiltros: alLimpiarFiltros);
    }

    return TablaGenerica<CompraResumen>(
      items: compras,
      alPresionarFila: (compra) => alAbrir(compra.id),
      columnas: [
        ColumnaTabla<CompraResumen>(
          titulo: 'Cuándo llegó',
          flex: 2,
          constructor: (c) => Text(
            formatearFecha(c.fecha),
            style: TipografiaApp.cuerpo,
          ),
        ),
        ColumnaTabla<CompraResumen>(
          titulo: 'Remisión',
          flex: 2,
          constructor: (c) => _Numeros(compra: c),
        ),
        ColumnaTabla<CompraResumen>(
          titulo: 'Proveedor',
          flex: 3,
          constructor: (c) => Text(
            c.proveedorNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TipografiaApp.cuerpo,
          ),
        ),
        ColumnaTabla<CompraResumen>(
          titulo: 'Líneas',
          flex: 1,
          constructor: (c) => Text(
            '${c.lineas}',
            style:
                TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
          ),
        ),
        ColumnaTabla<CompraResumen>(
          titulo: 'Estado',
          flex: 2,
          constructor: (c) => IndicadorEstado(
            etiqueta: c.estado.etiqueta,
            color: colorDeEstadoCompra(c.estado).color,
            colorFondo: colorDeEstadoCompra(c.estado).fondo,
          ),
        ),
        ColumnaTabla<CompraResumen>(
          titulo: 'Costó',
          flex: 2,
          alineacion: Alignment.centerRight,
          constructor: (c) => Text(
            formatearPrecio(c.total),
            style: TipografiaApp.cuerpoMedium.copyWith(
              color: c.anulada
                  ? ColoresApp.textDisabled
                  : ColoresApp.castletonGreen,
              decoration: c.anulada ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Los dos números que tiene una remisión: el del taller y el del proveedor.
/// Van juntos porque cada uno sirve para una cosa —archivar y reclamar—.
class _Numeros extends StatelessWidget {
  const _Numeros({required this.compra});

  final CompraResumen compra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(compra.numero, style: TipografiaApp.cuerpoMedium),
        Text(
          compra.numeroFactura ?? 'Sin factura',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TipografiaApp.caption.copyWith(
            color: compra.numeroFactura == null
                ? ColoresApp.textDisabled
                : ColoresApp.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayFiltro, required this.alLimpiarFiltros});

  final bool hayFiltro;
  final VoidCallback alLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    if (hayFiltro) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EstadoVacio(
            icono: Icons.search_off_rounded,
            titulo: 'Ninguna compra cumple el filtro',
            pista: 'Prueba con otro proveedor o con otro rango de fechas.',
          ),
          TextButton(
            onPressed: alLimpiarFiltros,
            child: Text(
              'Quitar los filtros',
              style: TipografiaApp.enlace(TipografiaApp.caption),
            ),
          ),
        ],
      );
    }

    return const EstadoVacio(
      icono: Icons.local_shipping_outlined,
      titulo: 'Todavía no hay compras registradas',
      pista: 'Registra la remisión del proveedor y su costo entra al '
          'inventario.',
    );
  }
}
