import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_error_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';
import 'package:inventario_k1/frontend/share/widgets/top_bar_widget.dart';

import '../../../../backend/features/deudores/enum/enum_deudor.dart';
import '../../../../backend/features/deudores/modelo/deudor_pago.dart';
import '../../../../backend/features/deudores/modelo/deudor_resumen.dart';
import '../provider/deudor_editor_provider.dart';
import '../provider/deudores_provider.dart';
import '../widgets/detalle/badge_estado_deudor_widget.dart';
import '../widgets/detalle/card_info_general_deudor_widget.dart';
import '../widgets/detalle/card_pagos_deudor_widget.dart';
import '../widgets/detalle/form_pago_inline_widget.dart';
import '../widgets/detalle/panel_resumen_financiero_deudor_widget.dart';
import '../widgets/formulario/seccion_datos_deudor_widget.dart';
import '../widgets/formulario/seccion_pago_inicial_widget.dart';
import '../widgets/lista/filtros_lista_deudores_widget.dart';
import '../widgets/lista/kpi_deudores_widget.dart';
import '../widgets/lista/tarjeta_lista_deudor_widget.dart';

class DeudoresVista extends ConsumerWidget {
  const DeudoresVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      deudoresProvider.select((s) => !s.hasValue && !s.hasError),
    );
    final error = ref.watch(
      deudoresProvider.select((s) => s.hasError ? s.error : null),
    );

    if (isLoading) {
      return const Scaffold(
        backgroundColor: ColoresApp.bgContent,
        body: Center(
          child: CircularProgressIndicator(color: ColoresApp.primary),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: ColoresApp.bgContent,
        body: EstadoErrorWidget(
          mensaje: error.toString(),
          alReintentar: () => ref.invalidate(deudoresProvider),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBarDeudores(),
          Expanded(child: _LayoutMasterDetail()),
        ],
      ),
    );
  }
}

// ── TopBar ────────────────────────────────────────────────────────────────────

class _TopBarDeudores extends ConsumerWidget {
  const _TopBarDeudores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      deudoresProvider.select((s) => s.asData?.value.deudores.length ?? 0),
    );
    return TopBarWidget(
      titulo: 'Deudores',
      accionesSufijo: _ContadorTotal(total: total),
    );
  }
}

class _ContadorTotal extends StatelessWidget {
  const _ContadorTotal({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ColoresApp.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$total',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Layout master-detail ──────────────────────────────────────────────────────

class _LayoutMasterDetail extends StatelessWidget {
  const _LayoutMasterDetail();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelListaIzquierdo(),
        VerticalDivider(width: 1, thickness: 1, color: ColoresApp.border),
        Expanded(child: _PanelDerechoDinamico()),
      ],
    );
  }
}

// ── Panel izquierdo ───────────────────────────────────────────────────────────

class _PanelListaIzquierdo extends StatelessWidget {
  const _PanelListaIzquierdo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 370,
      child: Container(
        color: ColoresApp.bgCard,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KpiDeudoresWidget(),
            SizedBox(height: 4),
            FiltrosListaDeudoresWidget(),
            Divider(height: 14, color: ColoresApp.border),
            Expanded(child: _ListaDeudores()),
            Divider(height: 1, color: ColoresApp.border),
            _BotonNuevaDeuda(),
          ],
        ),
      ),
    );
  }
}

class _ListaDeudores extends ConsumerWidget {
  const _ListaDeudores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pag = ref.watch(paginacionDeudoresProvider);
    final seleccionadoId = ref.watch(
      deudoresProvider
          .select((s) => s.asData?.value.deudorSeleccionadoId),
    );

    if (pag.paginadas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 38, color: ColoresApp.textLight),
              SizedBox(height: 8),
              Text(
                'Sin deudores',
                style: TextStyle(fontSize: 13, color: ColoresApp.textLight),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: pag.paginadas.length,
      itemBuilder: (_, i) {
        final d = pag.paginadas[i];
        return TarjetaListaDeudorWidget(
          key: ValueKey(d.id),
          deudor: d,
          seleccionado: d.id == seleccionadoId,
          onTap: () =>
              ref.read(deudoresProvider.notifier).abrirDetalle(d.id),
        );
      },
    );
  }
}

class _BotonNuevaDeuda extends ConsumerWidget {
  const _BotonNuevaDeuda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ElevatedButton.icon(
        onPressed: () {
          ref.invalidate(deudorEditorProvider);
          ref.read(deudoresProvider.notifier).abrirNuevo();
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nueva deuda'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresApp.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Panel derecho dinámico ────────────────────────────────────────────────────

class _PanelDerechoDinamico extends ConsumerWidget {
  const _PanelDerechoDinamico();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(
      deudoresProvider
          .select((s) => s.asData?.value.modoPanel ?? ModoPanelDeudor.vacio),
    );

    return switch (modo) {
      ModoPanelDeudor.vacio => const _EstadoVacioDetalle(),
      ModoPanelDeudor.detalle => const _PanelDetalle(),
      ModoPanelDeudor.formulario => const _PanelFormulario(),
    };
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EstadoVacioDetalle extends StatelessWidget {
  const _EstadoVacioDetalle();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 52, color: ColoresApp.textLight),
          SizedBox(height: 10),
          Text(
            'Selecciona un deudor',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textMedium,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'o registra una nueva deuda con el botón inferior',
            style: TextStyle(fontSize: 12, color: ColoresApp.textLight),
          ),
        ],
      ),
    );
  }
}

// ── Panel de detalle ──────────────────────────────────────────────────────────

class _PanelDetalle extends ConsumerWidget {
  const _PanelDetalle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudorId = ref.watch(
      deudoresProvider
          .select((s) => s.asData?.value.deudorSeleccionadoId),
    );
    if (deudorId == null) return const _EstadoVacioDetalle();

    final detalleAsync = ref.watch(deudorDetalleProvider(deudorId));

    return detalleAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.primary),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error al cargar: $e',
          style: const TextStyle(color: ColoresApp.statusDebt),
        ),
      ),
      data: (detalle) => _ContenidoDetalle(
        key: ValueKey(deudorId),
        resumen: detalle.resumen,
        pagos: detalle.pagos,
      ),

    );
  }
}

class _ContenidoDetalle extends ConsumerWidget {
  const _ContenidoDetalle({
    super.key,
    required this.resumen,
    required this.pagos,
  });

  final DeudorResumen resumen;
  final List<DeudorPago> pagos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostrarFormPago = ref.watch(
      deudoresProvider
          .select((s) => s.asData?.value.mostrarFormPago ?? false),
    );

    return Column(
      children: [
        _CabeceraDetalle(resumen: resumen),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      if (mostrarFormPago)
                        FormPagoInlineWidget(
                          deudorId: resumen.id,
                          saldo: resumen.saldo,
                        ),
                      CardInfoGeneralDeudorWidget(resumen: resumen),
                      const SizedBox(height: 14),
                      CardPagosDeudorWidget(
                        pagos: pagos,
                        deudorId: resumen.id,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 260,
                  child: PanelResumenFinancieroDeudorWidget(
                    resumen: resumen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CabeceraDetalle extends ConsumerWidget {
  const _CabeceraDetalle({required this.resumen});

  final DeudorResumen resumen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostrarFormPago = ref.watch(
      deudoresProvider
          .select((s) => s.asData?.value.mostrarFormPago ?? false),
    );
    final notifier = ref.read(deudoresProvider.notifier);
    final puedeRegistrarPago = resumen.estado == EstadoDeudor.activa ||
        resumen.estado == EstadoDeudor.vencida;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: ColoresApp.bgCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      resumen.numero,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    BadgeEstadoDeudorWidget(estado: resumen.estado),
                  ],
                ),
                Text(
                  '${resumen.nombreCliente}  ·  Creada el '
                  '${resumen.creadoEn.year}-${resumen.creadoEn.month.toString().padLeft(2, '0')}-${resumen.creadoEn.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColoresApp.textMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              if (puedeRegistrarPago)
                ElevatedButton.icon(
                  onPressed: notifier.toggleFormPago,
                  icon: Icon(
                    mostrarFormPago
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.add_rounded,
                    size: 16,
                  ),
                  label: Text(
                      mostrarFormPago ? 'Cerrar pago' : 'Registrar pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 10),
              _BotonesAccionDetalle(resumen: resumen),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonesAccionDetalle extends ConsumerWidget {
  const _BotonesAccionDetalle({required this.resumen});

  final DeudorResumen resumen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Tooltip(
          message: 'Editar',
          child: IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: ColoresApp.textMedium),
            style: IconButton.styleFrom(
              backgroundColor: ColoresApp.bgContent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: ColoresApp.border),
              ),
            ),
            onPressed: () {
              ref.read(deudorEditorProvider.notifier).inicializar(resumen);
              ref.read(deudoresProvider.notifier).abrirEditar(resumen.id);
            },
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Eliminar',
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: ColoresApp.statusDebt),
            style: IconButton.styleFrom(
              backgroundColor: ColoresApp.statusDebtBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _confirmarEliminar(context, ref),
          ),
        ),
      ],
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref) {
    DialogoConfirmarEliminar.mostrar(
      context: context,
      nombreElemento: resumen.numero,
      tipoElemento: 'deuda',
      onConfirmar: () async {
        final error =
            await ref.read(deudoresProvider.notifier).eliminar(resumen.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Deuda eliminada.');
        }
      },
    );
  }
}

// ── Panel formulario ──────────────────────────────────────────────────────────

class _PanelFormulario extends ConsumerWidget {
  const _PanelFormulario();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(deudorEditorProvider);

    return Column(
      children: [
        _CabeceraFormulario(
          esEdicion: editor.esEdicion,
          guardando: editor.guardando,
          onCancelar: () {
            final selId =
                ref.read(deudoresProvider).value?.deudorSeleccionadoId;
            if (selId != null) {
              ref.read(deudoresProvider.notifier).abrirDetalle(selId);
            } else {
              ref.read(deudoresProvider.notifier).cerrarPanel();
            }
          },
          onGuardar: () => _guardar(context, ref),
        ),
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: _ContenidoFormulario(),
          ),
        ),
      ],
    );
  }

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final error = await ref.read(deudorEditorProvider.notifier).guardar();
    if (!context.mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      final esEdicion = ref.read(deudorEditorProvider).esEdicion;
      SnackBarMensaje.success(
        context,
        esEdicion ? 'Deuda actualizada.' : 'Deuda creada correctamente.',
      );
    }
  }
}

class _ContenidoFormulario extends ConsumerWidget {
  const _ContenidoFormulario();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esEdicion = ref.watch(
      deudorEditorProvider.select((s) => s.esEdicion),
    );

    return Column(
      children: [
        const SeccionDatosDeudorWidget(),
        if (!esEdicion) ...[
          const SizedBox(height: 14),
          const SeccionPagoInicialWidget(),
        ],
      ],
    );
  }
}

class _CabeceraFormulario extends StatelessWidget {
  const _CabeceraFormulario({
    required this.esEdicion,
    required this.guardando,
    required this.onCancelar,
    required this.onGuardar,
  });

  final bool esEdicion;
  final bool guardando;
  final VoidCallback onCancelar;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: ColoresApp.bgCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esEdicion ? 'Editar deuda' : 'Nueva deuda',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textDark,
                  ),
                ),
                Text(
                  esEdicion
                      ? 'Modifica los datos y guarda'
                      : 'El número se generará automáticamente',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColoresApp.textMedium,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onCancelar,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.textMedium,
              side: const BorderSide(color: ColoresApp.border),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: guardando ? null : onGuardar,
            icon: guardando
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(esEdicion ? 'Guardar cambios' : 'Crear deuda'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
