import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/deudores/resultado/resultado_cierre_credito.dart';
import '../../../../../core/formato.dart';
import '../../../../share/share.dart';
import '../../../deudores/provider/deudores_providers.dart';
import '../provider/orden_editor_provider.dart';

/// Cerrar la orden a crédito: la moto se va y el cliente queda debiendo.
///
/// **Es lo que impide el descuento doble de inventario.** Antes había que
/// anotar el repuesto en la orden —que lo saca del estante— y otra vez en
/// Cuentas por cobrar para que constara qué se fió, y el inventario descontaba
/// las dos veces. Aquí la deuda nace con las líneas de la orden ya dentro y
/// **sin volver a mover stock**.
///
/// Parámetros:
/// - [ordenId]: la orden que se cierra.
/// - [numero] y [total]: los de la orden, para poder decir qué se está
///   fiando sin volver a consultarlos.
///
/// Ejemplo:
/// ```dart
/// await DialogoCerrarACredito.mostrar(
///   context,
///   ordenId: 41,
///   numero: 'ORD-0041',
///   total: 159000,
/// );
/// ```
class DialogoCerrarACredito extends ConsumerStatefulWidget {
  const DialogoCerrarACredito({
    super.key,
    required this.ordenId,
    required this.numero,
    required this.total,
  });

  final int ordenId;
  final String numero;
  final int total;

  static Future<bool?> mostrar(
    BuildContext context, {
    required int ordenId,
    required String numero,
    required int total,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => DialogoCerrarACredito(
          ordenId: ordenId,
          numero: numero,
          total: total,
        ),
      );

  @override
  ConsumerState<DialogoCerrarACredito> createState() =>
      _DialogoCerrarACreditoState();
}

class _DialogoCerrarACreditoState extends ConsumerState<DialogoCerrarACredito> {
  final _notas = TextEditingController();

  /// Quince días es el plazo que el taller da por defecto. Se puede quitar:
  /// una deuda sin plazo es válida y no vence sola.
  DateTime? _vence = DateTime.now().add(const Duration(days: 15));
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    // Lo que esté esperando su retardo se escribe antes: el editor guarda con
    // pausa, y sin esto la última línea agregada no viajaría a la deuda.
    await ref.read(ordenEditorProvider(widget.ordenId).notifier).guardarAhora();

    final resultado =
        await ref.read(repositorioDeudoresProvider).cerrarOrdenACredito(
              ordenId: widget.ordenId,
              fechaVencimiento: _vence,
              notas: _notas.text,
            );

    if (!mounted) return;

    switch (resultado) {
      case DeudaAbierta(:final numero):
        Navigator.of(context).pop(true);
        MensajeApp.exito(
          context,
          'La orden ${widget.numero} quedó fiada en la deuda $numero',
        );
      case CierreRechazado(:final mensaje):
        setState(() {
          _guardando = false;
          _error = mensaje;
        });
    }
  }

  void _cancelar() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    return AtajosFormulario(
      alGuardar: _guardando ? null : _cerrar,
      alCancelar: _cancelar,
      child: Dialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Cerrar a crédito', style: TipografiaApp.heading3),
                const SizedBox(height: 4),
                Text(
                  'La moto se va y el cliente queda debiendo '
                  '${formatearPrecio(widget.total)}. Se abre la deuda con las '
                  'líneas de la ${widget.numero} ya dentro.',
                  style: TipografiaApp.caption
                      .copyWith(color: ColoresApp.textMuted),
                ),
                const SizedBox(height: 16),
                const AvisoEnLinea(
                  mensaje: 'El inventario no se vuelve a mover: los repuestos '
                      'salieron del estante al anotarlos en la orden. La '
                      'deuda queda enlazada y sus líneas se corrigen aquí.',
                  tono: TonoAviso.informacion,
                ),
                const SizedBox(height: 20),
                CampoFecha(
                  etiqueta: 'Plazo para pagar (opcional)',
                  valor: _vence,
                  formatear: formatearFecha,
                  primeraFecha: DateTime.now(),
                  ultimaFecha: DateTime.now().add(const Duration(days: 365)),
                  alCambiar: (fecha) => setState(() => _vence = fecha),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  etiqueta: 'Nota (opcional)',
                  controlador: _notas,
                  placeholder: 'Qué se acordó con el cliente…',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AvisoEnLinea(mensaje: _error!, tono: TonoAviso.error),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BotonSecundario(
                      etiqueta: 'Cancelar',
                      alPresionar: _guardando ? null : _cancelar,
                    ),
                    const SizedBox(width: 12),
                    BotonPrimario(
                      etiqueta: _guardando ? 'Cerrando…' : 'Cerrar a crédito',
                      icono: Icons.attach_money_rounded,
                      alPresionar: _guardando ? null : _cerrar,
                    ),
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
