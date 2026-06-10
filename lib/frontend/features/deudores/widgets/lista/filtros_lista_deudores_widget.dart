import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/backend/features/deudores/enum/enum_deudor.dart';
import 'package:inventario_k1/core/debounce.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import 'package:inventario_k1/frontend/share/widgets/output/chip_filtro_widget.dart';

import '../../provider/deudores_provider.dart';

class FiltrosListaDeudoresWidget extends ConsumerStatefulWidget {
  const FiltrosListaDeudoresWidget({super.key});

  @override
  ConsumerState<FiltrosListaDeudoresWidget> createState() =>
      _FiltrosListaDeudoresWidgetState();
}

class _FiltrosListaDeudoresWidgetState
    extends ConsumerState<FiltrosListaDeudoresWidget> {
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _onBuscar(String valor) {
    _debouncer(() => ref.read(deudoresProvider.notifier).buscar(valor));
  }

  @override
  Widget build(BuildContext context) {
    final filtroEstado = ref.watch(
      deudoresProvider.select((s) => s.asData?.value.filtroEstado),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          _BarraBusquedaDeudores(onCambiar: _onBuscar),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChipFiltro(
                  etiqueta: 'Todas',
                  seleccionado: filtroEstado == null,
                  alPresionar: () =>
                      ref.read(deudoresProvider.notifier).filtrarEstado(null),
                ),
                const SizedBox(width: 6),
                ChipFiltro(
                  etiqueta: 'Activas',
                  seleccionado: filtroEstado == EstadoDeudor.activa,
                  color: ColoresApp.primary,
                  alPresionar: () => ref
                      .read(deudoresProvider.notifier)
                      .filtrarEstado(EstadoDeudor.activa),
                ),
                const SizedBox(width: 6),
                ChipFiltro(
                  etiqueta: 'Vencidas',
                  seleccionado: filtroEstado == EstadoDeudor.vencida,
                  color: ColoresApp.statusPending,
                  alPresionar: () => ref
                      .read(deudoresProvider.notifier)
                      .filtrarEstado(EstadoDeudor.vencida),
                ),
                const SizedBox(width: 6),
                ChipFiltro(
                  etiqueta: 'Pagadas',
                  seleccionado: filtroEstado == EstadoDeudor.pagada,
                  color: ColoresApp.statusPaid,
                  alPresionar: () => ref
                      .read(deudoresProvider.notifier)
                      .filtrarEstado(EstadoDeudor.pagada),
                ),
                const SizedBox(width: 6),
                ChipFiltro(
                  etiqueta: 'Incobrables',
                  seleccionado: filtroEstado == EstadoDeudor.incobrable,
                  color: ColoresApp.statusDebt,
                  alPresionar: () => ref
                      .read(deudoresProvider.notifier)
                      .filtrarEstado(EstadoDeudor.incobrable),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraBusquedaDeudores extends StatelessWidget {
  const _BarraBusquedaDeudores({required this.onCambiar});

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
          hintText: 'Buscar por cliente, número o concepto…',
          hintStyle:
              TextStyle(color: ColoresApp.textLight, fontSize: 12.5),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: ColoresApp.textLight,
            size: 16,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
