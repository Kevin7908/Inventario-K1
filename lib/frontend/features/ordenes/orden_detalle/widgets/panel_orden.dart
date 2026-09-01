import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/share/dominio/permiso.dart';
import '../../../../../core/formato.dart';
import '../../../../share/share.dart';
import '../../../autenticacion/widgets/si_puede.dart';
import '../../widgets/estado_orden_ui.dart';
import '../modelo/linea_orden_editor.dart';
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
    required this.alCerrarACredito,
  });

  static const double ancho = PanelDocumento.ancho;

  final int ordenId;
  final VoidCallback alImprimir;

  /// Fiar la orden entera. Lo resuelve la vista, que es la que sabe cerrarse
  /// después: la deuda vive en otra pantalla.
  final VoidCallback alCerrarACredito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelDocumento(
      cabecera: _Cabecera(ordenId: ordenId),
      contenido: _Lineas(ordenId: ordenId),
      pie: _Pie(
        ordenId: ordenId,
        alImprimir: alImprimir,
        alCerrarACredito: alCerrarACredito,
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
      return const EstadoVacio(
        icono: Icons.build_circle_outlined,
        titulo: 'La orden está vacía',
        pista: 'Toca un repuesto o un servicio de la izquierda.',
      );
    }

    final notifier = ref.read(provider.notifier);
    final datos = ref.watch(datosProductoOrdenProvider);

    /// Cuánto admite como máximo la línea: lo que queda en bodega **más** lo
    /// que ella ya se llevó, porque eso último salió del estante al anotarlo.
    /// `null` en lo que no mueve inventario y en el producto que no está en el
    /// mapa: sin dato, el control no acota.
    double? topeDe(LineaOrdenEditor linea) {
      if (!linea.tipo.mueveInventario) return null;
      final stock = datos[linea.referenciaId]?.stock;
      return stock == null ? null : stock + linea.cantidad;
    }
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
          EncabezadoGrupoLineas(
            icono: LineaOrden.iconoDe(grupo.tipo),
            titulo: grupo.titulo,
            subtotal: grupo.subtotal,
          ),
          for (final linea in grupo.lineas)
            LineaOrden(
              // Tipo + id: los tres tipos viven en tablas distintas, así que
              // la tarea 3 y el repuesto 3 existen a la vez y solo el id no
              // los distingue.
              key: ValueKey('${linea.tipo.name}-${linea.id}'),
              linea: linea,
              editable: editable,
              imagen: linea.tipo.mueveInventario
                  ? datos[linea.referenciaId]?.imagen
                  : null,
              disponible: topeDe(linea),
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
/// Totales y acciones, sobre el fondo tenue del diseño.
class _Pie extends ConsumerWidget {
  const _Pie({
    required this.ordenId,
    required this.alImprimir,
    required this.alCerrarACredito,
  });

  final int ordenId;
  final VoidCallback alImprimir;
  final VoidCallback alCerrarACredito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fiar una orden vacía abriría una deuda de cero pesos, y una ya cerrada
    // no se fía: el repositorio lo rechaza igual, esto evita el viaje.
    final sePuedeFiar = ref.watch(
      ordenEditorProvider(ordenId).select(
        (s) => (s.value?.editable ?? false) && (s.value?.lineas.isNotEmpty ?? false),
      ),
    );

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
          // Fiar el trabajo entero: abre la deuda con estas mismas líneas y
          // **no vuelve a tocar el inventario**. Esconderlo es orden; la
          // compuerta que vale está en el repositorio (`CLAUDE.md` §7 bis).
          if (sePuedeFiar) ...[
            const SizedBox(height: 10),
            SiPuede(
              permiso: Permiso.deudoresCrear,
              child: BotonSecundario(
                etiqueta: 'Cerrar a crédito',
                icono: Icons.attach_money_rounded,
                expandido: true,
                alPresionar: alCerrarACredito,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
