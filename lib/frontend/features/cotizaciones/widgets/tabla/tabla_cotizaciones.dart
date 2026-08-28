import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../../provider/cotizaciones_provider.dart';
import '../estado_cotizacion_ui.dart';

/// Listado paginado de cotizaciones.
///
/// Vive aparte de la vista porque es la única parte de la pantalla que observa
/// los datos: así el encabezado, el buscador y los chips no se reconstruyen al
/// cambiar de página.
class TablaCotizaciones extends ConsumerStatefulWidget {
  const TablaCotizaciones({super.key, required this.alAbrir});

  final ValueChanged<CotizacionResumen> alAbrir;

  @override
  ConsumerState<TablaCotizaciones> createState() => _TablaCotizacionesState();
}

class _TablaCotizacionesState extends ConsumerState<TablaCotizaciones> {
  Future<void> _eliminar(CotizacionResumen cotizacion) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar la cotización ${cotizacion.numero}?',
      mensaje: 'Se borrarán también sus líneas. Esta acción no se puede '
          'deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final resultado =
        await ref.read(cotizacionesProvider.notifier).eliminar(cotizacion.id);
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensaje,
            style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
          ),
          backgroundColor: ColoresApp.statusDanger,
        ),
      );
    }
  }

  /// Los `flex` replican la grilla del mockup (`1fr 1.6fr 1fr 1fr 1fr 1fr`).
  /// La séptima columna no está en el diseño: es la papelera, y se conserva
  /// porque sin ella no habría forma de borrar una cotización.
  List<ColumnaTabla<CotizacionResumen>> get _columnas => [
        ColumnaTabla(
          titulo: 'Código',
          flex: 10,
          constructor: (c) => Text(
            c.numero,
            style: TipografiaApp.monoespaciada(
              TipografiaApp.cuerpoMedium.copyWith(fontSize: 13),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Cliente',
          flex: 16,
          constructor: (c) => Text(
            c.nombreCliente,
            style: TipografiaApp.cuerpoMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Fecha',
          flex: 10,
          constructor: (c) => Text(
            formatearFecha(c.creadoEn),
            style: TipografiaApp.caption,
          ),
        ),
        ColumnaTabla(
          titulo: 'Ítems',
          flex: 10,
          constructor: (c) => Text(
            '${c.cantidadItems}',
            style: TipografiaApp.caption.copyWith(fontSize: 13),
          ),
        ),
        ColumnaTabla(
          titulo: 'Estado',
          flex: 10,
          constructor: (c) => Align(
            alignment: Alignment.centerLeft,
            child: IndicadorEstado(
              etiqueta: c.estado.etiqueta,
              color: c.estado.color,
              colorFondo: c.estado.colorFondo,
            ),
          ),
        ),
        ColumnaTabla(
          titulo: 'Total',
          flex: 10,
          alineacion: Alignment.centerRight,
          constructor: (c) => Text(
            formatearPrecio(c.total),
            textAlign: TextAlign.right,
            style: TipografiaApp.cuerpoMedium.copyWith(
              color: ColoresApp.castletonGreen,
            ),
          ),
        ),
        ColumnaTabla(
          titulo: '',
          ancho: 44,
          alineacion: Alignment.centerRight,
          constructor: (c) => BotonIcono(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar cotización',
            color: ColoresApp.statusDanger,
            alPresionar: () => _eliminar(c),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(cotizacionesProvider);

    if (estadoAsync.isLoading && !estadoAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      );
    }
    if (estadoAsync.hasError && !estadoAsync.hasValue) {
      return Center(
        child: Text(
          'Error al cargar las cotizaciones: ${estadoAsync.error}',
          style: TipografiaApp.cuerpo,
        ),
      );
    }

    final cotizaciones = ref.watch(cotizacionesPaginaProvider);
    final pagina = ref.watch(
      cotizacionesProvider.select((s) => (
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
        Expanded(
          child: TablaGenerica<CotizacionResumen>(
            items: cotizaciones,
            columnas: _columnas,
            alPresionarFila: widget.alAbrir,
            mensajeVacio: pagina.hayFiltro
                ? 'Ninguna cotización coincide con el filtro.'
                : 'Aún no hay cotizaciones. Crea la primera con "Nueva '
                    'cotización".',
          ),
        ),
        if (pagina.paginas > 1)
          PaginacionWidget(
            paginaActual: pagina.actual,
            totalPaginas: pagina.paginas,
            totalItems: pagina.total,
            itemsPorPagina: pagina.tamano,
            alCambiarPagina: (p) =>
                ref.read(cotizacionesProvider.notifier).irAPagina(p),
          ),
      ],
    );
  }
}
