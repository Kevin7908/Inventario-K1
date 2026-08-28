import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/ordenes/modelo/orden_resumen.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../provider/ordenes_providers.dart';
import 'estado_orden_ui.dart';

/// La tabla del listado de órdenes, con las seis columnas del diseño.
///
/// Los anchos son los `grid-template-columns: 1fr 2fr 1.3fr 1fr 1fr 1fr` del
/// mockup, traducidos a `flex`. Como `flex` es entero, van multiplicados por
/// diez: 1.3 no se puede expresar de otro modo y redondearlo a 1 le quitaba
/// sitio al nombre del técnico.
///
/// Es la única parte de la pantalla que observa los datos: así el encabezado,
/// el buscador y las tarjetas no se reconstruyen al cambiar de página.
///
/// Recibe **una página**, no el listado: el `WHERE`, el `COUNT` y el `LIMIT`
/// los resolvió SQLite (§5 de `REGLAS_BD.md`).
class TablaOrdenes extends ConsumerWidget {
  const TablaOrdenes({super.key, required this.alAbrir});

  final ValueChanged<OrdenResumen> alAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(ordenesProvider);

    if (estadoAsync.hasError) {
      return Center(
        child: Text(
          'Error al cargar las órdenes: ${estadoAsync.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    final ordenes = ref.watch(ordenesPaginaProvider);

    if (estadoAsync.isLoading && ordenes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final pagina = ref.watch(
      ordenesProvider.select((s) => (
            actual: s.value?.pagina ?? 0,
            total: s.value?.total ?? 0,
            paginas: s.value?.totalPaginas ?? 1,
            tamano: s.value?.tamanoPagina ?? 12,
            hayFiltro: s.value?.hayFiltro ?? false,
          )),
    );

    return Column(
      children: [
        // `Expanded`: la tabla tiene encabezado fijo y exige altura acotada.
        Expanded(child: _tabla(ordenes, pagina.hayFiltro)),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(ordenesProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }

  Widget _tabla(List<OrdenResumen> ordenes, bool hayFiltro) {
    return TablaGenerica<OrdenResumen>(
      items: ordenes,
      alPresionarFila: alAbrir,
      mensajeVacio: hayFiltro
          ? 'No hay órdenes que coincidan'
          : 'Aún no hay órdenes. Crea la primera con "Nueva orden".',
      columnas: [
        ColumnaTabla(
          titulo: 'Orden',
          flex: 10,
          constructor: (o) => Text(
            o.numeroOrden,
            // Monoespaciada como en el diseño: los consecutivos se comparan de
            // un vistazo cuando los dígitos van alineados.
            style: TipografiaApp.cuerpoMedium.copyWith(
              fontSize: 13,
              fontFamily: 'monospace',
              fontFamilyFallback: const ['RobotoMono', 'Courier'],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Cliente / Moto',
          flex: 20,
          constructor: (o) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                o.clienteNombre,
                style: TipografiaApp.cuerpoMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                o.motoDescripcion,
                style: TipografiaApp.caption.copyWith(
                  fontSize: 12,
                  color: ColoresApp.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        ColumnaTabla(
          titulo: 'Técnico',
          flex: 13,
          constructor: (o) => Text(
            o.tecnicoParaListado,
            style: TipografiaApp.cuerpo.copyWith(
              fontSize: 13,
              color: ColoresApp.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Fecha',
          flex: 10,
          constructor: (o) => Text(
            o.fechaIngreso == null ? '—' : formatearFecha(o.fechaIngreso!),
            style: TipografiaApp.caption.copyWith(
              color: ColoresApp.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Estado',
          flex: 10,
          constructor: (o) => BadgeEstadoOrden(estado: o.estado),
        ),
        ColumnaTabla(
          titulo: 'Total',
          flex: 10,
          alineacion: Alignment.centerRight,
          constructor: (o) => Text(
            formatearPrecio(o.total),
            style: TipografiaApp.cuerpoMedium.copyWith(
              color: ColoresApp.castletonGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
