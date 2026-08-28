import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/inventario/modelo/movimiento_inventario.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/formato.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../provider/inventario_providers.dart';
import '../widgets/dialogo_entrada_compra.dart';
import '../widgets/estilo_movimiento.dart';
import '../widgets/tabla_movimientos.dart';

/// Movimientos de inventario: el libro mayor del taller.
///
/// Cada entrada y cada salida de mercancía deja aquí su renglón, con quién la
/// hizo y de qué documento vino. **No se edita nada**: un movimiento mal
/// registrado se corrige con otro que lo compense —lo impide además una guarda
/// de la base—.
///
/// Es la pantalla que responde «¿dónde se fueron las doce pastillas?», que es
/// la pregunta que antes no tenía respuesta porque el stock se escribía con
/// seis `UPDATE` repartidos por la app.
class MovimientosVista extends ConsumerStatefulWidget {
  const MovimientosVista({super.key});

  @override
  ConsumerState<MovimientosVista> createState() => _MovimientosVistaState();
}

class _MovimientosVistaState extends ConsumerState<MovimientosVista> {
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
      ref.read(movimientosProvider.notifier).buscar(texto);
    });
  }

  void _limpiarFiltros() {
    _busqueda.clear();
    ref.read(movimientosProvider.notifier).limpiarFiltros();
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
              titulo: 'Movimientos de inventario',
              subtitulo: 'Todo lo que entró y salió, y quién lo movió',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busqueda,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por producto, SKU o nota...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                const Flexible(child: _ChipsSentido()),
                const SizedBox(width: 20),
                // Esconder el botón es orden; la compuerta que impide de
                // verdad está en el repositorio (`CLAUDE.md` §7 bis).
                SiPuede(
                  permiso: Permiso.inventarioEntrada,
                  child: BotonPrimario(
                    etiqueta: 'Dar entrada',
                    icono: Icons.local_shipping_outlined,
                    alPresionar: () => DialogoEntradaCompra.mostrar(context),
                  ),
                ),
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
              child: TablaMovimientos(alLimpiarFiltros: _limpiarFiltros),
            ),
            const SizedBox(height: 16),
            const _Paginador(),
          ],
        ),
      ),
    );
  }
}

/// Entradas o salidas. Tocar el que ya está puesto lo quita.
class _ChipsSentido extends ConsumerWidget {
  const _ChipsSentido();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo =
        ref.watch(movimientosProvider.select((s) => s.value?.soloEntradas));
    final notifier = ref.read(movimientosProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChipFiltro(
          etiqueta: 'Entradas',
          icono: Icons.south_west_rounded,
          seleccionado: activo == true,
          colorActivo: ColoresApp.statusSuccess,
          alPresionar: () => notifier.filtrarPorSentido(true),
        ),
        ChipFiltro(
          etiqueta: 'Salidas',
          icono: Icons.north_east_rounded,
          seleccionado: activo == false,
          colorActivo: ColoresApp.statusDanger,
          alPresionar: () => notifier.filtrarPorSentido(false),
        ),
      ],
    );
  }
}

/// Por qué se movió y entre qué fechas.
class _Filtros extends ConsumerWidget {
  const _Filtros();

  /// El valor que representa «cualquiera» en el desplegable. `null` no sirve:
  /// `SelectorWidget` lo usaría como «sin elegir» y no lo pintaría.
  static const _todos = 'TODOS';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(movimientosProvider).value;
    if (estado == null) return const SizedBox.shrink();

    final notifier = ref.read(movimientosProvider.notifier);

    return FilaCampos(
      pesos: const [3, 2, 2],
      hijos: [
        SelectorWidget<String>(
          etiqueta: 'Por qué',
          valor: estado.tipo?.codigo ?? _todos,
          opciones: [_todos, for (final t in TipoMovimiento.values) t.codigo],
          constructorEtiqueta: (valor) => valor == _todos
              ? 'Todos los motivos'
              : TipoMovimiento.desdeCodigo(valor).etiqueta,
          alCambiar: (valor) => notifier.filtrarPorTipo(
            valor == _todos ? null : TipoMovimiento.desdeCodigo(valor),
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

/// Cuántos movimientos hay y qué saldo dejan los de esta página.
class _Resumen extends ConsumerWidget {
  const _Resumen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(movimientosProvider).value;
    if (estado == null) return const SizedBox.shrink();

    // Solo lo visible, y la etiqueta lo dice: sumar todas las páginas pide su
    // propia consulta con `SUM`, no recorrer una lista que no está entera.
    final saldo = estado.items
        .fold<double>(0, (acumulado, m) => acumulado + m.cantidad);

    return Row(
      children: [
        Text(
          estado.total == 1 ? '1 movimiento' : '${estado.total} movimientos',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        const SizedBox(width: 12),
        Text(
          'En esta página: ${formatearCantidadMovimiento(saldo)} unidades',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        if (estado.hayFiltro) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: () =>
                ref.read(movimientosProvider.notifier).limpiarFiltros(),
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
    final estado = ref.watch(movimientosProvider).value;
    if (estado == null || estado.total == 0) return const SizedBox.shrink();

    return PaginacionWidget(
      paginaActual: estado.pagina,
      totalPaginas: estado.totalPaginas,
      totalItems: estado.total,
      itemsPorPagina: estado.tamanoPagina,
      alCambiarPagina: (pagina) =>
          ref.read(movimientosProvider.notifier).irAPagina(pagina),
    );
  }
}
