import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../../clientes/provider/cliente_provider.dart';
import '../../../motos/provider/motos_provider.dart';
import '../provider/cotizacion_editor_provider.dart';

/// Para quién es la cotización: cliente, moto, vigencia y notas.
///
/// Los cuatro campos viven en un diálogo y no en el panel porque son lo último
/// que se completa —primero se arma la lista, después se dice para quién es— y
/// porque apilados ocupaban media columna de 360 px. En el panel queda solo la
/// [FichaResumen] que abre este cuadro.
///
/// No hay botón de guardar: la cotización se persiste sola, así que cada campo
/// avisa al editor en cuanto cambia y "Listo" solo cierra.
class DialogoDatosCotizacion extends ConsumerStatefulWidget {
  const DialogoDatosCotizacion({super.key, required this.cotizacionId});

  final int? cotizacionId;

  static Future<void> mostrar(
    BuildContext context, {
    required int? cotizacionId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DialogoDatosCotizacion(cotizacionId: cotizacionId),
    );
  }

  @override
  ConsumerState<DialogoDatosCotizacion> createState() =>
      _DialogoDatosCotizacionState();
}

class _DialogoDatosCotizacionState
    extends ConsumerState<DialogoDatosCotizacion> {
  late final TextEditingController _notas;

  @override
  void initState() {
    super.initState();
    // El texto se copia una sola vez al abrir: mientras el cuadro está en
    // pantalla, la fuente de verdad de lo tecleado es el controlador.
    final estado = ref.read(cotizacionEditorProvider(widget.cotizacionId)).value;
    _notas = TextEditingController(text: estado?.notas ?? '');
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  void _cerrar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final provider = cotizacionEditorProvider(widget.cotizacionId);
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

    return AtajosFormulario(
      alGuardar: _cerrar,
      alCancelar: _cerrar,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: ColoresApp.shadowMedium,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Datos de la cotización',
                  style: TipografiaApp.heading3),
              const SizedBox(height: 20),
              CampoBusqueda<Cliente>(
                etiqueta: 'Cliente',
                valor: datos.cliente,
                opciones: clientes,
                constructorEtiqueta: (c) => c.nombreCompleto,
                constructorDetalle: (c) => c.telefono,
                placeholder: 'Mostrador',
                alCambiar: notifier.seleccionarCliente,
              ),
              const SizedBox(height: 14),
              CampoBusqueda<Moto>(
                etiqueta: 'Moto',
                valor: datos.moto,
                opciones: motos,
                constructorEtiqueta: (m) => m.nombreDisplay,
                constructorDetalle: (m) => m.placa,
                placeholder: 'Sin moto',
                alCambiar: notifier.seleccionarMoto,
              ),
              const SizedBox(height: 14),
              CampoFecha(
                etiqueta: 'Vigente hasta',
                valor: datos.vigencia,
                formatear: formatearFecha,
                alCambiar: notifier.cambiarVigencia,
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Notas',
                controlador: _notas,
                placeholder: 'Condiciones, tiempos de entrega…',
                lineas: 3,
                alCambiar: notifier.cambiarNotas,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: BotonPrimario(etiqueta: 'Listo', alPresionar: _cerrar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
