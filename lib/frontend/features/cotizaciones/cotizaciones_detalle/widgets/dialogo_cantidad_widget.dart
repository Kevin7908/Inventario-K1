import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../frontend/share/temas/colores_app.dart';

/// Diálogo para seleccionar la cantidad de un producto antes de añadirlo al
/// carrito. Valida que la cantidad esté entre 1 y [disponible].
///
/// Retorna la cantidad elegida o `null` si el usuario canceló.
class DialogoCantidad extends StatefulWidget {
  const DialogoCantidad({
    super.key,
    required this.nombreProducto,
    required this.disponible,
    this.cantidadInicial = 1,
    this.etiquetaConfirmar = 'Agregar',
  });

  final String nombreProducto;
  final int disponible;
  final int cantidadInicial;
  final String etiquetaConfirmar;

  static Future<int?> mostrar(
    BuildContext context, {
    required String nombreProducto,
    required int disponible,
    int cantidadInicial = 1,
    String etiquetaConfirmar = 'Agregar',
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DialogoCantidad(
        nombreProducto:    nombreProducto,
        disponible:        disponible,
        cantidadInicial:   cantidadInicial,
        etiquetaConfirmar: etiquetaConfirmar,
      ),
    );
  }

  @override
  State<DialogoCantidad> createState() => _DialogoCantidadState();
}

class _DialogoCantidadState extends State<DialogoCantidad> {
  late int _cantidad;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _cantidad = widget.cantidadInicial.clamp(1, widget.disponible);
    _ctrl = TextEditingController(text: _cantidad.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(int v) {
    final clamped = v.clamp(1, widget.disponible);
    if (clamped == _cantidad) return;
    setState(() {
      _cantidad = clamped;
      _ctrl
        ..text = clamped.toString()
        ..selection = TextSelection.collapsed(offset: clamped.toString().length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ─────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ColoresApp.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: ColoresApp.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.nombreProducto,
                      style: const TextStyle(
                        color: ColoresApp.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Disponible: ${widget.disponible} '
                '${widget.disponible == 1 ? 'unidad' : 'unidades'}',
                style: const TextStyle(
                  color: ColoresApp.textMedium,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),

              // ── Stepper ────────────────────────────────────────
              const Text(
                'Cantidad',
                style: TextStyle(
                  color: ColoresApp.textMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Stepper(
                    icono: Icons.remove_rounded,
                    activo: _cantidad > 1,
                    onTap: () => _set(_cantidad - 1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: ColoresApp.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n != _cantidad) _set(n);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: ColoresApp.bgContent,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: ColoresApp.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: ColoresApp.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Stepper(
                    icono: Icons.add_rounded,
                    activo: _cantidad < widget.disponible,
                    onTap: () => _set(_cantidad + 1),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Botones ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresApp.textMedium,
                        side: const BorderSide(color: ColoresApp.border),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _cantidad),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresApp.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(widget.etiquetaConfirmar),
                    ),
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

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: activo ? ColoresApp.primaryLight : ColoresApp.bgContent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo
                ? ColoresApp.primary.withValues(alpha: 0.35)
                : ColoresApp.border,
          ),
        ),
        child: Icon(
          icono,
          size: 18,
          color: activo ? ColoresApp.primary : ColoresApp.textLight,
        ),
      ),
    );
  }
}
