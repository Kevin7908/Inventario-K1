import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/motos/modelo/moto.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../../../motos/provider/motos_provider.dart';
import '../provider/deuda_editor_provider.dart';

/// La cabecera de la deuda: en qué moto se montó, cómo se llama el fiado,
/// hasta cuándo hay plazo y qué se anotó.
///
/// **El monto no está aquí**, y esa es la diferencia con el diálogo que tenía
/// antes: la deuda vale lo que suman sus repuestos, y esos se anotan en el
/// panel de la izquierda. Un campo de monto tecleable al lado de unas líneas
/// que ya suman es la vía más corta a que las dos cifras no coincidan.
///
/// **Sí hay botón de guardar**, al revés que en el diálogo de una reserva: son
/// cuatro campos que se teclean de una vez, y escribir la base a cada letra
/// del concepto no le hace falta a nadie.
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
  late final TextEditingController _notas;

  DateTime? _vence;
  int? _motoId;
  bool _guardando = false;
  bool _editable = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // El estado inicial se lee una sola vez: mientras el diálogo está abierto
    // nadie más escribe esta cabecera, y releerlo en `build` pisaría lo
    // tecleado.
    final estado = ref.read(deudaEditorProvider(widget.deudaId)).value;
    _concepto = TextEditingController(text: estado?.concepto ?? '');
    _notas = TextEditingController(text: estado?.notas ?? '');
    _vence = estado?.fechaVencimiento;
    _motoId = estado?.motoId;
    _editable = estado?.editable ?? false;
  }

  @override
  void dispose() {
    _concepto.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _cerrar() => Navigator.of(context).pop();

  Future<void> _guardar() async {
    if (!_editable || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    final concepto = _concepto.text.trim();
    final notas = _notas.text.trim();
    final resultado = await ref
        .read(deudaEditorProvider(widget.deudaId).notifier)
        .actualizarDatos(
          motoId: _motoId,
          concepto: concepto.isEmpty ? null : concepto,
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
    final clienteId = ref.watch(
      deudaEditorProvider(widget.deudaId).select((s) => s.value?.clienteId),
    );
    final todasLasMotos =
        ref.watch(catalogoMotosProvider).value ?? const <Moto>[];
    // Solo las motos de quien debe: cargarle a alguien el repuesto de la moto
    // de otro es justo el error que la deuda tiene que poder explicar después.
    // La que ya está elegida se conserva aunque haya cambiado de dueño, para
    // no borrarla sin avisar al abrir el diálogo.
    final motos = [
      for (final m in todasLasMotos)
        if (m.clienteId == clienteId || m.id == _motoId) m,
    ];
    final moto = motos.where((m) => m.id == _motoId).firstOrNull;

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
                    ? 'En qué moto se montó, cómo se llama y hasta cuándo hay '
                        'plazo. Lo que se debe sale de los repuestos.'
                    : 'Esta deuda ya está cerrada: se lee, no se cambia.',
                style: TipografiaApp.caption,
              ),
              const SizedBox(height: 20),
              CampoBusqueda<Moto>(
                etiqueta: 'Moto',
                valor: moto,
                opciones: motos,
                constructorEtiqueta: (m) => m.nombreDisplay,
                constructorDetalle: (m) => m.placa,
                placeholder: 'Opcional: en qué moto se montó…',
                alCambiar: _editable
                    ? (m) => setState(() => _motoId = m?.id)
                    : (_) {},
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Concepto',
                controlador: _concepto,
                placeholder: 'Opcional: cómo se llama este fiado…',
                habilitado: _editable,
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
                      alPresionar:
                          _guardando ? null : () => unawaited(_guardar()),
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
