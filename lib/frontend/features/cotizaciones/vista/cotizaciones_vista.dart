import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../core/formato.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../cotizaciones_detalle/vista/cotizacion_detalle_vista.dart';
import '../provider/cotizaciones_provider.dart';
import '../widgets/tabla/tabla_cotizaciones.dart';

/// Pantalla de Cotizaciones: presupuestos previos para clientes.
///
/// Hospeda la navegación interna del módulo —listado y editor— sin rutas
/// globales, igual que Clientes y Productos, para que la barra lateral no
/// desaparezca al abrir una cotización.
class CotizacionesVista extends ConsumerStatefulWidget {
  const CotizacionesVista({super.key});

  @override
  ConsumerState<CotizacionesVista> createState() => _CotizacionesVistaState();
}

/// Vista activa dentro del módulo.
enum _Pantalla { lista, editor }

class _CotizacionesVistaState extends ConsumerState<CotizacionesVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  _Pantalla _pantalla = _Pantalla.lista;
  CotizacionResumen? _seleccionada;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(cotizacionesProvider.notifier).buscar(texto);
    });
  }

  void _nueva() => setState(() {
        _seleccionada = null;
        _pantalla = _Pantalla.editor;
      });

  void _abrir(CotizacionResumen cotizacion) => setState(() {
        _seleccionada = cotizacion;
        _pantalla = _Pantalla.editor;
      });

  void _volverALista() => setState(() {
        _seleccionada = null;
        _pantalla = _Pantalla.lista;
      });

  @override
  Widget build(BuildContext context) {
    return switch (_pantalla) {
      _Pantalla.lista => _lista(),
      _Pantalla.editor => CotizacionDetalleVista(
          cotizacion: _seleccionada,
          alCerrar: _volverALista,
        ),
    };
  }

  /// La raíz no observa ningún provider: cada bloque se suscribe al suyo, así
  /// que escribir en el buscador no reconstruye el encabezado ni los chips.
  Widget _lista() {
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
            const _EncabezadoCotizaciones(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busquedaController,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por código o cliente...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nueva cotización',
                  icono: Icons.add,
                  alPresionar: _nueva,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _ChipsEstado(),
            const SizedBox(height: 16),
            Expanded(child: TablaCotizaciones(alAbrir: _abrir)),
          ],
        ),
      ),
    );
  }
}

/// Encabezado con los conteos del listado.
///
/// El monto vigente va aquí y no en tarjetas sueltas —como en Clientes y
/// Motos—: es un solo número y no justifica una fila de cards que le robe
/// altura a la tabla.
class _EncabezadoCotizaciones extends ConsumerWidget {
  const _EncabezadoCotizaciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(cotizacionesResumenProvider).value;
    final total = resumen?.total ?? 0;

    final buffer = StringBuffer('Presupuestos previos para clientes');
    if (total > 0) {
      buffer.write(total == 1 ? ' · 1 cotización' : ' · $total cotizaciones');
      final montoVigente = resumen?.montoVigente ?? 0;
      if (montoVigente > 0) {
        buffer.write(' · ${formatearPrecio(montoVigente)} en juego');
      }
    }

    return EncabezadoConCuenta(
      titulo: 'Cotizaciones',
      subtitulo: buffer.toString(),
    );
  }
}

/// Chips de filtro por vigencia, con el conteo de cada estado.
class _ChipsEstado extends ConsumerWidget {
  const _ChipsEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(
      cotizacionesProvider.select((s) => s.value?.filtroEstado),
    );
    final resumen = ref.watch(cotizacionesResumenProvider).value;

    void filtrar(EstadoCotizacion? valor) =>
        ref.read(cotizacionesProvider.notifier).filtrarPorEstado(valor);

    String con(String etiqueta, int? cuenta) =>
        cuenta == null || cuenta == 0 ? etiqueta : '$etiqueta ($cuenta)';

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        ChipFiltro(
          etiqueta: con('Todas', resumen?.total),
          seleccionado: estado == null,
          alPresionar: () => filtrar(null),
        ),
        ChipFiltro(
          etiqueta: con('Vigentes', resumen?.vigentes),
          seleccionado: estado == EstadoCotizacion.vigente,
          colorActivo: ColoresApp.statusSuccess,
          alPresionar: () => filtrar(EstadoCotizacion.vigente),
        ),
        ChipFiltro(
          etiqueta: con('Por vencer', resumen?.porVencer),
          seleccionado: estado == EstadoCotizacion.porVencer,
          colorActivo: ColoresApp.statusWarning,
          alPresionar: () => filtrar(EstadoCotizacion.porVencer),
        ),
        ChipFiltro(
          etiqueta: con('Vencidas', resumen?.vencidas),
          seleccionado: estado == EstadoCotizacion.vencida,
          colorActivo: ColoresApp.statusDanger,
          alPresionar: () => filtrar(EstadoCotizacion.vencida),
        ),
      ],
    );
  }
}
