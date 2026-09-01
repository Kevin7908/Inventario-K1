import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/pos/enum/enum_ventas.dart';
import '../../../../core/formato.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../provider/historial_ventas_providers.dart';
import '../widgets/tabla_historial_ventas.dart';

/// Historial de ventas: qué se vendió, cuándo, a quién y quién lo cobró.
///
/// **La ven todos**, a diferencia de la bitácora: un cajero necesita poder
/// buscar la factura de un cliente que vuelve a reclamar, y esconderle el
/// historial no le quita a nadie la posibilidad de mirar el cajón.
///
/// **Una factura no se corrige: se deshace.** Desde aquí se puede recibir una
/// devolución parcial —vuelve la mercancía elegida y la factura sigue viva— o
/// anular la venta entera, que la deja en `ANULADA` con su número y devuelve
/// todo lo que quedaba. Las dos piden `POS_ANULAR`. Lo que no hay es editar:
/// ni el total, ni las líneas, ni el cliente.
class HistorialVentasVista extends ConsumerStatefulWidget {
  const HistorialVentasVista({super.key});

  @override
  ConsumerState<HistorialVentasVista> createState() =>
      _HistorialVentasVistaState();
}

class _HistorialVentasVistaState extends ConsumerState<HistorialVentasVista> {
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

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
      ref.read(historialVentasProvider.notifier).buscar(texto);
    });
  }

  void _limpiarFiltros() {
    _busqueda.clear();
    ref.read(historialVentasProvider.notifier).limpiarFiltros();
  }

  /// La raíz no observa el listado: cada bloque se suscribe al suyo.
  @override
  Widget build(BuildContext context) {
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
              titulo: 'Historial de ventas',
              subtitulo: 'Qué se vendió, cuándo y quién lo cobró',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busqueda,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por factura, cliente o cajero...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                const Flexible(child: _ChipsEstado()),
              ],
            ),
            const SizedBox(height: 16),
            const _Filtros(),
            const SizedBox(height: 8),
            const _Resumen(),
            const SizedBox(height: 12),
            // `Expanded` porque `TablaGenerica` lleva encabezado fijo y exige
            // un padre acotado (`CLAUDE.md` §4).
            Expanded(
              child: TablaHistorialVentas(alLimpiarFiltros: _limpiarFiltros),
            ),
            const SizedBox(height: 16),
            const _Paginador(),
          ],
        ),
      ),
    );
  }
}

/// Pagada, pendiente o anulada. Tocar la que ya está puesta la quita.
class _ChipsEstado extends ConsumerWidget {
  const _ChipsEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(
      historialVentasProvider.select((s) => s.value?.estado),
    );
    final notifier = ref.read(historialVentasProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final estado in EstadoPago.values)
          ChipFiltro(
            etiqueta: estado.etiqueta,
            seleccionado: activo == estado,
            colorActivo: colorDeEstadoPago(estado).color,
            alPresionar: () => notifier.filtrarPorEstado(estado),
          ),
      ],
    );
  }
}

/// De dónde salió la venta y entre qué fechas.
class _Filtros extends ConsumerWidget {
  const _Filtros();

  /// El valor que representa «cualquiera» en el desplegable. `null` no sirve:
  /// `SelectorWidget` lo usaría como «sin elegir» y no lo pintaría.
  static const _todos = 'TODOS';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(historialVentasProvider).value;
    if (estado == null) return const SizedBox.shrink();

    final notifier = ref.read(historialVentasProvider.notifier);

    return FilaCampos(
      pesos: const [3, 2, 2],
      hijos: [
        SelectorWidget<String>(
          etiqueta: 'Origen',
          valor: estado.tipo?.aTexto ?? _todos,
          opciones: [_todos, for (final t in TipoVenta.values) t.aTexto],
          constructorEtiqueta: (valor) =>
              valor == _todos ? 'Todas' : TipoVenta.desdeTexto(valor).etiqueta,
          alCambiar: (valor) => notifier.filtrarPorTipo(
            valor == _todos ? null : TipoVenta.desdeTexto(valor),
          ),
        ),
        CampoFecha(
          etiqueta: 'Desde',
          valor: estado.desde,
          formatear: formatearFecha,
          primeraFecha: DateTime(2020),
          ultimaFecha: DateTime.now(),
          alCambiar: (fecha) => notifier.filtrarPorFechas(
            desde: fecha,
            hasta: estado.hasta,
          ),
        ),
        CampoFecha(
          etiqueta: 'Hasta',
          valor: estado.hasta,
          formatear: formatearFecha,
          primeraFecha: estado.desde ?? DateTime(2020),
          ultimaFecha: DateTime.now(),
          alCambiar: (fecha) => notifier.filtrarPorFechas(
            desde: estado.desde,
            hasta: fecha,
          ),
        ),
      ],
    );
  }
}

/// Cuántas ventas hay y cuánto suman **todas** las del filtro.
class _Resumen extends ConsumerWidget {
  const _Resumen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(
      historialVentasProvider.select((s) => (
            total: s.value?.total ?? 0,
            suma: s.value?.sumaNeta ?? 0,
            hayFiltro: s.value?.hayFiltro ?? false,
            cargado: s.value != null,
          )),
    );
    if (!resumen.cargado) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          resumen.total == 1 ? '1 venta' : '${resumen.total} ventas',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        const SizedBox(width: 12),
        // El periodo entero, no la página: lo suma SQLite con el mismo
        // `WHERE` del listado. Va neto y sin las anuladas —lo devuelto salió
        // de la caja y lo anulado nunca entró—, que es la cifra con la que se
        // cuadra el cajón.
        Text(
          'En total: ${formatearPrecio(resumen.suma)}',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        if (resumen.hayFiltro) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: () =>
                ref.read(historialVentasProvider.notifier).limpiarFiltros(),
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
    final estado = ref.watch(historialVentasProvider).value;
    if (estado == null || estado.total == 0) return const SizedBox.shrink();

    return PaginacionWidget(
      paginaActual: estado.pagina,
      totalPaginas: estado.totalPaginas,
      totalItems: estado.total,
      itemsPorPagina: estado.tamanoPagina,
      alCambiarPagina: (pagina) =>
          ref.read(historialVentasProvider.notifier).irAPagina(pagina),
    );
  }
}
