import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/bitacora/modelo/entrada_bitacora.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/selector_cuenta.dart';
import '../provider/bitacora_providers.dart';
import 'estilo_accion.dart';

/// Los chips de acción: creó, modificó, eliminó, anuló.
///
/// Van como chips y no dentro de un desplegable porque son cuatro y son lo que
/// más se filtra: «enséñame los borrados» es la pregunta que trae a alguien a
/// esta pantalla. Tocar el que ya está puesto lo quita.
class ChipsAccion extends ConsumerWidget {
  const ChipsAccion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activa = ref.watch(
      bitacoraListaProvider.select((s) => s.value?.accion),
    );
    final notifier = ref.read(bitacoraListaProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final accion in AccionAuditada.values)
          ChipFiltro(
            etiqueta: accion.etiqueta,
            icono: EstiloAccion.de(accion).icono,
            seleccionado: activa == accion,
            colorActivo: EstiloAccion.de(accion).color,
            alPresionar: () => notifier.filtrarPorAccion(accion),
          ),
      ],
    );
  }
}

/// Quién, sobre qué módulo y entre qué fechas.
///
/// Los cuatro caben en una fila en una ventana de escritorio y se apilan
/// cuando no. Cada uno vuelve a la primera página al cambiar, porque el
/// conjunto que se está paginando pasó a ser otro.
class FiltrosBitacora extends ConsumerWidget {
  const FiltrosBitacora({super.key});

  /// El valor que representa «cualquiera» en los dos desplegables. `null` no
  /// sirve: `SelectorWidget` lo usaría como «sin elegir» y no lo pintaría.
  static const _todos = 'TODOS';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(bitacoraListaProvider).value;
    if (estado == null) return const SizedBox.shrink();

    final notifier = ref.read(bitacoraListaProvider.notifier);

    return FilaCampos(
      // Quién y Módulo llevan nombres largos; las fechas caben en la mitad.
      pesos: const [3, 3, 2, 2],
      hijos: [
        SelectorCuenta(
          usuarioId: estado.usuarioId,
          alCambiar: notifier.filtrarPorUsuario,
        ),
        SelectorWidget<String>(
          etiqueta: 'Módulo',
          valor: estado.entidad?.codigo ?? _todos,
          opciones: [
            _todos,
            for (final e in EntidadAuditada.values) e.codigo,
          ],
          constructorEtiqueta: (codigo) => codigo == _todos
              ? 'Todos'
              : EntidadAuditada.desdeCodigo(codigo).etiqueta,
          alCambiar: (codigo) => notifier.filtrarPorEntidad(
            codigo == _todos ? null : EntidadAuditada.desdeCodigo(codigo),
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
