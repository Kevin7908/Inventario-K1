import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/servicios/modelo/servicio.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../provider/catalogo_cotizacion_providers.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Catálogo de servicios del editor, en filas.
///
/// No van en tarjetas como los productos porque un servicio no tiene foto ni
/// categoría: una rejilla de cuadros vacíos ocuparía el triple para decir lo
/// mismo. Un clic en la fila lo agrega a la cotización.
///
/// El precio sugerido es de referencia: la línea nace con él y se puede
/// ajustar en el panel de la derecha sin tocar el catálogo.
class TablaServiciosCotizacion extends ConsumerWidget {
  const TablaServiciosCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicios = ref.watch(serviciosCotizacionProvider(cotizacionId));

    return TablaGenerica<Servicio>(
      items: servicios,
      mensajeVacio: 'Ningún servicio coincide con la búsqueda.',
      alPresionarFila: ref
          .read(cotizacionEditorProvider(cotizacionId).notifier)
          .agregarServicio,
      columnas: [
        ColumnaTabla(
          titulo: 'Servicio',
          flex: 2,
          constructor: (s) => Text(
            s.nombre,
            style: TipografiaApp.cuerpoMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Descripción',
          flex: 3,
          constructor: (s) => Text(
            s.descripcion?.isNotEmpty == true ? s.descripcion! : '—',
            style: TipografiaApp.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Precio sugerido',
          flex: 2,
          alineacion: Alignment.centerRight,
          constructor: (s) => Text(
            s.precioSugerido == 0 ? 'A convenir' : formatearPrecio(s.precioSugerido),
            textAlign: TextAlign.right,
            style: s.precioSugerido == 0
                ? TipografiaApp.deshabilitado(TipografiaApp.caption)
                : TipografiaApp.cuerpoMedium.copyWith(
                    color: ColoresApp.castletonGreen,
                  ),
          ),
        ),
      ],
    );
  }
}
