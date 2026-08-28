import 'package:flutter/material.dart';

import '../../../../share/share.dart';
import '../../../../../core/validaciones.dart';

/// Formulario del cargo suelto: lo que no está en ningún catálogo.
///
/// Para el repuesto que se compra en la esquina, el domicilio o el lavado que
/// nadie dio de alta. **No mueve inventario a propósito**: si el repuesto
/// estuviera en el catálogo, sería un repuesto.
///
/// No hay lista que mostrar, así que el panel izquierdo se convierte en dos
/// campos y un botón.
///
/// Parámetros:
/// - [alAgregar]: recibe la descripción y el precio ya validados.
/// - [habilitado]: en `false` el botón queda apagado —la orden está entregada
///   o anulada.
class CargoLibreForm extends StatefulWidget {
  const CargoLibreForm({
    super.key,
    required this.alAgregar,
    this.habilitado = true,
  });

  final void Function(String descripcion, int precio) alAgregar;
  final bool habilitado;

  @override
  State<CargoLibreForm> createState() => _CargoLibreFormState();
}

class _CargoLibreFormState extends State<CargoLibreForm> {
  final _descripcion = TextEditingController();
  final _precio = TextEditingController();

  /// Habilita el botón sin reconstruir el panel entero en cada tecla.
  late final ValueNotifier<bool> _completo = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _descripcion.addListener(_revisar);
    _precio.addListener(_revisar);
  }

  void _revisar() => _completo.value = _descripcion.text.trim().isNotEmpty &&
      (int.tryParse(normalizarDigitos(_precio.text)) ?? 0) > 0;

  @override
  void dispose() {
    _descripcion.dispose();
    _precio.dispose();
    _completo.dispose();
    super.dispose();
  }

  void _agregar() {
    if (!_completo.value) return;
    widget.alAgregar(_descripcion.text.trim(), int.parse(normalizarDigitos(_precio.text)));
    _descripcion.clear();
    _precio.clear();
  }

  @override
  Widget build(BuildContext context) {
    return PanelSeccion(
      titulo: 'Cargo suelto',
      icono: Icons.edit_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Para lo que no está en el catálogo: el repuesto que se compra en '
            'la esquina, el domicilio, un lavado. No descuenta inventario.',
            style: TipografiaApp.caption,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Descripción *',
            controlador: _descripcion,
            placeholder: 'Guardabarros trasero conseguido afuera',
          ),
          const SizedBox(height: 14),
          CampoTexto(
            etiqueta: 'Precio *',
            controlador: _precio,
            placeholder: '0',
            comoPrecio: true,
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder<bool>(
            valueListenable: _completo,
            builder: (context, completo, _) => BotonPrimario(
              etiqueta: 'Agregar a la orden',
              icono: Icons.add,
              alPresionar: completo && widget.habilitado ? _agregar : null,
            ),
          ),
        ],
      ),
    );
  }
}
