import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_error_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_vacio_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';
import 'package:inventario_k1/frontend/share/widgets/paginacion_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/top_bar_widget.dart';

import '../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../provider/cotizaciones_provider.dart';
import '../cotizaciones_detalle/vista/cotizacion_detalle_vista.dart';
import '../widgets/tabla/cotizacion_fila_widget.dart';
import '../widgets/tabla/resumen_cards_cotizacion.dart';
import '../widgets/tabla/seccion_filtros_cot.dart';

class CotizacionesVista extends ConsumerStatefulWidget {
  const CotizacionesVista({super.key});

  @override
  ConsumerState<CotizacionesVista> createState() => _CotizacionesVistaState();
}

class _CotizacionesVistaState extends ConsumerState<CotizacionesVista> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onBuscar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(cotizacionesProvider.notifier).buscar(valor);
    });
  }

  void _abrirNueva() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CotizacionDetalleVista(),
      ),
    );
  }

  void _abrirDetalle(CotizacionResumen cot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CotizacionDetalleVista(cotizacion: cot),
      ),
    );
  }

  void _confirmarEliminar(CotizacionResumen cot) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: cot.numero,
      tipoElemento: 'cotización',
      onConfirmar: () async {
        final error =
            await ref.read(cotizacionesProvider.notifier).eliminar(cot.id);
        if (!mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Cotización eliminada.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBarConBoton(
            titulo: 'Cotizaciones',
            etiquetaBoton: 'Nueva Cotización',
            alPresionarBoton: _abrirNueva,
          ),
          Expanded(
            child: _CuerpoCotizaciones(
              onBuscar: _onBuscar,
              onDetalle: _abrirDetalle,
              onEliminar: _confirmarEliminar,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shell asíncrono ───────────────────────────────────────────────────────────
//
// Usa .select para que solo reaccione a transiciones loading/error,
// no a cada actualización de datos o cambio de filtro/página.

class _CuerpoCotizaciones extends ConsumerWidget {
  const _CuerpoCotizaciones({
    required this.onBuscar,
    required this.onDetalle,
    required this.onEliminar,
  });

  final ValueChanged<String> onBuscar;
  final ValueChanged<CotizacionResumen> onDetalle;
  final ValueChanged<CotizacionResumen> onEliminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      cotizacionesProvider.select((s) => !s.hasValue && !s.hasError),
    );
    final error = ref.watch(
      cotizacionesProvider.select((s) => s.hasError ? s.error : null),
    );

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      );
    }
    if (error != null) {
      return EstadoErrorWidget(
        mensaje: error.toString(),
        alReintentar: () => ref.invalidate(cotizacionesProvider),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ResumenCardsCotizacion(),
          const SizedBox(height: 20),
          SeccionFiltrosCot(onBuscar: onBuscar),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ColoresApp.bgCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: ColoresApp.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CotizacionTablaEncabezado(),
                  Expanded(
                    child: _TablaCotizaciones(
                      onDetalle: onDetalle,
                      onEliminar: onEliminar,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _PaginacionCotizaciones(),
        ],
      ),
    );
  }
}

// ── Tabla paginada ────────────────────────────────────────────────────────────
//
// Solo se reconstruye cuando cambia la slice de cotizaciones visible.

class _TablaCotizaciones extends ConsumerWidget {
  const _TablaCotizaciones({
    required this.onDetalle,
    required this.onEliminar,
  });

  final ValueChanged<CotizacionResumen> onDetalle;
  final ValueChanged<CotizacionResumen> onEliminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginadas = ref.watch(
      paginacionProvider.select((p) => p.paginadas),
    );

    if (paginadas.isEmpty) {
      return const EstadoVacioWidget(
        icono: Icons.description_outlined,
        textoSinDatos: 'Sin cotizaciones',
        textoSinResultados: 'No hay cotizaciones que coincidan.',
        textoCTA: '',
      );
    }

    return ListView.separated(
      itemCount: paginadas.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: ColoresApp.border,
      ),
      itemBuilder: (_, i) {
        final cot = paginadas[i];
        return CotizacionFilaWidget(
          key: ValueKey(cot.id),
          cotizacion: cot,
          seleccionada: false,
          onTap: () => onDetalle(cot),
          onEliminar: () => onEliminar(cot),
        );
      },
    );
  }
}

// ── Barra de paginación ───────────────────────────────────────────────────────
//
// Solo se reconstruye cuando cambia el número de página, total o páginas.

class _PaginacionCotizaciones extends ConsumerWidget {
  const _PaginacionCotizaciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pag = ref.watch(paginacionProvider);

    return PaginacionWidget(
      paginaActual: pag.paginaActual,
      totalPaginas: pag.totalPaginas,
      totalItems: pag.totalFiltradas,
      itemsPorPagina: CotizacionesState.itemsPorPagina,
      alCambiarPagina: (p) =>
          ref.read(cotizacionesProvider.notifier).cambiarPagina(p),
      labelEntidad: 'cotizaciones',
    );
  }
}
