import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/compras/enum/enum_compras.dart';
import '../../../../../backend/features/compras/modelo/compra_item.dart';
import '../../../../../backend/share/dominio/permiso.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../../../autenticacion/widgets/si_puede.dart';
import '../../../documentos/provider/documentos_providers.dart';
import '../../../documentos/traductores/compra_a_documento.dart';
import '../../../documentos/widgets/dialogo_vista_previa.dart';
import '../../provider/compras_providers.dart';
import '../../widgets/estado_compra_ui.dart';
import '../provider/compra_editor_provider.dart';
import 'dialogo_datos_compra.dart';
import 'linea_compra.dart';

/// Panel derecho de la ficha: la remisión que se está armando.
///
/// Replica el aside de «Venta actual» del diseño: 360 px, borde a la
/// izquierda, cabecera con el contador de líneas, lista scrolleable y pie
/// sobre fondo tenue. Lo que cambia respecto de los otros cuatro editores es
/// el signo: aquí el pie no cobra, **anula**.
class PanelCompra extends ConsumerWidget {
  const PanelCompra({super.key, required this.compraId});

  static const double ancho = PanelDocumento.ancho;

  final int compraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelDocumento(
      cabecera: _Cabecera(compraId: compraId),
      contenido: _Lineas(compraId: compraId),
      pie: _Pie(compraId: compraId),
    );
  }
}

/// Título, contador de líneas, estado y de quién llegó la mercancía.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.compraId});

  final int compraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      compraEditorProvider(compraId).select((s) => (
            numero: s.value?.numero ?? '',
            proveedor: s.value?.proveedorNombre ?? '',
            factura: s.value?.numeroFactura,
            fecha: s.value?.fecha,
            estado: s.value?.estado,
            lineas: s.value?.lineas.length ?? 0,
          )),
    );

    final subtitulo = [
      if (datos.fecha != null) 'llegó el ${formatearFecha(datos.fecha!)}',
      datos.factura == null ? 'sin factura' : 'factura ${datos.factura}',
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
                child: Text('Lo que llegó', style: TipografiaApp.heading3),
              ),
              IndicadorEstado(
                etiqueta:
                    datos.lineas == 1 ? '1 línea' : '${datos.lineas} líneas',
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
                  datos.numero,
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 12,
                    color: ColoresApp.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // El estado siempre a la vista: mientras sea borrador, lo que
              // el usuario tiene que ver es que **falta darla por terminada**.
              if (datos.estado != null) BadgeEstadoCompra(estado: datos.estado!),
            ],
          ),
          const SizedBox(height: 12),
          FichaResumen(
            titulo: datos.proveedor.isEmpty ? 'Sin proveedor' : datos.proveedor,
            subtitulo: subtitulo,
            inicial:
                datos.proveedor.isEmpty ? null : inicialDe(datos.proveedor),
            icono: datos.proveedor.isEmpty ? Icons.local_shipping_outlined : null,
            etiquetaAccion: 'Proveedor, factura, fecha y notas',
            alPresionar: () =>
                DialogoDatosCompra.mostrar(context, compraId: compraId),
          ),
        ],
      ),
    );
  }
}

/// Las líneas de la remisión.
class _Lineas extends ConsumerWidget {
  const _Lineas({required this.compraId});

  final int compraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = compraEditorProvider(compraId);
    final lineas = ref.watch(
      provider.select((s) => s.value?.lineas ?? const <CompraItem>[]),
    );
    final editable =
        ref.watch(provider.select((s) => s.value?.editable ?? false));

    if (lineas.isEmpty) {
      return const EstadoVacio(
        icono: Icons.local_shipping_outlined,
        titulo: 'Todavía no has anotado nada',
        pista: 'Toca un producto de la izquierda y ponle su costo.',
      );
    }

    final notifier = ref.read(provider.notifier);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      itemCount: lineas.length,
      itemBuilder: (context, i) {
        final linea = lineas[i];
        return LineaCompra(
          key: ValueKey(linea.id),
          descripcion: linea.descripcion,
          sku: linea.sku,
          imagen: linea.imagenUrl,
          cantidad: linea.cantidad,
          costoUnitario: linea.costoUnitario,
          editable: editable,
          alCambiarCantidad: (cantidad) =>
              notifier.cambiarCantidad(linea, cantidad),
          alCambiarCosto: (costo) => notifier.cambiarCosto(linea, costo),
          alEliminar: () => unawaited(notifier.eliminarLinea(linea)),
        );
      },
    );
  }
}

/// El total de la remisión y los dos gestos que la cierran: darla por
/// terminada —que es lo normal— o anularla.
class _Pie extends ConsumerWidget {
  const _Pie({required this.compraId});

  final int compraId;

  /// Dar por terminada es archivar: a partir de ahí no admite más líneas y
  /// cuenta como gasto del mes. Se avisa con el total porque es la cifra que
  /// queda escrita.
  Future<void> _terminar(BuildContext context, WidgetRef ref) async {
    final resultado =
        await ref.read(compraEditorProvider(compraId).notifier).terminar();
    if (!context.mounted) return;

    switch (resultado) {
      case Exito():
        MensajeApp.exito(context, 'Compra terminada');
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
    }
  }

  /// Abre la remisión impresa: el acta de lo que llegó, para archivarla con
  /// la factura del proveedor.
  ///
  /// Relee el detalle en vez de armarlo con lo que tiene el editor a la vista:
  /// el papel tiene que salir de lo que está guardado. Un borrador también se
  /// imprime —su mercancía ya entró al inventario—, y el título lo dice.
  Future<void> _imprimir(BuildContext context, WidgetRef ref) async {
    try {
      ref.invalidate(compraDetalleProvider(compraId));
      final compra = await ref.read(compraDetalleProvider(compraId).future);
      final ajustes = await leerAjustesImpresion(
        ref.read(repositorioConfiguracionProvider),
      );
      if (!context.mounted) return;

      await DialogoVistaPrevia.mostrar(
        context,
        documento: documentoDeCompra(compra: compra, negocio: ajustes.negocio),
        formato: ajustes.formato,
      );
    } catch (e) {
      if (!context.mounted) return;
      MensajeApp.error(context, 'No se pudo abrir la remisión: $e');
    }
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, int total) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Anular la compra?',
      mensaje: 'Sale del inventario lo que había entrado con esta remisión '
          '(${formatearPrecio(total)}). La compra no se borra: queda anulada, '
          'con su número. Si algo de esa mercancía ya se vendió, no se puede '
          'anular y la corrección es un ajuste de inventario.',
      textoConfirmar: 'Anular',
    );
    if (confirmado != true) return;

    final resultado =
        await ref.read(compraEditorProvider(compraId).notifier).anular();
    if (!context.mounted) return;

    switch (resultado) {
      case Exito():
        MensajeApp.exito(context, 'Compra anulada');
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      compraEditorProvider(compraId).select((s) => (
            total: s.value?.total ?? 0,
            unidades: s.value?.unidades ?? 0,
            puedeTerminar: s.value?.puedeTerminar ?? false,
            estado: s.value?.estado,
            lineas: s.value?.lineas.length ?? 0,
          )),
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
          RenglonCuenta(
            etiqueta: 'Unidades recibidas',
            valor: formatearCantidad(datos.unidades),
          ),
          const SizedBox(height: 8),
          RenglonCuenta(
            etiqueta: 'Costó',
            valor: formatearPrecio(datos.total),
            color: ColoresApp.castletonGreen,
          ),
          // Terminar va arriba y en primario porque es lo que se hace nueve
          // de cada diez veces; anular es el camino de vuelta.
          if (datos.puedeTerminar) ...[
            const SizedBox(height: 16),
            SiPuede(
              permiso: Permiso.comprasCrear,
              child: BotonPrimario(
                etiqueta: 'Marcar como terminada',
                icono: Icons.check_rounded,
                alPresionar: () => unawaited(_terminar(context, ref)),
              ),
            ),
          ],
          // Imprimir no mira el estado: una remisión anulada también se
          // archiva, y el título del papel dice que lo está.
          if (datos.lineas > 0) ...[
            const SizedBox(height: 10),
            BotonSecundario(
              etiqueta: 'Imprimir remisión',
              icono: Icons.print_outlined,
              expandido: true,
              alPresionar: () => unawaited(_imprimir(context, ref)),
            ),
          ],
          if (datos.lineas > 0 && datos.estado != EstadoCompra.anulada) ...[
            const SizedBox(height: 10),
            SiPuede(
              permiso: Permiso.comprasAnular,
              child: BotonDestructivo(
                etiqueta: 'Anular compra',
                icono: Icons.block_rounded,
                expandido: true,
                alPresionar: () =>
                    unawaited(_anular(context, ref, datos.total)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
