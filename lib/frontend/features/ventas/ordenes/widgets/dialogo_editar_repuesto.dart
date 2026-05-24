import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/ordenes/modelo/orden_repuesto.dart';
import '../../../../share/formateadores/moneda_formateador.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../provider/ordenes_provider.dart';

class DialogoEditarRepuesto extends ConsumerStatefulWidget {
  const DialogoEditarRepuesto({
    super.key,
    required this.ordenId,
    required this.repuesto,
  });

  final int ordenId;
  final OrdenRepuesto repuesto;

  static Future<void> mostrar(
    BuildContext context, {
    required int ordenId,
    required OrdenRepuesto repuesto,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoEditarRepuesto(ordenId: ordenId, repuesto: repuesto),
    );
  }

  @override
  ConsumerState<DialogoEditarRepuesto> createState() =>
      _DialogoEditarRepuestoState();
}

class _DialogoEditarRepuestoState extends ConsumerState<DialogoEditarRepuesto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _precioCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final r = widget.repuesto;
    _cantidadCtrl = TextEditingController(
      text: r.cantidad % 1 == 0
          ? r.cantidad.toInt().toString()
          : r.cantidad.toStringAsFixed(2),
    );
    _precioCtrl = TextEditingController(
      text: r.precioUnitario.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final cantidad = double.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '')) ?? 0;

    final error = await ref.read(ordenesProvider.notifier).actualizarRepuesto(
          widget.repuesto.id,
          widget.ordenId,
          cantidad: cantidad,
          precioUnitario: precio,
        );

    if (!mounted) return;

    if (error != null) {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    } else {
      Navigator.of(context).pop();
      SnackBarMensaje.success(context, 'Repuesto actualizado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEncabezado(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del producto (solo lectura)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: ColoresApp.bgContent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ColoresApp.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 16, color: ColoresApp.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.repuesto.productoNombre,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ColoresApp.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      _label('Cantidad *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cantidadCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: _deco('1'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido.';
                          final n = double.tryParse(v.trim());
                          if (n == null || n <= 0) return 'Debe ser mayor a 0.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _label('Precio unitario'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ColoresApp.bgContent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ColoresApp.border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              fmtMoneda(widget.repuesto.precioUnitario),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: ColoresApp.textDark,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.lock_outline_rounded,
                                size: 14, color: ColoresApp.textLight),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            _buildBotones(),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 20, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColoresApp.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_outlined,
                color: ColoresApp.primary, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Editar Repuesto',
              style: TextStyle(
                color: ColoresApp.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: ColoresApp.textMedium),
            style: IconButton.styleFrom(
              backgroundColor: ColoresApp.bgContent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotones() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.textMedium,
                side: const BorderSide(color: ColoresApp.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColoresApp.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar cambios'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String texto) => Text(
        texto,
        style: const TextStyle(
          color: ColoresApp.textDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
        filled: true,
        fillColor: ColoresApp.bgContent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.statusDebt)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresApp.statusDebt, width: 1.5)),
      );
}
