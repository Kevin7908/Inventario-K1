import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../../backend/features/ventas/facturas/modelo/factura_resumen.dart';
import '../../../../../core/currency_ext.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share2/feedback/dialogo_confirmacion.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/estado_error_widget.dart';
import '../../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../detalle_factura/factura_detalle_page.dart';
import '../provider/facturas_provider.dart';
import '../widgets/dialogo_crear_factura.dart';
import '../widgets/factura_fila_widget.dart';

const _kAccent = ColoresApp.accentAmber;

class FacturasVista extends ConsumerWidget {
  const FacturasVista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAsync = ref.watch(facturasProvider);

    return estadoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EstadoErrorWidget(
        mensaje: e.toString(),
        alReintentar: () => ref.invalidate(facturasProvider),
      ),
      data: (_) => const _ContenidoFacturas(),
    );
  }
}

// ── Cuerpo principal ──────────────────────────────────────────────────────────

class _ContenidoFacturas extends ConsumerWidget {
  const _ContenidoFacturas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista      = ref.watch(facturasFiltradas);
    final estadoPago = ref.watch(facturasProvider).value?.filtroEstadoPago;
    final hayFiltro  = (ref.watch(facturasProvider).value?.filtroBusqueda.isNotEmpty ?? false) ||
                       estadoPago != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── KPI cards ──────────────────────────────────────────────────
          const _KpiRow(),
          const SizedBox(height: 20),
          // ── Barra: búsqueda + chips + botón ────────────────────────────
          _BarraAcciones(
            filtroActual: estadoPago,
            onFiltrar: (e) =>
                ref.read(facturasProvider.notifier).filtrarEstadoPago(e),
            onNuevaFactura: () =>
                DialogoCrearFactura.mostrar(context, tipoFijo: TipoVenta.servicio),
          ),
          const SizedBox(height: 8),
          // ── Tabla ───────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ColoresApp.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColoresApp.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const FacturaTablaEncabezado(),
                  Expanded(
                    child: lista.isEmpty
                        ? EstadoVacioWidget(
                            icono: Icons.request_quote_outlined,
                            textoSinDatos: 'Sin facturas',
                            textoSinResultados:
                                'No hay facturas que coincidan.',
                            textoCTA:
                                'Crea una nueva factura con el botón de arriba.',
                            hayFiltro: hayFiltro,
                          )
                        : _ListaFacturas(
                            facturas:  lista,
                            onTap: (f) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FacturaDetallePage(facturaId: f.id),
                              ),
                            ),
                            onEliminar: (f) =>
                                _confirmarEliminar(context, ref, f),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(
      BuildContext context, WidgetRef ref, FacturaResumen f) {
    // No se ofrece «eliminar»: una factura es un documento contable y solo se
    // anula. Queda en la lista, marcada, con su número.
    DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Anular la factura ${f.numeroFactura}?',
      mensaje: 'Se devolverá al inventario lo que había salido. La factura no '
          'se borra: queda registrada como anulada.',
      textoConfirmar: 'Anular factura',
    ).then((confirmado) async {
      if (confirmado != true) return;
      final error = await ref.read(facturasProvider.notifier).anular(f.id);
      if (!context.mounted) return;
      if (error != null) {
        SnackBarMensaje.error(context, error);
      } else {
        SnackBarMensaje.success(context, 'Factura anulada.');
      }
    });
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────

class _KpiRow extends ConsumerWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(facturasKpisProvider);
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            titulo: 'Cobrado este mes',
            valor: kpis.totalMes.toCompactCop(),
            subtitulo: '${kpis.count} facturas en total',
            acento: ColoresApp.accentGreen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _KpiCard(
            titulo: 'Saldo pendiente',
            valor: kpis.pendiente.toCompactCop(),
            subtitulo: 'Por cobrar',
            acento: _kAccent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _KpiCard(
            titulo: 'Total cobrado',
            valor: kpis.cobrado.toCompactCop(),
            subtitulo: 'Acumulado',
            acento: ColoresApp.primary,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.acento,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final Color  acento;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: acento, width: 3)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              color: ColoresApp.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: acento,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 11, color: ColoresApp.textLight),
          ),
        ],
      ),
    );
  }
}

// ── Barra de acciones ─────────────────────────────────────────────────────────

class _BarraAcciones extends ConsumerWidget {
  const _BarraAcciones({
    required this.filtroActual,
    required this.onFiltrar,
    required this.onNuevaFactura,
  });

  final EstadoPago?              filtroActual;
  final ValueChanged<EstadoPago?> onFiltrar;
  final VoidCallback             onNuevaFactura;

  static const _chips = <({String label, EstadoPago? estado})>[
    (label: 'Todas',      estado: null),
    (label: 'Pendientes', estado: EstadoPago.pendiente),
    (label: 'Pagadas',    estado: EstadoPago.pagado),
    (label: 'Anuladas',   estado: EstadoPago.anulada),
  ];

  static Color _chipColor(EstadoPago? e) => switch (e) {
        null                 => ColoresApp.textDark,
        EstadoPago.pendiente => _kAccent,
        EstadoPago.pagado    => ColoresApp.accentGreen,
        EstadoPago.anulada   => ColoresApp.accentRed,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: BarraBusquedaWidget(
            placeholder: 'Buscar por factura, cliente…',
            debounceMs: 280,
            alCambiar: (q) =>
                ref.read(facturasProvider.notifier).buscar(q),
          ),
        ),
        const SizedBox(width: 10),
        ..._chips.map((c) {
          final sel   = filtroActual == c.estado;
          final color = _chipColor(c.estado);
          return Padding(
            padding: const EdgeInsets.only(left: 5),
            child: _FiltroChip(
              label:       c.label,
              seleccionado: sel,
              color:       color,
              onTap: () => onFiltrar(sel ? null : c.estado),
            ),
          );
        }),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onNuevaFactura,
          icon: const Icon(Icons.add_rounded, size: 15),
          label: const Text('Nueva Factura'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            elevation: 0,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
    required this.label,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  final String       label;
  final bool         seleccionado;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color:  seleccionado ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado ? color : ColoresApp.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : ColoresApp.textMedium,
          ),
        ),
      ),
    );
  }
}

// ── Lista de facturas ─────────────────────────────────────────────────────────

class _ListaFacturas extends StatelessWidget {
  const _ListaFacturas({
    required this.facturas,
    required this.onTap,
    required this.onEliminar,
  });

  final List<FacturaResumen>          facturas;
  final ValueChanged<FacturaResumen>  onTap;
  final ValueChanged<FacturaResumen>  onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: facturas.length,
      addAutomaticKeepAlives: false,
      itemBuilder: (_, i) {
        final f = facturas[i];
        return FacturaFilaWidget(
          key:       ValueKey(f.id),
          factura:   f,
          onTap:     () => onTap(f),
          onEliminar: () => onEliminar(f),
        );
      },
    );
  }
}
