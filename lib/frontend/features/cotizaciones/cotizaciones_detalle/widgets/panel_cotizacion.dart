import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../share2/share2.dart';
import '../provider/catalogo_cotizacion_providers.dart';
import '../provider/cotizacion_editor_provider.dart';
import 'encabezamiento_cotizacion.dart';
import 'linea_cotizacion.dart';
import 'totales_cotizacion.dart';

/// Panel derecho del editor: la cotización que se está armando.
///
/// Replica el aside de "Venta actual" del diseño: 360 px, borde a la
/// izquierda, cabecera con el contador de ítems, lista scrolleable y pie sobre
/// fondo tenue. Cliente y moto son opcionales: se cotiza a quien entra a
/// preguntar un precio, y muchas veces todavía no es cliente de nadie.
class PanelCotizacion extends ConsumerWidget {
  const PanelCotizacion({
    super.key,
    required this.cotizacionId,
    required this.notasControlador,
    required this.alReservar,
    required this.alImprimir,
  });

  static const double ancho = 360;

  final int? cotizacionId;
  final TextEditingController notasControlador;
  final VoidCallback alReservar;
  final VoidCallback alImprimir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: ancho,
      decoration: const BoxDecoration(
        color: ColoresApp.bgCard,
        border: Border(left: BorderSide(color: ColoresApp.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Cabecera(cotizacionId: cotizacionId),
          Expanded(child: _Lineas(cotizacionId: cotizacionId)),
          _Pie(
            cotizacionId: cotizacionId,
            notasControlador: notasControlador,
            alReservar: alReservar,
            alImprimir: alImprimir,
          ),
        ],
      ),
    );
  }
}

/// Título, contador de ítems y a quién se le cotiza.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      cotizacionEditorProvider(cotizacionId).select((s) => (
            numero: s.value?.numero ?? '',
            cliente: s.value?.cliente?.nombreCompleto,
            items: s.value?.items.length ?? 0,
          )),
    );

    final referencia = datos.numero.isEmpty ? 'Sin guardar' : '#${datos.numero}';
    final aQuien = datos.cliente ?? 'Mostrador';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Cotización actual', style: TipografiaApp.heading3),
              ),
              IndicadorEstado(
                etiqueta: datos.items == 1 ? '1 ítem' : '${datos.items} ítems',
                color: ColoresApp.castletonGreen,
                colorFondo: ColoresApp.statusSuccessBg,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$referencia · Cliente: $aQuien',
            style: TipografiaApp.caption.copyWith(
              fontSize: 12,
              color: ColoresApp.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Las líneas de la cotización. Es lo único del panel que cambia al agregar o
/// quitar algo, así que va en su propio widget.
class _Lineas extends ConsumerWidget {
  const _Lineas({required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = cotizacionEditorProvider(cotizacionId);
    final items = ref.watch(provider.select((s) => s.value?.items ?? const []));

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.request_quote_outlined,
                size: 40,
                color: ColoresApp.textDisabled,
              ),
              SizedBox(height: 12),
              Text(
                'La cotización está vacía',
                textAlign: TextAlign.center,
                style: TipografiaApp.cuerpo,
              ),
              SizedBox(height: 4),
              Text(
                'Toca un producto o un servicio de la izquierda.',
                textAlign: TextAlign.center,
                style: TipografiaApp.caption,
              ),
            ],
          ),
        ),
      );
    }

    final notifier = ref.read(provider.notifier);
    final fotos = ref.watch(imagenPorProductoProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return LineaCotizacion(
          // El tipo y la referencia identifican la línea; el índice solo, no:
          // al borrar una de en medio reutilizaría el estado de la siguiente y
          // el campo de precio mostraría el importe de otra línea.
          key: ValueKey('${item.tipo.valor}-${item.referenciaId}-$i'),
          item: item,
          imagen: item.tipo.esReservable ? fotos[item.referenciaId] : null,
          alCambiarCantidad: (cantidad) => notifier.cambiarCantidad(i, cantidad),
          alCambiarPrecio: (precio) => notifier.cambiarPrecio(i, precio),
          alEliminar: () => notifier.eliminarItem(i),
        );
      },
    );
  }
}

/// Notas, totales y acciones, sobre el fondo tenue del diseño.
class _Pie extends ConsumerWidget {
  const _Pie({
    required this.cotizacionId,
    required this.notasControlador,
    required this.alReservar,
    required this.alImprimir,
  });

  final int? cotizacionId;
  final TextEditingController notasControlador;
  final VoidCallback alReservar;
  final VoidCallback alImprimir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: ColoresApp.bgInput,
        border: Border(top: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezamientoCotizacion(cotizacionId: cotizacionId),
          const SizedBox(height: 14),
          CampoTexto(
            etiqueta: 'Notas',
            controlador: notasControlador,
            placeholder: 'Condiciones, tiempos de entrega…',
            lineas: 2,
            alCambiar: ref
                .read(cotizacionEditorProvider(cotizacionId).notifier)
                .cambiarNotas,
          ),
          const SizedBox(height: 14),
          TotalesCotizacion(cotizacionId: cotizacionId),
          const SizedBox(height: 16),
          BotonPrimario(
            etiqueta: 'Imprimir cotización',
            icono: Icons.print_outlined,
            alPresionar: alImprimir,
          ),
          const SizedBox(height: 10),
          BotonSecundario(
            etiqueta: 'Reservar productos',
            icono: Icons.bookmark_outline_rounded,
            expandido: true,
            alPresionar: alReservar,
          ),
        ],
      ),
    );
  }
}
