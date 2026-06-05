import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/widgets/input/barra_busqueda_widget.dart';

import 'package:inventario_k1/backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import 'package:inventario_k1/frontend/features/cotizaciones/provider/cotizaciones_provider.dart';

class SeccionFiltrosCot extends ConsumerWidget {
  const SeccionFiltrosCot({
    super.key,
    required this.onBuscar,
  });

  final ValueChanged<String> onBuscar;

  static const _meses = [
    'Todos los meses',
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  static const _opcionesEstado = [
    'Todos los estados',
    'Vigente',
    'Por vencer',
    'Vencida',
  ];

  EstadoCotizacion? _estadoDesde(String? s) => switch (s) {
        'Vigente' => EstadoCotizacion.vigente,
        'Por vencer' => EstadoCotizacion.porVencer,
        'Vencida' => EstadoCotizacion.vencida,
        _ => null,
      };

  String _estadoA(EstadoCotizacion? e) => switch (e) {
        EstadoCotizacion.vigente => 'Vigente',
        EstadoCotizacion.porVencer => 'Por vencer',
        EstadoCotizacion.vencida => 'Vencida',
        null => 'Todos los estados',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtroEstado = ref.watch(
      cotizacionesProvider.select((s) => s.asData?.value.filtroEstado),
    );
    final filtroMes = ref.watch(
      cotizacionesProvider.select((s) => s.asData?.value.filtroMes),
    );

    final mesActual = filtroMes != null ? _meses[filtroMes] : _meses[0];
    final estadoActual = _estadoA(filtroEstado);

    return Row(
      children: [
        Expanded(
          child: BarraBusquedaWidget(
            placeholder: 'Buscar por número, cliente o moto...',
            alCambiar: onBuscar,
          ),
        ),
        const SizedBox(width: 12),
        FiltroDropdownWidget(
          valor: estadoActual,
          opciones: _opcionesEstado,
          alCambiar: (v) => ref
              .read(cotizacionesProvider.notifier)
              .filtrarEstado(_estadoDesde(v)),
        ),
        const SizedBox(width: 12),
        FiltroDropdownWidget(
          valor: mesActual,
          opciones: _meses,
          alCambiar: (v) {
            final idx = _meses.indexOf(v ?? _meses[0]);
            ref
                .read(cotizacionesProvider.notifier)
                .filtrarMes(idx == 0 ? null : idx);
          },
        ),
      ],
    );
  }
}
