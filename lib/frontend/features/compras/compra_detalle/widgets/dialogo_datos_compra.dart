import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../../../proveedores/provider/proveedores_provider.dart';
import '../provider/compra_editor_provider.dart';

/// La cabecera de la remisión: de quién llegó, con qué papel y cuándo.
///
/// Lo mismo que `DialogoDatosDeuda` para una deuda: la ficha muestra el
/// resumen y esto deja corregirlo. **No toca las líneas**, que se corrigen en
/// el panel de la derecha.
///
/// Ejemplo:
/// ```dart
/// await DialogoDatosCompra.mostrar(context, compraId: 7);
/// ```
class DialogoDatosCompra extends ConsumerStatefulWidget {
  const DialogoDatosCompra({super.key, required this.compraId});

  final int compraId;

  static Future<void> mostrar(
    BuildContext context, {
    required int compraId,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoDatosCompra(compraId: compraId),
      );

  @override
  ConsumerState<DialogoDatosCompra> createState() => _DialogoDatosCompraState();
}

class _DialogoDatosCompraState extends ConsumerState<DialogoDatosCompra> {
  late final TextEditingController _factura;
  late final TextEditingController _notas;
  late int _proveedorId;
  late DateTime _fecha;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final estado = ref.read(compraEditorProvider(widget.compraId)).value;
    _factura = TextEditingController(text: estado?.numeroFactura ?? '');
    _notas = TextEditingController(text: estado?.notas ?? '');
    _proveedorId = estado?.proveedorId ?? 0;
    _fecha = estado?.fecha ?? DateTime.now();
  }

  @override
  void dispose() {
    _factura.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await ref
        .read(compraEditorProvider(widget.compraId).notifier)
        .actualizarDatos(
          proveedorId: _proveedorId,
          fecha: _fecha,
          numeroFactura: _factura.text,
          notas: _notas.text,
        );

    if (!mounted) return;
    switch (resultado) {
      case Exito():
        Navigator.of(context).pop();
      case Fallo(:final mensaje):
        setState(() {
          _guardando = false;
          _error = mensaje;
        });
    }
  }

  void _cerrar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final proveedores =
        ref.watch(catalogoProveedoresProvider).value ?? const <Proveedor>[];

    return AtajosFormulario(
      alGuardar: _guardando ? null : _guardar,
      alCancelar: _cerrar,
      child: Dialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Datos de la remisión',
                    style: TipografiaApp.heading3),
                const SizedBox(height: 20),
                CampoBusqueda<Proveedor>(
                  etiqueta: 'Proveedor',
                  valor: proveedores
                      .where((p) => p.id == _proveedorId)
                      .firstOrNull,
                  opciones: proveedores,
                  constructorEtiqueta: (p) => p.nombre,
                  constructorDetalle: (p) => p.telefono ?? p.nitCedula ?? '',
                  placeholder: '¿De quién llegó?',
                  placeholderBusqueda: 'Nombre del proveedor…',
                  alCambiar: (p) => setState(() {
                    if (p?.id != null) _proveedorId = p!.id!;
                  }),
                ),
                const SizedBox(height: 16),
                FilaCampos(
                  hijos: [
                    CampoTexto(
                      etiqueta: 'Factura del proveedor',
                      controlador: _factura,
                      placeholder: 'FV-2291',
                      monoespaciado: true,
                    ),
                    CampoFecha(
                      etiqueta: 'Cuándo llegó',
                      valor: _fecha,
                      formatear: formatearFecha,
                      primeraFecha: DateTime(2020),
                      ultimaFecha: DateTime.now(),
                      alCambiar: (f) => setState(() => _fecha = f),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  etiqueta: 'Nota (opcional)',
                  controlador: _notas,
                  placeholder: 'Quién la trajo, qué faltó…',
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
                      alPresionar: _guardando ? null : _cerrar,
                    ),
                    const SizedBox(width: 12),
                    BotonPrimario(
                      etiqueta: _guardando ? 'Guardando…' : 'Guardar',
                      alPresionar: _guardando ? null : _guardar,
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
