import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../proveedores/provider/proveedores_provider.dart';
import '../provider/productos_provider.dart';

/// Agrega un proveedor a la lista de quienes le venden un repuesto al taller.
///
/// Sin esto, la lista solo crecía sola: un proveedor entraba al registrar su
/// remisión, y el único que se podía elegir a mano era el principal, desde el
/// formulario del producto. Pero saber a quién más pedirle una pieza es un
/// dato que se anota **antes** de comprarle, no después.
///
/// La referencia es el código con el que ese proveedor llama a la pieza: no es
/// el SKU del taller, es lo que hay que decirle por teléfono para que mande la
/// correcta.
///
/// Parámetros:
/// - [productoId]: a qué repuesto se le agrega.
/// - [yaVinculados]: los ids que ya están, para no ofrecerlos otra vez. La
///   `UNIQUE` de la tabla lo rechazaría igual; esto evita el viaje.
///
/// Ejemplo:
/// ```dart
/// await DialogoVincularProveedor.mostrar(
///   context,
///   productoId: producto.id!,
///   yaVinculados: {4, 9},
/// );
/// ```
class DialogoVincularProveedor extends ConsumerStatefulWidget {
  const DialogoVincularProveedor({
    super.key,
    required this.productoId,
    required this.yaVinculados,
  });

  final int productoId;
  final Set<int> yaVinculados;

  static Future<bool?> mostrar(
    BuildContext context, {
    required int productoId,
    required Set<int> yaVinculados,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DialogoVincularProveedor(
        productoId: productoId,
        yaVinculados: yaVinculados,
      ),
    );
  }

  @override
  ConsumerState<DialogoVincularProveedor> createState() =>
      _DialogoVincularProveedorState();
}

class _DialogoVincularProveedorState
    extends ConsumerState<DialogoVincularProveedor> {
  final _referencia = TextEditingController();

  Proveedor? _elegido;
  bool _principal = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _referencia.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final proveedor = _elegido;
    if (proveedor?.id == null) {
      setState(() => _error = 'Elige a quién se le compra.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado =
        await ref.read(repositorioProductosProvider).vincularProveedor(
              productoId: widget.productoId,
              proveedorId: proveedor!.id!,
              referenciaProveedor: _referencia.text.trim().isEmpty
                  ? null
                  : _referencia.text.trim(),
              esPrincipal: _principal,
            );

    if (!mounted) return;
    switch (resultado) {
      case Exito():
        Navigator.of(context).pop(true);
      case Fallo(:final mensaje):
        setState(() {
          _guardando = false;
          _error = mensaje;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Los que ya están no se ofrecen, y los dados de baja tampoco: no se le
    // compra a quien ya no vende.
    final disponibles = (ref.watch(catalogoProveedoresProvider).value ??
            const <Proveedor>[])
        .where((p) => p.activo && !widget.yaVinculados.contains(p.id))
        .toList();

    return AtajosFormulario(
      alGuardar: _guardando ? null : _guardar,
      alCancelar: () => Navigator.of(context).pop(),
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
              const Text('Agregar un proveedor',
                  style: TipografiaApp.heading3),
              const SizedBox(height: 18),
              if (disponibles.isEmpty)
                const AvisoEnLinea(
                  tono: TonoAviso.informacion,
                  mensaje: 'Ya están todos los proveedores activos del '
                      'catálogo. Da de alta uno nuevo en Proveedores.',
                )
              else ...[
                SelectorWidget<Proveedor?>(
                  etiqueta: 'Proveedor',
                  valor: _elegido,
                  opciones: <Proveedor?>[null, ...disponibles],
                  constructorEtiqueta: (p) => p?.nombre ?? 'Elige uno',
                  alCambiar: (p) => setState(() => _elegido = p),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  etiqueta: 'Su referencia (opcional)',
                  placeholder: 'El código con el que él la llama',
                  controlador: _referencia,
                ),
                const SizedBox(height: 16),
                InterruptorCampo(
                  etiqueta: 'Es el principal',
                  detalle: _principal
                      ? 'Se propone al pedir y sale en la rejilla'
                      : 'Uno más de la lista',
                  valor: _principal,
                  alCambiar: (v) => setState(() => _principal = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                AvisoEnLinea(tono: TonoAviso.error, mensaje: _error!),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TipografiaApp.cuerpoMedium.copyWith(
                        color: ColoresApp.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BotonPrimario(
                    etiqueta: _guardando ? 'Guardando…' : 'Agregar',
                    icono: Icons.add,
                    alPresionar:
                        _guardando || disponibles.isEmpty ? null : _guardar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
