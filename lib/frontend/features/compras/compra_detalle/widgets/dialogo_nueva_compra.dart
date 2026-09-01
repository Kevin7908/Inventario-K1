import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/compras/resultado/resultado_compra.dart';
import '../../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../../core/formato.dart';
import '../../../../../core/resultado.dart';
import '../../../../share/share.dart';
import '../../../proveedores/provider/proveedores_provider.dart';
import '../../provider/compras_providers.dart';

/// Abre la remisión: de quién llegó, con qué papel y cuándo.
///
/// **Solo la cabecera.** Las líneas se anotan después en la ficha, que guarda
/// sola: es el mismo arranque de una orden o de una deuda, y por el mismo
/// motivo —`proveedor_id` es `NOT NULL` y el número sale del consecutivo, así
/// que la compra tiene que existir antes de poder anotarle nada—.
///
/// Devuelve el id de la compra recién abierta, o `null` si se canceló:
/// cancelar aquí no crea nada, así que entrar y arrepentirse no quema un
/// consecutivo `COM-`.
///
/// Ejemplo:
/// ```dart
/// final id = await DialogoNuevaCompra.mostrar(context);
/// ```
class DialogoNuevaCompra extends ConsumerStatefulWidget {
  const DialogoNuevaCompra({super.key});

  static Future<int?> mostrar(BuildContext context) => showDialog<int>(
        context: context,
        builder: (_) => const DialogoNuevaCompra(),
      );

  @override
  ConsumerState<DialogoNuevaCompra> createState() => _DialogoNuevaCompraState();
}

class _DialogoNuevaCompraState extends ConsumerState<DialogoNuevaCompra> {
  final _factura = TextEditingController();
  final _notas = TextEditingController();

  Proveedor? _proveedor;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _factura.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    final proveedor = _proveedor;
    if (proveedor?.id == null) {
      setState(() => _error = 'Elige de qué proveedor llegó la mercancía.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await ref.read(repositorioComprasProvider).crear(
          proveedorId: proveedor!.id!,
          fecha: _fecha,
          numeroFactura: _factura.text,
          notas: _notas.text,
        );

    if (!mounted) return;

    switch (resultado) {
      case CompraRegistrada(:final compraId, :final numero):
        Navigator.of(context).pop(compraId);
        MensajeApp.exito(context, 'Compra $numero abierta');
      case CompraRechazada(:final motivo, :final mensaje):
        setState(() {
          _guardando = false;
          _error = motivo == MotivoFallo.remisionDuplicada
              ? '$mensaje Revisa el número de factura.'
              : mensaje;
        });
    }
  }

  void _cerrar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final proveedores =
        ref.watch(catalogoProveedoresProvider).value ?? const <Proveedor>[];

    return AtajosFormulario(
      alGuardar: _guardando ? null : _abrir,
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
                const Text('Registrar compra', style: TipografiaApp.heading3),
                const SizedBox(height: 4),
                Text(
                  'La remisión que llegó del proveedor. Después anotas lo que '
                  'trajo, con su costo, y se va guardando sola.',
                  style: TipografiaApp.caption
                      .copyWith(color: ColoresApp.textMuted),
                ),
                const SizedBox(height: 20),
                CampoBusqueda<Proveedor>(
                  etiqueta: 'Proveedor',
                  valor: _proveedor,
                  opciones: proveedores.where((p) => p.activo).toList(),
                  constructorEtiqueta: (p) => p.nombre,
                  constructorDetalle: (p) => p.telefono ?? p.nitCedula ?? '',
                  placeholder: '¿De quién llegó?',
                  placeholderBusqueda: 'Nombre del proveedor…',
                  alCambiar: (p) => setState(() {
                    _proveedor = p;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                FilaCampos(
                  hijos: [
                    CampoTexto(
                      etiqueta: 'Factura del proveedor (opcional)',
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
                      etiqueta: _guardando ? 'Abriendo…' : 'Abrir remisión',
                      icono: Icons.local_shipping_outlined,
                      alPresionar: _guardando ? null : _abrir,
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
