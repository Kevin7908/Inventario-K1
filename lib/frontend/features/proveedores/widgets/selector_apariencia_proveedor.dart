import 'package:flutter/material.dart';

import '../../../share2/share2.dart';
import 'tarjeta_proveedor.dart';

/// Colores que puede tomar el marcador de un proveedor.
///
/// El primero, `#3B82F6`, es el azul con que el diseño pinta la tarjeta de
/// proveedor y el valor por defecto de la columna en la base.
const List<({String hex, String nombre})> coloresProveedor = [
  (hex: '#3B82F6', nombre: 'Azul'),
  (hex: '#01B763', nombre: 'Verde'),
  (hex: '#E74C3C', nombre: 'Rojo'),
  (hex: '#E0892A', nombre: 'Naranja'),
  (hex: '#8B5CF6', nombre: 'Morado'),
  (hex: '#14B8A6', nombre: 'Teal'),
  (hex: '#EC4899', nombre: 'Rosa'),
  (hex: '#64748B', nombre: 'Gris'),
];

/// Elige el color y el ícono con que se identifica un proveedor, mostrando el
/// resultado en vivo.
///
/// El mockup dibuja todos los proveedores iguales —camión azul—, pero el
/// modelo ya guarda ambos campos y la lista es más fácil de recorrer cuando
/// cada distribuidor se reconoce por su marcador. Los valores por defecto son
/// exactamente los del diseño.
class SelectorAparienciaProveedor extends StatelessWidget {
  const SelectorAparienciaProveedor({
    super.key,
    required this.colorHex,
    required this.icono,
    required this.alCambiarColor,
    required this.alCambiarIcono,
  });

  final String colorHex;
  final String icono;
  final ValueChanged<String> alCambiarColor;
  final ValueChanged<String> alCambiarIcono;

  @override
  Widget build(BuildContext context) {
    final color = colorDeHex(colorHex) ?? ColoresApp.statusInfo;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarcadorIdentidad(
          icono: iconoDeProveedor(icono),
          color: color,
          lado: 56,
          radio: 16,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Color', style: TipografiaApp.etiquetaCampo),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final opcion in coloresProveedor)
                    _Muestra(
                      color: colorDeHex(opcion.hex) ?? ColoresApp.statusInfo,
                      tooltip: opcion.nombre,
                      seleccionado: colorHex == opcion.hex,
                      alPresionar: () => alCambiarColor(opcion.hex),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Ícono', style: TipografiaApp.etiquetaCampo),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final opcion in iconosProveedor)
                    _Muestra(
                      color: color,
                      icono: opcion.icono,
                      tooltip: opcion.nombre,
                      seleccionado: icono == opcion.clave,
                      alPresionar: () => alCambiarIcono(opcion.clave),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Casilla seleccionable del selector: un color sólido o un ícono sobre él.
class _Muestra extends StatelessWidget {
  const _Muestra({
    required this.color,
    required this.tooltip,
    required this.seleccionado,
    required this.alPresionar,
    this.icono,
  });

  final Color color;
  final String tooltip;
  final bool seleccionado;
  final VoidCallback alPresionar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final esColor = icono == null;
    final fondo = esColor ? color : color.withValues(alpha: 0.12);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: alPresionar,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: seleccionado ? color : ColoresApp.borderInput,
                width: seleccionado ? 2 : 1,
              ),
            ),
            child: esColor
                ? (seleccionado
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: ColoresApp.textOnPrimary,
                      )
                    : null)
                : Icon(
                    icono,
                    size: 19,
                    color: seleccionado ? color : ColoresApp.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}
