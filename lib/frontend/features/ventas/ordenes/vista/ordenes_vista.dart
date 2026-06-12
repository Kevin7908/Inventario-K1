import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../backend/features/ventas/ordenes/modelo/orden_resumen.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../../share/widgets/output/estado_vacio_widget.dart';
import '../detalle_orden/orden_detalle_page.dart';
import '../provider/ordenes_provider.dart';
import '../widgets/dialogo_crear_editar_orden.dart';

// Acento para órdenes
const _kAccent = ColoresApp.primary;

class OrdenesVista extends ConsumerStatefulWidget {
  const OrdenesVista({super.key});

  @override
  ConsumerState<OrdenesVista> createState() => _OrdenesVistaState();
}

class _OrdenesVistaState extends ConsumerState<OrdenesVista> {
  int? _selectedId;

  void _seleccionar(int id) {
    if (_selectedId != id) setState(() => _selectedId = id);
  }

  void _deseleccionar() => setState(() => _selectedId = null);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Lista (340 px) ────────────────────────────────────────────────
        SizedBox(
          width: 340,
          child: _OrdenesListaPanel(
            selectedId: _selectedId,
            onSeleccionar: _seleccionar,
            onNuevaOrden: () => DialogoCrearEditarOrden.mostrar(context),
          ),
        ),
        Container(width: 1, color: ColoresApp.border),
        // ── Detalle (expandido) ───────────────────────────────────────────
        Expanded(
          child: RepaintBoundary(
            child: _selectedId == null
                ? const _EmptyStateOrden()
                : OrdenDetalleVista(
                    key:      ValueKey(_selectedId),
                    ordenId:  _selectedId!,
                    onVolver: _deseleccionar,
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Panel izquierdo de la lista ───────────────────────────────────────────────

class _OrdenesListaPanel extends ConsumerStatefulWidget {
  const _OrdenesListaPanel({
    required this.selectedId,
    required this.onSeleccionar,
    required this.onNuevaOrden,
  });

  final int?                    selectedId;
  final ValueChanged<int>       onSeleccionar;
  final VoidCallback            onNuevaOrden;

  @override
  ConsumerState<_OrdenesListaPanel> createState() => _OrdenesListaPanelState();
}

class _OrdenesListaPanelState extends ConsumerState<_OrdenesListaPanel> {
  @override
  Widget build(BuildContext context) {
    final contadores    = ref.watch(ordenesContadoresProvider);
    final lista         = ref.watch(ordenesFiltradas);
    final ordenesState  = ref.watch(ordenesProvider).value;
    final filtroActual  = ordenesState?.filtroEstado;
    final hayFiltro     = (ordenesState?.filtroBusqueda.isNotEmpty ?? false) ||
                          filtroActual != null;

    return Container(
      color: ColoresApp.bgCard,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          _ListaHeader(
            abiertas: contadores.abiertas,
            listas:   contadores.listas,
          ),
          // ── Búsqueda ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: BarraBusquedaWidget(
              placeholder: 'Buscar orden, moto, cliente…',
              debounceMs: 280,
              alCambiar: (q) =>
                  ref.read(ordenesProvider.notifier).buscar(q),
            ),
          ),
          // ── Chips de filtro ───────────────────────────────────────────
          _FiltroChips(
            filtroActual: filtroActual,
            onFiltrar: (e) =>
                ref.read(ordenesProvider.notifier).filtrarEstado(e),
          ),
          const Divider(height: 1, color: ColoresApp.border),
          // ── Lista ─────────────────────────────────────────────────────
          Expanded(
            child: lista.isEmpty
                ? EstadoVacioWidget(
                    icono: Icons.receipt_long_outlined,
                    textoSinDatos: 'Sin órdenes',
                    textoSinResultados: 'No hay órdenes que coincidan.',
                    textoCTA: 'Crea una nueva orden con el botón de abajo.',
                    hayFiltro: hayFiltro,
                  )
                : _ListaOrdenes(
                    ordenes:    lista,
                    selectedId: widget.selectedId,
                    onTap:      widget.onSeleccionar,
                  ),
          ),
          // ── Botón nueva ───────────────────────────────────────────────
          _NuevaOrdenBtn(onTap: widget.onNuevaOrden),
        ],
      ),
    );
  }
}

// ── Sub-widgets del panel izquierdo ───────────────────────────────────────────

class _ListaHeader extends StatelessWidget {
  const _ListaHeader({required this.abiertas, required this.listas});

  final int abiertas;
  final int listas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          const Text(
            'Órdenes de servicio',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textDark,
            ),
          ),
          const Spacer(),
          _CounterChip(label: '$abiertas abiertas', color: _kAccent),
          const SizedBox(width: 5),
          _CounterChip(label: '$listas listas', color: ColoresApp.accentGreen),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.label, required this.color});

  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FiltroChips extends StatelessWidget {
  const _FiltroChips({
    required this.filtroActual,
    required this.onFiltrar,
  });

  final EstadoOrden?              filtroActual;
  final ValueChanged<EstadoOrden?> onFiltrar;

  static const _opciones = <({String label, EstadoOrden? estado})>[
    (label: 'Todas',     estado: null),
    (label: 'Abiertas',  estado: EstadoOrden.abierta),
    (label: 'Listas',    estado: EstadoOrden.lista),
    (label: 'Entregadas', estado: EstadoOrden.entregada),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _opciones.map((o) {
          final sel = filtroActual == o.estado;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: _FiltroChip(
              label:       o.label,
              seleccionado: sel,
              onTap: () => onFiltrar(sel ? null : o.estado),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  final String       label;
  final bool         seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: seleccionado ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado ? _kAccent : ColoresApp.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : ColoresApp.textMedium,
          ),
        ),
      ),
    );
  }
}

class _ListaOrdenes extends StatelessWidget {
  const _ListaOrdenes({
    required this.ordenes,
    required this.selectedId,
    required this.onTap,
  });

  final List<OrdenResumen>  ordenes;
  final int?                selectedId;
  final ValueChanged<int>   onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: ordenes.length,
      addAutomaticKeepAlives: false,
      itemBuilder: (_, i) {
        final o = ordenes[i];
        return _OrdenTarjeta(
          key:          ValueKey(o.id),
          orden:        o,
          seleccionada: selectedId == o.id,
          onTap:        () => onTap(o.id),
        );
      },
    );
  }
}

class _OrdenTarjeta extends StatelessWidget {
  const _OrdenTarjeta({
    super.key,
    required this.orden,
    required this.seleccionada,
    required this.onTap,
  });

  final OrdenResumen orden;
  final bool         seleccionada;
  final VoidCallback onTap;

  static String _fmtFecha(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: seleccionada
              ? ColoresApp.primaryLight
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: seleccionada ? _kAccent : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: ColoresApp.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orden.numeroOrden,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    orden.motoDescripcion,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    orden.clienteNombre,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ColoresApp.textMedium,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _EstadoBadge(estado: orden.estado),
                const SizedBox(height: 4),
                Text(
                  _fmtFecha(orden.fechaIngreso),
                  style: const TextStyle(
                    fontSize: 10,
                    color: ColoresApp.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NuevaOrdenBtn extends StatelessWidget {
  const _NuevaOrdenBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Nueva Orden'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge de estado de orden ──────────────────────────────────────────────────

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});
  final EstadoOrden estado;

  static Color _color(EstadoOrden e) => switch (e) {
        EstadoOrden.abierta   => ColoresApp.primary,
        EstadoOrden.lista     => ColoresApp.accentGreen,
        EstadoOrden.entregada => ColoresApp.textMedium,
        EstadoOrden.anulada   => ColoresApp.accentRed,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}

// ── Empty state del detalle ───────────────────────────────────────────────────

class _EmptyStateOrden extends StatelessWidget {
  const _EmptyStateOrden();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_outlined, size: 56, color: ColoresApp.textLight),
          SizedBox(height: 12),
          Text(
            'Selecciona una orden',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textMedium,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'o crea una nueva',
            style: TextStyle(fontSize: 12, color: ColoresApp.textLight),
          ),
        ],
      ),
    );
  }
}
