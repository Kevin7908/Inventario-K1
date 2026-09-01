import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/compras/enum/enum_compras.dart';
import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/formato.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../../proveedores/provider/proveedores_provider.dart';
import '../compra_detalle/vista/compra_detalle_vista.dart';
import '../compra_detalle/widgets/dialogo_nueva_compra.dart';
import '../provider/compras_providers.dart';
import '../widgets/tabla_compras.dart';

/// Compras: las remisiones del proveedor, con lo que de verdad costó cada una.
///
/// Es el otro lado del historial de ventas. Antes de que existiera, dar
/// entrada preguntaba producto y cantidad, así que el taller no podía saber a
/// cómo compró un repuesto la última vez ni cuánto lleva gastado con un
/// proveedor este mes.
///
/// La remisión se abre desde aquí y se trabaja en su propia ficha, que
/// **guarda sola**: se anota lo que llegó con su costo y cada línea entra al
/// inventario en el momento. Si se tecleó mal del todo, se anula —lo que saca
/// lo que había entrado—.
class ComprasVista extends ConsumerStatefulWidget {
  const ComprasVista({super.key});

  @override
  ConsumerState<ComprasVista> createState() => _ComprasVistaState();
}

class _ComprasVistaState extends ConsumerState<ComprasVista> {
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  /// Qué remisión está abierta en la ficha. `null` = se ve el listado.
  int? _abierta;

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  /// Con retardo: cada tecla reabre el stream con un `WHERE` nuevo.
  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(comprasProvider.notifier).buscar(texto);
    });
  }

  void _limpiarFiltros() {
    _busqueda.clear();
    ref.read(comprasProvider.notifier).limpiarFiltros();
  }

  /// Una remisión nueva empieza preguntando de quién llegó, porque
  /// `proveedor_id` es `NOT NULL`. Cancelar el cuadro no crea nada.
  Future<void> _nueva() async {
    final id = await DialogoNuevaCompra.mostrar(context);
    if (id == null || !mounted) return;
    setState(() => _abierta = id);
  }

  void _abrir(int compraId) => setState(() => _abierta = compraId);

  void _volverALista() => setState(() => _abierta = null);

  /// La raíz no observa el listado: cada bloque se suscribe al suyo.
  @override
  Widget build(BuildContext context) {
    final abierta = _abierta;
    if (abierta != null) {
      return CompraDetalleVista(compraId: abierta, alCerrar: _volverALista);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EncabezadoConCuenta(
              titulo: 'Compras',
              subtitulo: 'Lo que llega del proveedor, con su costo real',
            ),
            const SizedBox(height: 20),
            const _Tarjetas(),
            const SizedBox(height: 20),
            // El buscador y el botón ocupan el ancho completo, y los chips
            // van **debajo**: apretados en la misma fila, el buscador se
            // quedaba sin sitio y los tres bloques competían por el ancho.
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busqueda,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por remisión, factura o proveedor...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                SiPuede(
                  permiso: Permiso.comprasCrear,
                  child: BotonPrimario(
                    etiqueta: 'Registrar compra',
                    icono: Icons.add,
                    alPresionar: _nueva,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _ChipsEstado(),
            const SizedBox(height: 16),
            const _Filtros(),
            const SizedBox(height: 8),
            const _Resumen(),
            const SizedBox(height: 12),
            // `Expanded` porque `TablaGenerica` lleva encabezado fijo y exige
            // un padre acotado (`CLAUDE.md` §4).
            Expanded(
              child: TablaCompras(
                alLimpiarFiltros: _limpiarFiltros,
                alAbrir: _abrir,
              ),
            ),
            const SizedBox(height: 16),
            const _Paginador(),
          ],
        ),
      ),
    );
  }
}

/// Los cuatro números del mes: cuántas remisiones, cuánto se invirtió, a
/// cuántos proveedores y cuántas se anularon.
class _Tarjetas extends ConsumerWidget {
  const _Tarjetas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenComprasProvider).value;

    return Row(
      children: [
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.comprasMes ?? 0}',
            etiqueta: 'Compras del mes',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: formatearPrecioCompacto(resumen?.invertidoMes ?? 0),
            etiqueta: 'Invertido este mes',
            colorValor: ColoresApp.castletonGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.proveedoresMes ?? 0}',
            etiqueta: 'Proveedores del mes',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TarjetaMetrica(
            valor: '${resumen?.anuladas ?? 0}',
            etiqueta: 'Anuladas',
            colorValor: ColoresApp.statusDanger,
          ),
        ),
      ],
    );
  }
}

/// Registrada o anulada. Tocar el que ya está puesto lo quita.
class _ChipsEstado extends ConsumerWidget {
  const _ChipsEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(comprasProvider.select((s) => s.value?.estado));
    final notifier = ref.read(comprasProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final estado in EstadoCompra.values)
          ChipFiltro(
            etiqueta: estado.etiqueta,
            seleccionado: activo == estado,
            colorActivo: colorDeEstadoCompra(estado).color,
            alPresionar: () => notifier.filtrarPorEstado(estado),
          ),
      ],
    );
  }
}

/// De qué proveedor y entre qué fechas.
class _Filtros extends ConsumerWidget {
  const _Filtros();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(comprasProvider).value;
    if (estado == null) return const SizedBox.shrink();

    final notifier = ref.read(comprasProvider.notifier);
    final proveedores =
        ref.watch(catalogoProveedoresProvider).value ?? const <Proveedor>[];

    return FilaCampos(
      pesos: const [3, 2, 2],
      hijos: [
        CampoBusqueda<Proveedor>(
          etiqueta: 'Proveedor',
          valor: proveedores
              .where((p) => p.id == estado.proveedorId)
              .firstOrNull,
          opciones: proveedores,
          constructorEtiqueta: (p) => p.nombre,
          placeholder: 'Todos',
          placeholderBusqueda: 'Nombre del proveedor…',
          alCambiar: (p) => notifier.filtrarPorProveedor(p?.id),
        ),
        CampoFecha(
          etiqueta: 'Desde',
          valor: estado.desde,
          formatear: formatearFecha,
          primeraFecha: DateTime(2020),
          ultimaFecha: DateTime.now(),
          alCambiar: (fecha) =>
              notifier.filtrarPorFechas(desde: fecha, hasta: estado.hasta),
        ),
        CampoFecha(
          etiqueta: 'Hasta',
          valor: estado.hasta,
          formatear: formatearFecha,
          primeraFecha: estado.desde ?? DateTime(2020),
          ultimaFecha: DateTime.now(),
          alCambiar: (fecha) =>
              notifier.filtrarPorFechas(desde: estado.desde, hasta: fecha),
        ),
      ],
    );
  }
}

/// Cuántas compras hay y cuánto suman las de la página.
class _Resumen extends ConsumerWidget {
  const _Resumen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(comprasProvider).value;
    if (estado == null) return const SizedBox.shrink();

    // Solo lo visible, y la etiqueta lo dice: el total del periodo filtrado
    // pide su propia consulta con `SUM`, no recorrer una lista paginada.
    final sumaPagina = estado.items
        .where((c) => !c.anulada)
        .fold<int>(0, (acumulado, c) => acumulado + c.total);

    return Row(
      children: [
        Text(
          estado.total == 1 ? '1 compra' : '${estado.total} compras',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        const SizedBox(width: 12),
        Text(
          'En esta página: ${formatearPrecio(sumaPagina)}',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        if (estado.hayFiltro) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => ref.read(comprasProvider.notifier).limpiarFiltros(),
            child: Text(
              'Quitar los filtros',
              style: TipografiaApp.enlace(TipografiaApp.caption),
            ),
          ),
        ],
      ],
    );
  }
}

class _Paginador extends ConsumerWidget {
  const _Paginador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(comprasProvider).value;
    if (estado == null || estado.total == 0) return const SizedBox.shrink();

    return PaginacionWidget(
      paginaActual: estado.pagina,
      totalPaginas: estado.totalPaginas,
      totalItems: estado.total,
      itemsPorPagina: estado.tamanoPagina,
      alCambiarPagina: (pagina) =>
          ref.read(comprasProvider.notifier).irAPagina(pagina),
    );
  }
}
