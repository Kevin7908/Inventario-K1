import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../share/share.dart';
import '../../clientes/provider/cliente_provider.dart';
import '../provider/pos_providers.dart';
import 'linea_carrito.dart';
import 'totales_venta.dart';

/// Panel derecho del punto de venta: la venta que se está armando.
///
/// Es el aside de "Venta actual" del diseño: 360 px, borde a la izquierda,
/// cabecera con el contador de ítems, lista scrolleable y pie sobre fondo
/// tenue.
class PanelVenta extends StatelessWidget {
  const PanelVenta({super.key, required this.alCobrar});

  static const double ancho = PanelDocumento.ancho;

  final VoidCallback alCobrar;

  @override
  Widget build(BuildContext context) {
    return PanelDocumento(
      cabecera: const _Cabecera(),
      contenido: const _Lineas(),
      pie: _Pie(alCobrar: alCobrar),
    );
  }
}

/// Título, contador de ítems y la ficha de a quién se le vende.
class _Cabecera extends ConsumerWidget {
  const _Cabecera();

  /// El cliente es opcional: lo normal en el mostrador es que sea alguien de
  /// paso. Se elige cuando hace falta que la venta quede a su nombre.
  ///
  /// [clientes] llega ya resuelto desde `build`: `catalogoClientesProvider` es
  /// un `StreamProvider`, y un `ref.read` desde el callback lo encontraría sin
  /// oyentes y sin datos —el cuadro salía vacío—.
  Future<void> _elegirCliente(
    BuildContext context,
    WidgetRef ref,
    List<Cliente> clientes,
  ) async {
    final elegido = await showDialog<Seleccion<Cliente>>(
      context: context,
      builder: (_) => CuadroSeleccion<Cliente>(
        titulo: 'Cliente',
        opciones: clientes,
        constructorEtiqueta: (c) => c.nombreCompleto,
        constructorDetalle: (c) => c.telefono,
        placeholderBusqueda: 'Buscar por nombre o teléfono…',
        seleccionado: ref.read(posProvider).cliente,
        alAgregar: null,
        etiquetaAgregar: 'Agregar',
      ),
    );
    if (elegido == null) return;
    ref.read(posProvider.notifier).seleccionarCliente(elegido.valor);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(
      posProvider.select((s) => (
            cliente: s.cliente?.nombreCompleto,
            telefono: s.cliente?.telefono,
            unidades: s.unidades,
          )),
    );
    final clientes =
        ref.watch(catalogoClientesProvider).value ?? const <Cliente>[];

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
                child: Text('Venta actual', style: TipografiaApp.heading3),
              ),
              IndicadorEstado(
                etiqueta:
                    datos.unidades == 1 ? '1 ítem' : '${datos.unidades} ítems',
                color: ColoresApp.castletonGreen,
                colorFondo: ColoresApp.statusSuccessBg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FichaResumen(
            titulo: datos.cliente ?? 'Mostrador',
            subtitulo: datos.cliente == null
                ? 'Venta sin cliente registrado'
                : datos.telefono,
            inicial: datos.cliente == null ? null : inicialDe(datos.cliente!),
            icono: datos.cliente == null ? Icons.storefront_outlined : null,
            tenue: datos.cliente == null,
            etiquetaAccion: 'Elegir el cliente de la venta',
            alPresionar: () => _elegirCliente(context, ref, clientes),
          ),
        ],
      ),
    );
  }
}

/// Las líneas del carrito. Es lo único del panel que cambia al agregar o
/// quitar algo, así que va en su propio widget.
class _Lineas extends ConsumerWidget {
  const _Lineas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(posProvider.select((s) => s.items));

    if (items.isEmpty) {
      return const EstadoVacio(
        icono: Icons.shopping_cart_outlined,
        titulo: 'El carrito está vacío',
        pista: 'Toca un producto de la izquierda para agregarlo.',
      );
    }

    final notifier = ref.read(posProvider.notifier);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return LineaCarrito(
          // El producto identifica la línea; el índice solo, no: al borrar una
          // de en medio, el estado del control de cantidad se reutilizaría
          // para la siguiente.
          key: ValueKey(item.producto.id),
          item: item,
          alCambiarCantidad: (cantidad) => notifier.cambiarCantidad(i, cantidad),
          alEliminar: () => notifier.quitarLinea(i),
        );
      },
    );
  }
}

/// Totales y cobro, sobre el fondo tenue del diseño.
class _Pie extends ConsumerWidget {
  const _Pie({required this.alCobrar});

  final VoidCallback alCobrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(
      posProvider.select((s) => (vacio: s.vacio, procesando: s.procesando)),
    );
    final puedeCobrar = !estado.vacio && !estado.procesando;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: const BoxDecoration(
        color: ColoresApp.bgInput,
        border: Border(top: BorderSide(color: ColoresApp.borderFila)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TotalesVenta(),
          const SizedBox(height: 16),
          BotonPrimario(
            etiqueta: estado.procesando ? 'Cobrando…' : 'Cobrar e imprimir',
            icono: Icons.print_outlined,
            alPresionar: puedeCobrar ? alCobrar : null,
          ),
          const SizedBox(height: 10),
          BotonSecundario(
            etiqueta: 'Vaciar carrito',
            icono: Icons.remove_shopping_cart_outlined,
            expandido: true,
            alPresionar:
                estado.vacio ? null : ref.read(posProvider.notifier).vaciar,
          ),
        ],
      ),
    );
  }
}
