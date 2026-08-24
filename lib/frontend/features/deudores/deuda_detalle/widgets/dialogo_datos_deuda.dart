import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share2/share2.dart';
import '../provider/deuda_editor_provider.dart';

/// Los datos de la cabecera de una deuda: por qué se debe, cuánto, hasta
/// cuándo y qué se anotó.
///
/// **Aquí sí hay botón de guardar**, al revés que en el diálogo de una
/// reserva. Una reserva se persiste sola porque se arma línea a línea; una
/// deuda es una cabecera que se teclea de una vez, y escribir la base a cada
/// letra del concepto no le hace falta a nadie.
///
/// El monto **no puede bajar de lo ya cobrado**: el repositorio lo rechaza y
/// el motivo llega escrito, con la cifra, para que el usuario sepa hasta dónde
/// puede bajarlo.
class DialogoDatosDeuda extends ConsumerStatefulWidget {
  const DialogoDatosDeuda({super.key, required this.deudaId});

  final int deudaId;

  static Future<void> mostrar(BuildContext context, {required int deudaId}) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoDatosDeuda(deudaId: deudaId),
      );

  @override
  ConsumerState<DialogoDatosDeuda> createState() => _DialogoDatosDeudaState();
}

class _DialogoDatosDeudaState extends ConsumerState<DialogoDatosDeuda> {
  late final TextEditingController _concepto;
  late final TextEditingController _monto;
  late final TextEditingController _notas;

  DateTime? _vence;
  bool _guardando = false;
  String? _error;

  /// Lo ya cobrado, para no dejar bajar el monto por debajo.
  int _cobrado = 0;
  bool _editable = true;

  @override
  void initState() {
    super.initState();
    // El estado inicial se lee una sola vez: mientras el diálogo está abierto
    // nadie más escribe esta deuda, y releerlo en `build` pisaría lo tecleado.
    final estado = ref.read(deudaEditorProvider(widget.deudaId)).value;
    _concepto = TextEditingController(text: estado?.deuda.concepto ?? '');
    _monto = TextEditingController(text: '${estado?.montoTotal ?? 0}');
    _notas = TextEditingController(text: estado?.deuda.notas ?? '');
    _vence = estado?.deuda.fechaVencimiento;
    _cobrado = estado?.montoPagado ?? 0;
    _editable = estado?.editable ?? false;
  }

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    _notas.dispose();
    super.dispose();
  }

  int get _montoTotal => int.tryParse(_monto.text) ?? 0;

  bool get _puedeGuardar =>
      _editable &&
      !_guardando &&
      _concepto.text.trim().isNotEmpty &&
      _montoTotal >= _cobrado &&
      _montoTotal > 0;

  void _cerrar() => Navigator.of(context).pop();

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    final notas = _notas.text.trim();
    final resultado = await ref
        .read(deudaEditorProvider(widget.deudaId).notifier)
        .actualizarDatos(
          concepto: _concepto.text.trim(),
          montoTotal: _montoTotal,
          fechaVencimiento: _vence,
          notas: notas.isEmpty ? null : notas,
        );

    if (!mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      setState(() {
        _guardando = false;
        _error = mensaje;
      });
    } else {
      _cerrar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bajoLoCobrado = _montoTotal < _cobrado;

    return AtajosFormulario(
      alGuardar: _guardar,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Datos de la deuda', style: TipografiaApp.heading3),
              const SizedBox(height: 6),
              Text(
                _editable
                    ? 'Por qué se debe, cuánto y hasta cuándo.'
                    : 'Esta deuda ya está cerrada: se lee, no se cambia.',
                style: TipografiaApp.caption,
              ),
              const SizedBox(height: 20),
              CampoTexto(
                etiqueta: 'Concepto',
                controlador: _concepto,
                placeholder: 'Por qué queda debiendo…',
                habilitado: _editable,
                alCambiar: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Monto total',
                controlador: _monto,
                placeholder: '0',
                soloEnteros: true,
                habilitado: _editable,
                alCambiar: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                bajoLoCobrado
                    ? 'El cliente ya entregó ${formatearPrecio(_cobrado)}: la '
                        'deuda no puede quedar por debajo de eso.'
                    : 'Cobrado hasta ahora: ${formatearPrecio(_cobrado)}.',
                style: TipografiaApp.caption.copyWith(
                  fontSize: 11.5,
                  color: bajoLoCobrado
                      ? ColoresApp.statusDanger
                      : ColoresApp.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              CampoFecha(
                etiqueta: 'Vence',
                valor: _vence,
                formatear: formatearFecha,
                placeholder: 'Opcional: hasta cuándo tiene plazo',
                alCambiar:
                    _editable ? (fecha) => setState(() => _vence = fecha) : null,
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Notas',
                controlador: _notas,
                placeholder: 'Opcional: lo que se acordó…',
                lineas: 3,
                habilitado: _editable,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TipografiaApp.caption.copyWith(
                    color: ColoresApp.statusDanger,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BotonSecundario(
                    etiqueta: _editable ? 'Cancelar' : 'Listo',
                    alPresionar: _guardando ? null : _cerrar,
                  ),
                  if (_editable) ...[
                    const SizedBox(width: 12),
                    BotonPrimario(
                      etiqueta: _guardando ? 'Guardando…' : 'Guardar',
                      icono: Icons.check_rounded,
                      alPresionar: _puedeGuardar ? () => unawaited(_guardar()) : null,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
