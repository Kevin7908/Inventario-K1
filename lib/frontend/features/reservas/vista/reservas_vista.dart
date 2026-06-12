import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/dialogos/dialogo_confirmar_eliminar_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/estado_error_widget.dart';
import 'package:inventario_k1/frontend/share/widgets/output/snack_bar_mensaje.dart';
import 'package:inventario_k1/frontend/share/widgets/top_bar_widget.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../backend/features/reservas/modelo/reserva_abono.dart';
import '../../../../backend/features/reservas/modelo/reserva_item.dart';
import '../../../../backend/features/reservas/modelo/reserva_resumen.dart';
import '../provider/reservas_provider.dart';
import '../reserva_editor/provider/reserva_editor_provider.dart';
import '../widgets/detalle/badge_estado_reserva_widget.dart';
import '../widgets/detalle/card_abonos_reserva_widget.dart';
import '../widgets/detalle/card_info_general_reserva_widget.dart';
import '../widgets/detalle/card_productos_reservados_widget.dart';
import '../widgets/detalle/form_abono_inline_widget.dart';
import '../widgets/detalle/panel_resumen_financiero_widget.dart';
import '../widgets/formulario/grilla_productos_reserva_widget.dart';
import '../widgets/formulario/lista_items_reservados_widget.dart';
import '../widgets/formulario/seccion_abono_inicial_widget.dart';
import '../widgets/formulario/seccion_cliente_moto_widget.dart';
import '../widgets/formulario/totales_formulario_reserva_widget.dart';
import '../widgets/lista/filtros_lista_reservas_widget.dart';
import '../widgets/lista/kpi_reservas_widget.dart';
import '../widgets/lista/tarjeta_lista_reserva_widget.dart';

class ReservasVista extends ConsumerWidget {
  const ReservasVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      reservasProvider.select((s) => !s.hasValue && !s.hasError),
    );
    final error = ref.watch(
      reservasProvider.select((s) => s.hasError ? s.error : null),
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
          alReintentar: () => ref.invalidate(reservasProvider),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: ColoresApp.bgContent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBarReservas(),
          Expanded(
            child: _LayoutMasterDetail(),
          ),
        ],
      ),
    );
  }
}

// ── TopBar ────────────────────────────────────────────────────────────────────

class _TopBarReservas extends StatelessWidget {
  const _TopBarReservas();

  @override
  Widget build(BuildContext context) {
    return const TopBarWidget(titulo: 'Reservas');
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

// ── Panel izquierdo (lista) ───────────────────────────────────────────────────

class _PanelListaIzquierdo extends StatelessWidget {
  const _PanelListaIzquierdo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      child: Container(
        color: ColoresApp.bgCard,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KpiReservasWidget(),
            SizedBox(height: 2),
            FiltrosListaReservasWidget(),
            Divider(height: 14, color: ColoresApp.border),
            Expanded(child: _ListaReservas()),
            Divider(height: 1, color: ColoresApp.border),
            _BotonNuevaReserva(),
          ],
        ),
      ),
    );
  }
}

class _ListaReservas extends ConsumerWidget {
  const _ListaReservas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pag = ref.watch(paginacionReservasProvider);
    final seleccionadaId = ref.watch(
      reservasProvider.select((s) => s.asData?.value.reservaSeleccionadaId),
    );

    if (pag.paginadas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border_rounded,
                  size: 36, color: ColoresApp.textLight),
              SizedBox(height: 8),
              Text(
                'Sin reservas',
                style: TextStyle(
                  fontSize: 13,
                  color: ColoresApp.textLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: pag.paginadas.length,
      itemBuilder: (_, i) {
        final r = pag.paginadas[i];
        return TarjetaListaReservaWidget(
          key: ValueKey(r.id),
          reserva: r,
          seleccionada: r.id == seleccionadaId,
          onTap: () =>
              ref.read(reservasProvider.notifier).abrirDetalle(r.id),
        );
      },
    );
  }
}

class _BotonNuevaReserva extends ConsumerWidget {
  const _BotonNuevaReserva();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ElevatedButton.icon(
        onPressed: () {
          ref.invalidate(reservaEditorProvider);
          ref.read(reservasProvider.notifier).abrirNueva();
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nueva Reserva'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresApp.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      reservasProvider.select((s) => s.asData?.value.modoPanel ?? ModoPanel.vacio),
    );

    return switch (modo) {
      ModoPanel.vacio => const _EstadoVacioDetalle(),
      ModoPanel.detalle => const _PanelDetalle(),
      ModoPanel.formulario => const _PanelFormulario(),
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
          Icon(Icons.bookmark_add_outlined,
              size: 52, color: ColoresApp.textLight),
          SizedBox(height: 10),
          Text(
            'Selecciona una reserva',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textMedium,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'o crea una nueva con el botón inferior',
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
    final reservaId = ref.watch(
      reservasProvider.select((s) => s.asData?.value.reservaSeleccionadaId),
    );
    if (reservaId == null) return const _EstadoVacioDetalle();

    final detalleAsync = ref.watch(reservaDetalleProvider(reservaId));

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
        key: ValueKey(reservaId),
        resumen: detalle.resumen,
        detalleKey: ValueKey(reservaId),
        items: detalle.items,
        abonos: detalle.abonos,
      ),
    );
  }
}

class _ContenidoDetalle extends ConsumerWidget {
  const _ContenidoDetalle({
    super.key,
    required this.resumen,
    required this.detalleKey,
    required this.items,
    required this.abonos,
  });

  final ReservaResumen resumen;
  final Key detalleKey;
  final List<ReservaItem> items;
  final List<ReservaAbono> abonos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostrarFormAbono = ref.watch(
      reservasProvider
          .select((s) => s.asData?.value.mostrarFormAbono ?? false),
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
                      if (mostrarFormAbono)
                        FormAbonoInlineWidget(
                          reservaId: resumen.id,
                          saldo: resumen.saldo,
                        ),
                      CardInfoGeneralReservaWidget(resumen: resumen),
                      const SizedBox(height: 14),
                      CardProductosReservadosWidget(items: items),
                      const SizedBox(height: 14),
                      CardAbonosReservaWidget(abonos: abonos),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 260,
                  child: PanelResumenFinancieroWidget(
                    resumen: resumen,
                    onCancelar: () => _confirmarCancelar(context, ref, resumen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarCancelar(
    BuildContext context,
    WidgetRef ref,
    ReservaResumen r,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text('¿Confirmas cancelar la reserva ${r.numero}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.statusDebt,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    final error = await ref
        .read(reservasProvider.notifier)
        .cambiarEstado(r.id, EstadoReserva.cancelada);
    if (!context.mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      SnackBarMensaje.success(context, 'Reserva ${r.numero} cancelada.');
    }
  }
}

class _CabeceraDetalle extends ConsumerWidget {
  const _CabeceraDetalle({required this.resumen});

  final ReservaResumen resumen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostrarFormAbono = ref.watch(
      reservasProvider
          .select((s) => s.asData?.value.mostrarFormAbono ?? false),
    );
    final notifier = ref.read(reservasProvider.notifier);

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
                    BadgeEstadoReservaWidget(estado: resumen.estado),
                  ],
                ),
                Text(
                  'Creada el '
                  '${resumen.creadoEn.year}-${resumen.creadoEn.month.toString().padLeft(2, '0')}-${resumen.creadoEn.day.toString().padLeft(2, '0')}'
                  '${resumen.cotizacionId != null ? '  ·  📋 Cotización #${resumen.cotizacionId}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ColoresApp.textMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (resumen.estado == EstadoReserva.activa)
                ElevatedButton.icon(
                  onPressed: notifier.toggleFormAbono,
                  icon: Icon(
                    mostrarFormAbono
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.add_rounded,
                    size: 16,
                  ),
                  label: Text(
                      mostrarFormAbono ? 'Cerrar abono' : 'Registrar abono'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
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

  final ReservaResumen resumen;

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
                  side: const BorderSide(color: ColoresApp.border)),
            ),
            onPressed: () {
              ref.invalidate(reservaEditorProvider);
              ref.read(reservasProvider.notifier).abrirEditar(resumen.id);
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
      tipoElemento: 'reserva',
      onConfirmar: () async {
        final error =
            await ref.read(reservasProvider.notifier).eliminar(resumen.id);
        if (!context.mounted) return;
        if (error != null) {
          SnackBarMensaje.error(context, error);
        } else {
          SnackBarMensaje.success(context, 'Reserva eliminada.');
        }
      },
    );
  }
}

// ── Panel formulario (nueva / editar) ─────────────────────────────────────────

class _PanelFormulario extends ConsumerStatefulWidget {
  const _PanelFormulario();

  @override
  ConsumerState<_PanelFormulario> createState() => _PanelFormularioState();
}

class _PanelFormularioState extends ConsumerState<_PanelFormulario> {
  late final ValueNotifier<Moto?> _motoNotifier;

  @override
  void initState() {
    super.initState();
    _motoNotifier = ValueNotifier(null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reservaId = ref.read(reservasProvider).value?.reservaSeleccionadaId;
      if (reservaId != null) {
        final reservas = ref.read(reservasProvider).value?.reservas ?? [];
        final reserva = reservas.where((r) => r.id == reservaId).firstOrNull;
        ref.read(reservaEditorProvider.notifier).inicializar(reserva);
      }
    });
  }

  @override
  void dispose() {
    _motoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReservaEditorState>(reservaEditorProvider, (prev, next) {
      if (prev?.moto?.id != next.moto?.id) {
        _motoNotifier.value = next.moto;
      }
    });

    final estado = ref.watch(reservaEditorProvider);

    return Column(
      children: [
        _CabeceraFormulario(
          esEdicion: estado.esEdicion,
          guardando: estado.guardando,
          onCancelar: () {
            final selId = ref.read(reservasProvider).value?.reservaSeleccionadaId;
            if (selId != null) {
              ref.read(reservasProvider.notifier).abrirDetalle(selId);
            } else {
              ref.read(reservasProvider.notifier).cerrarPanel();
            }
          },
          onGuardar: () => _guardar(context),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SeccionClienteMotoWidget(motoNotifier: _motoNotifier),
                const SizedBox(height: 14),
                const GrillaProductosReservaWidget(),
                const SizedBox(height: 14),
                const ListaItemsReservadosWidget(),
                if (!estado.esEdicion) ...[
                  const SizedBox(height: 14),
                  const SeccionAbonoInicialWidget(),
                ],
                const SizedBox(height: 14),
                TotalesFormularioReservaWidget(
                  total: estado.total,
                  abonoInicial: estado.abonoInicial,
                  saldo: estado.saldo,
                  esEdicion: estado.esEdicion,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _guardar(BuildContext context) async {
    final error = await ref.read(reservaEditorProvider.notifier).guardar();
    if (!context.mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
    } else {
      final esEdicion = ref.read(reservaEditorProvider).esEdicion;
      SnackBarMensaje.success(
        context,
        esEdicion ? 'Reserva actualizada.' : 'Reserva creada correctamente.',
      );
    }
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
                  esEdicion ? 'Editar Reserva' : 'Nueva Reserva',
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
                    fontSize: 11,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            label: Text(esEdicion ? 'Guardar cambios' : 'Crear reserva'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
