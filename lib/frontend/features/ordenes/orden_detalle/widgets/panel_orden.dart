import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../widgets/estado_orden_ui.dart';
import '../modelo/orden_editor_state.dart';
import '../provider/catalogo_orden_providers.dart';
import '../provider/orden_editor_provider.dart';
import 'dialogo_datos_orden.dart';
import 'linea_orden.dart';
import 'totales_orden.dart';

/// Panel derecho del editor: la orden que se está armando.
///
/// Replica el aside de "Venta actual" del diseño: 360 px, borde a la
/// izquierda, cabecera con el contador de ítems, lista scrolleable y pie sobre
/// fondo tenue.
///
/// A diferencia de la cotización, aquí cliente y moto **no son opcionales ni
/// editables desde una lista**: la orden se abrió para una moto concreta y
/// cambiarla a mitad sería otra orden. La ficha los muestra y el diálogo deja
/// corregir el resto de la cabecera.
class PanelOrden extends ConsumerWidget {
  const PanelOrden({
    super.key,
    required this.ordenId,
    required this.alImprimir,
  });

  static const double ancho = 360;

  final int ordenId;
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
          _Cabecera(ordenId: ordenId),
          Expanded(child: _Lineas(ordenId: ordenId)),
          _Pie(ordenId: ordenId, alImprimir: alImprimir),
        ],
      ),
    );
  }
}

/// Título, contador de ítems, estado y la ficha de a quién se le trabaja.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.ordenId});

  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      ordenEditorProvider(ordenId).select((s) => (
            numero: s.value?.numero ?? '',
            cliente: s.value?.clienteNombre ?? '',
            moto: s.value?.motoDescripcion ?? '',
            placa: s.value?.motoPlaca ?? '',
            kilometraje: s.value?.kilometrajeEntrada ?? 0,
            estado: s.value?.estado,
            items: s.value?.lineas.length ?? 0,
          )),
    );

    final estado = datos.estado;
    final subtitulo = [
      if (datos.placa.isNotEmpty) datos.placa,
      '${formatearCantidad(datos.kilometraje.toDouble())} km',
    ].join(' · ');

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
                child: Text('Orden actual', style: TipografiaApp.heading3),
              ),
              IndicadorEstado(
                etiqueta: datos.items == 1 ? '1 ítem' : '${datos.items} ítems',
                color: ColoresApp.castletonGreen,
                colorFondo: ColoresApp.statusSuccessBg,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${datos.numero}',
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (estado != null) BadgeEstadoOrden(estado: estado),
            ],
          ),
          const SizedBox(height: 12),
          FichaResumen(
            titulo: datos.cliente.isEmpty ? 'Sin cliente' : datos.cliente,
            subtitulo: '${datos.moto} · $subtitulo',
            inicial:
                datos.cliente.isEmpty ? null : inicialDe(datos.cliente),
            icono: datos.cliente.isEmpty ? Icons.person_outline : null,
            etiquetaAccion: 'Kilometraje, diagnóstico, estado y observaciones',
            alPresionar: () =>
                DialogoDatosOrden.mostrar(context, ordenId: ordenId),
          ),
        ],
      ),
    );
  }
}

/// Las líneas de la orden, agrupadas por tipo. Es lo único del panel que
/// cambia al agregar o quitar algo, así que va en su propio widget.
///
/// Los tres bloques van separados con su subtotal: mezclados, no había forma
/// de ver de un vistazo cuánto es mano de obra y cuánto repuestos, que es
/// justo lo que se discute con el cliente al entregar.
class _Lineas extends ConsumerWidget {
  const _Lineas({required this.ordenId});

  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ordenEditorProvider(ordenId);
    final lineas =
        ref.watch(provider.select((s) => s.value?.lineas ?? const []));
    final editable = ref.watch(provider.select((s) => s.value?.editable ?? false));

    if (lineas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.build_circle_outlined,
                size: 40,
                color: ColoresApp.textDisabled,
              ),
              SizedBox(height: 12),
              Text(
                'La orden está vacía',
                textAlign: TextAlign.center,
                style: TipografiaApp.cuerpo,
              ),
              SizedBox(height: 4),
              Text(
                'Toca un repuesto o un servicio de la izquierda.',
                textAlign: TextAlign.center,
                style: TipografiaApp.caption,
              ),
            ],
          ),
        ),
      );
    }

    final notifier = ref.read(provider.notifier);
    final fotos = ref.watch(imagenPorProductoOrdenProvider);
    // El `select` de arriba es sobre `lineas`, que conserva identidad mientras
    // no cambien: esta pasada solo corre cuando cambiaron de verdad. La regla
    // de agrupación vive en el estado.
    final grupos = OrdenEditorState.agrupar(lineas);

    // `ListView` concreto y no `.builder`: los grupos son tres como mucho y
    // aplanarlos a índices para el builder obligaría a recalcular a qué grupo
    // pertenece cada fila en cada llamada.
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      children: [
        for (final grupo in grupos) ...[
          _EncabezadoGrupo(grupo: grupo),
          for (final linea in grupo.lineas)
            LineaOrden(
              // Tipo + id: los tres tipos viven en tablas distintas, así que
              // la tarea 3 y el repuesto 3 existen a la vez y solo el id no
              // los distingue.
              key: ValueKey('${linea.tipo.name}-${linea.id}'),
              linea: linea,
              editable: editable,
              imagen: linea.tipo.mueveInventario
                  ? fotos[linea.referenciaId]
                  : null,
              alCambiarCantidad: (cantidad) =>
                  notifier.cambiarCantidad(linea, cantidad),
              alCambiarPrecio: (precio) =>
                  notifier.cambiarPrecio(linea, precio),
              alEliminar: () => unawaited(notifier.eliminarLinea(linea)),
              alMarcarCompletada: (hecha) => unawaited(
                notifier.marcarCompletada(linea, hecha: hecha),
              ),
            ),
        ],
      ],
    );
  }
}

/// Título de un bloque de líneas con su subtotal, como en el diseño: overline
/// tenue a la izquierda, importe a la derecha.
class _EncabezadoGrupo extends StatelessWidget {
  const _EncabezadoGrupo({required this.grupo});

  final GrupoLineasOrden grupo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Icon(
            LineaOrden.iconoDe(grupo.tipo),
            size: 14,
            color: ColoresApp.textMuted,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              grupo.titulo,
              style: TipografiaApp.overline.copyWith(
                color: ColoresApp.textMuted,
              ),
            ),
          ),
          Text(
            formatearPrecio(grupo.subtotal),
            style: TipografiaApp.overline.copyWith(
              color: ColoresApp.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Totales y acciones, sobre el fondo tenue del diseño.
class _Pie extends StatelessWidget {
  const _Pie({required this.ordenId, required this.alImprimir});

  final int ordenId;
  final VoidCallback alImprimir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: ColoresApp.bgInput,
        border: Border(top: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TotalesOrden(ordenId: ordenId),
          const SizedBox(height: 16),
          BotonPrimario(
            etiqueta: 'Imprimir orden',
            icono: Icons.print_outlined,
            alPresionar: alImprimir,
          ),
        ],
      ),
    );
  }
}
