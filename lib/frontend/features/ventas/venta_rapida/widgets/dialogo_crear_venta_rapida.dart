import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/ventas/facturas/enum/enum_facturas.dart';
import '../../../../share/temas/colores_app.dart';
import '../../../../share/widgets/output/snack_bar_mensaje.dart';
import '../../facturas/provider/facturas_provider.dart';

class DialogoCrearVentaRapida extends ConsumerStatefulWidget {
  const DialogoCrearVentaRapida({super.key});

  static Future<void> mostrar(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DialogoCrearVentaRapida(),
    );
  }

  @override
  ConsumerState<DialogoCrearVentaRapida> createState() =>
      _DialogoCrearVentaRapidaState();
}

class _DialogoCrearVentaRapidaState
    extends ConsumerState<DialogoCrearVentaRapida> {
  MetodoPago _metodoPago = MetodoPago.efectivo;
  EstadoPago _estadoPago = EstadoPago.pagado;
  bool _guardando = false;
  late final TextEditingController _ivaCtrl;

  @override
  void initState() {
    super.initState();
    _ivaCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _ivaCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    setState(() => _guardando = true);
    final iva = double.tryParse(_ivaCtrl.text.trim()) ?? 0;

    final error = await ref.read(facturasProvider.notifier).crear(
          tipo:       TipoVenta.mostrador,
          metodoPago: _metodoPago,
          estadoPago: _estadoPago,
          iva:        iva,
        );

    if (!mounted) return;
    if (error != null) {
      SnackBarMensaje.error(context, error);
      setState(() => _guardando = false);
    } else {
      Navigator.of(context).pop();
      SnackBarMensaje.success(context, 'Venta creada. Agrega los productos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ColoresApp.accentTeal.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.point_of_sale_outlined,
                      color: ColoresApp.accentTeal, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Nueva Venta Rápida',
                    style: TextStyle(
                        color: ColoresApp.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
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
            const SizedBox(height: 20),

            // Método de pago
            _label('Método de pago'),
            const SizedBox(height: 8),
            _SelectorChip<MetodoPago>(
              opciones: MetodoPago.values,
              seleccionado: _metodoPago,
              labelOf: (m) => m.etiqueta,
              onTap: (m) => setState(() => _metodoPago = m),
            ),
            const SizedBox(height: 16),

            // Estado de pago
            _label('Estado de pago'),
            const SizedBox(height: 8),
            _SelectorChip<EstadoPago>(
              opciones: EstadoPago.values,
              seleccionado: _estadoPago,
              labelOf: (e) => e.etiqueta,
              onTap: (e) => setState(() => _estadoPago = e),
            ),
            const SizedBox(height: 16),

            // IVA
            _label('IVA (valor en \$)'),
            const SizedBox(height: 6),
            TextField(
              controller: _ivaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                hintText: '0',
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
                    borderSide:
                        const BorderSide(color: ColoresApp.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _guardando ? null : () => Navigator.of(context).pop(),
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
                    onPressed: _guardando ? null : _crear,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.accentTeal,
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
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Crear venta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String texto) => Text(
        texto,
        style: const TextStyle(
            color: ColoresApp.textDark, fontSize: 13, fontWeight: FontWeight.w600),
      );
}

class _SelectorChip<T> extends StatelessWidget {
  const _SelectorChip({
    required this.opciones,
    required this.seleccionado,
    required this.labelOf,
    required this.onTap,
  });
  final List<T> opciones;
  final T seleccionado;
  final String Function(T) labelOf;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: opciones.map((o) {
        final sel = o == seleccionado;
        return GestureDetector(
          onTap: () => onTap(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? ColoresApp.primary.withValues(alpha: 0.08)
                  : ColoresApp.bgContent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? ColoresApp.primary : ColoresApp.border,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(
              labelOf(o),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? ColoresApp.primary : ColoresApp.textMedium,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
