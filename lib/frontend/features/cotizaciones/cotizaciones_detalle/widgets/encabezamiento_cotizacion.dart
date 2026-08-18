import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../../../motos/provider/motos_provider.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Cliente, moto y vigencia. Van en el pie y no en la cabecera porque son lo
/// último que se completa: primero se arma la lista, después se dice para
/// quién es.
class EncabezamientoCotizacion extends ConsumerWidget {
  const EncabezamientoCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = cotizacionEditorProvider(cotizacionId);
    final datos = ref.watch(
      provider.select((s) => (
            cliente: s.value?.cliente,
            moto: s.value?.moto,
            vigencia: s.value?.vigenciaHasta,
          )),
    );
    final notifier = ref.read(provider.notifier);

    final clientes =
        ref.watch(catalogoClientesProvider).value ?? const <Cliente>[];
    final todasLasMotos =
        ref.watch(catalogoMotosProvider).value ?? const <Moto>[];
    // Con cliente elegido, ofrecer las motos de los demás solo estorba.
    final motos = datos.cliente == null
        ? todasLasMotos
        : todasLasMotos
            .where((m) => m.clienteId == datos.cliente!.id)
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampoBusqueda<Cliente>(
          etiqueta: 'Cliente',
          valor: datos.cliente,
          opciones: clientes,
          constructorEtiqueta: (c) => c.nombreCompleto,
          constructorDetalle: (c) => c.telefono,
          placeholder: 'Mostrador',
          alCambiar: notifier.seleccionarCliente,
        ),
        const SizedBox(height: 12),
        CampoBusqueda<Moto>(
          etiqueta: 'Moto',
          valor: datos.moto,
          opciones: motos,
          constructorEtiqueta: (m) => m.nombreDisplay,
          constructorDetalle: (m) => m.placa,
          placeholder: 'Sin moto',
          alCambiar: notifier.seleccionarMoto,
        ),
        const SizedBox(height: 12),
        CampoFecha(
          etiqueta: 'Vigente hasta',
          valor: datos.vigencia,
          formatear: formatearFecha,
          alCambiar: notifier.cambiarVigencia,
        ),
      ],
    );
  }
}
