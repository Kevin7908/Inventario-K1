import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/core/debounce.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/output/chip_filtro_widget.dart';

import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../provider/reservas_provider.dart';

class FiltrosListaReservasWidget extends ConsumerStatefulWidget {
  const FiltrosListaReservasWidget({super.key});

  @override
  ConsumerState<FiltrosListaReservasWidget> createState() =>
      _FiltrosListaReservasWidgetState();
}

class _FiltrosListaReservasWidgetState
    extends ConsumerState<FiltrosListaReservasWidget> {
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _onBuscar(String valor) {
    _debouncer(() => ref.read(reservasProvider.notifier).buscar(valor));
  }

  @override
  Widget build(BuildContext context) {
    final filtroEstado = ref.watch(
      reservasProvider.select((s) => s.asData?.value.filtroEstado),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          _BarraBusquedaLista(onCambiar: _onBuscar),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChipFiltro(
                  etiqueta: 'Todas',
                  seleccionado: filtroEstado == null,
                  alPresionar: () => ref
                      .read(reservasProvider.notifier)
                      .filtrarEstado(null),
                ),
                const SizedBox(width: 6),
                ChipFiltro(
                  etiqueta: 'Activas',
                  seleccionado: filtroEstado == EstadoReserva.activa,
                  color: ColoresApp.statusPaid,
                  alPresionar: () => ref
                      .read(reservasProvider.notifier)
                      .filtrarEstado(EstadoReserva.activa),
                ),
                const SizedBox(width: 6),
                ChipFiltro(
                  etiqueta: 'Completadas',
                  seleccionado: filtroEstado == EstadoReserva.completada,
                  color: ColoresApp.primary,
                  alPresionar: () => ref
                      .read(reservasProvider.notifier)
                      .filtrarEstado(EstadoReserva.completada),
                ),
                const SizedBox(width: 6),
                ChipFiltro(
                  etiqueta: 'Canceladas',
                  seleccionado: filtroEstado == EstadoReserva.cancelada,
                  color: ColoresApp.statusDebt,
                  alPresionar: () => ref
                      .read(reservasProvider.notifier)
                      .filtrarEstado(EstadoReserva.cancelada),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraBusquedaLista extends StatelessWidget {
  const _BarraBusquedaLista({required this.onCambiar});

  final ValueChanged<String> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresApp.border),
      ),
      child: TextField(
        onChanged: onCambiar,
        style: const TextStyle(color: ColoresApp.textDark, fontSize: 12.5),
        decoration: const InputDecoration(
          hintText: 'Buscar reserva, cliente o moto…',
          hintStyle: TextStyle(color: ColoresApp.textLight, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded, color: ColoresApp.textLight, size: 16),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
