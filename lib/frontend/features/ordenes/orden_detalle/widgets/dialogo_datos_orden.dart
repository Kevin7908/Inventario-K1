import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/enum/enum_ordenes.dart';
import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../provider/orden_editor_provider.dart';

/// La cabecera de la orden: kilometraje, diagnóstico, observaciones y estado.
///
/// Los cuatro viven en un diálogo y no en el panel porque son lo último que se
/// completa —primero se arma la lista de trabajo, después se cierra— y porque
/// apilados ocupaban media columna de 360 px. En el panel queda solo la
/// `FichaResumen` que abre este cuadro.
///
/// **Cliente y moto no están aquí**, a diferencia de cotizaciones: la orden se
/// abrió para una moto concreta y cambiarla a mitad sería otra orden. Si se
/// equivocó de moto, se anula y se abre la correcta —así el historial de cada
/// moto sigue siendo cierto.
///
/// No hay botón de guardar: la orden se persiste sola, así que cada campo
/// avisa al editor en cuanto cambia y "Listo" solo cierra. El **estado** es la
/// excepción: cerrar una orden mueve el inventario entero, así que se aplica
/// en el acto y su resultado se muestra aquí mismo.
class DialogoDatosOrden extends ConsumerStatefulWidget {
  const DialogoDatosOrden({super.key, required this.ordenId});

  final int ordenId;

  static Future<void> mostrar(
    BuildContext context, {
    required int ordenId,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoDatosOrden(ordenId: ordenId),
      );

  @override
  ConsumerState<DialogoDatosOrden> createState() => _DialogoDatosOrdenState();
}

class _DialogoDatosOrdenState extends ConsumerState<DialogoDatosOrden> {
  late final TextEditingController _kilometraje;
  late final TextEditingController _diagnostico;
  late final TextEditingController _observaciones;

  String? _error;

  /// Los estados que ofrece el selector. `ANULADA` no está: anular devuelve
  /// stock y no tiene vuelta atrás, así que va en su propio botón y con
  /// confirmación, no escondida en un desplegable.
  static const _estadosOfrecidos = [
    EstadoOrden.abierta,
    EstadoOrden.lista,
    EstadoOrden.entregada,
  ];

  @override
  void initState() {
    super.initState();
    // El texto se copia una sola vez al abrir: mientras el cuadro está en
    // pantalla, la fuente de verdad de lo tecleado es el controlador.
    final estado = ref.read(ordenEditorProvider(widget.ordenId)).value;
    _kilometraje =
        TextEditingController(text: '${estado?.kilometrajeEntrada ?? 0}');
    _diagnostico = TextEditingController(text: estado?.diagnostico ?? '');
    _observaciones = TextEditingController(text: estado?.observaciones ?? '');
  }

  @override
  void dispose() {
    _kilometraje.dispose();
    _diagnostico.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  void _cerrar() => Navigator.of(context).pop();

  OrdenEditorNotifier get _notifier =>
      ref.read(ordenEditorProvider(widget.ordenId).notifier);

  Future<void> _cambiarEstado(EstadoOrden nuevo) async {
    setState(() => _error = null);
    final resultado = await _notifier.cambiarEstado(nuevo);
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) setState(() => _error = mensaje);
  }

  /// Anular devuelve al inventario lo que ya había salido y conserva el número
  /// y el historial. No se borra: una orden es un registro de trabajo, igual
  /// que una factura.
  Future<void> _anular() async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Anular la orden?',
      mensaje: 'Se devuelve al inventario lo que ya se había descontado. La '
          'orden conserva su número y su historial, pero no se puede reabrir.',
    );
    if (confirmado != true || !mounted) return;

    setState(() => _error = null);
    final resultado = await _notifier.anular();
    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      setState(() => _error = mensaje);
    } else {
      _cerrar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ordenEditorProvider(widget.ordenId);
    final datos = ref.watch(
      provider.select((s) => (
            numero: s.value?.numero ?? '',
            estado: s.value?.estado ?? EstadoOrden.abierta,
            editable: s.value?.editable ?? false,
            yaSalio: s.value?.inventarioYaSalio ?? false,
          )),
    );

    return AtajosFormulario(
      alGuardar: _cerrar,
      alCancelar: _cerrar,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 460,
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Datos de la orden ${datos.numero}',
                  style: TipografiaApp.heading3,
                ),
                const SizedBox(height: 20),
                SelectorWidget<EstadoOrden>(
                  etiqueta: 'Estado',
                  valor: datos.estado,
                  opciones: _estadosOfrecidos.contains(datos.estado)
                      ? _estadosOfrecidos
                      // Una orden anulada tiene que poder verse sin que el
                      // selector la muestre como si fuera otra cosa.
                      : [datos.estado],
                  constructorEtiqueta: (e) => e.etiqueta,
                  alCambiar: _cambiarEstado,
                ),
                const SizedBox(height: 8),
                _AvisoInventario(yaSalio: datos.yaSalio),
                const SizedBox(height: 14),
                CampoTexto(
                  etiqueta: 'Kilometraje de entrada',
                  controlador: _kilometraje,
                  placeholder: '15000',
                  soloEnteros: true,
                  alCambiar: (texto) =>
                      _notifier.cambiarKilometraje(int.tryParse(texto) ?? 0),
                ),
                const SizedBox(height: 14),
                CampoTexto(
                  etiqueta: 'Qué reporta el cliente',
                  controlador: _diagnostico,
                  placeholder: 'No enciende en frío…',
                  lineas: 3,
                  alCambiar: _notifier.cambiarDiagnostico,
                ),
                const SizedBox(height: 14),
                CampoTexto(
                  etiqueta: 'Observaciones del mecánico',
                  controlador: _observaciones,
                  placeholder: 'Llega con el tanque en reserva…',
                  lineas: 3,
                  alCambiar: _notifier.cambiarObservaciones,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _Error(mensaje: _error!),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (datos.editable)
                      BotonDestructivo(
                        etiqueta: 'Anular orden',
                        icono: Icons.block_outlined,
                        alPresionar: _anular,
                      ),
                    const Spacer(),
                    BotonPrimario(etiqueta: 'Listo', alPresionar: _cerrar),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Qué le va a pasar al inventario según el estado.
///
/// Es la regla menos evidente del módulo (§1.3) y la que más sorprende: pasar
/// a `LISTA` descuenta de golpe todos los repuestos anotados. Decirlo junto al
/// selector evita la sorpresa.
class _AvisoInventario extends StatelessWidget {
  const _AvisoInventario({required this.yaSalio});

  final bool yaSalio;

  @override
  Widget build(BuildContext context) {
    final texto = yaSalio
        ? 'Los repuestos de esta orden ya salieron del inventario. Lo que se '
            'agregue ahora descuenta al instante.'
        : 'Los repuestos están solo anotados. Salen del inventario al pasar la '
            'orden a Lista o Entregada.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          yaSalio ? Icons.inventory_outlined : Icons.schedule_outlined,
          size: 14,
          color: ColoresApp.textMuted,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texto,
            style: TipografiaApp.caption.copyWith(fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.statusDangerBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: ColoresApp.statusDanger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: TipografiaApp.caption.copyWith(
                color: ColoresApp.statusDanger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
