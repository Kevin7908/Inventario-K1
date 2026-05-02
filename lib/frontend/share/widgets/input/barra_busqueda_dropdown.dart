import 'package:flutter/material.dart';

import 'barra_busqueda_widget.dart';

class BarraBusquedaDropdown extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String> alBuscar;

  final String valorFiltro;
  final List<String> opcionesFiltro;
  final ValueChanged<String?> alCambiarFiltro;

  const BarraBusquedaDropdown({
    super.key,
    required this.placeholder,
    required this.alBuscar,
    required this.valorFiltro,
    required this.opcionesFiltro,
    required this.alCambiarFiltro,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BarraBusquedaWidget(
            placeholder: placeholder,
            alCambiar: alBuscar,
          ),
        ),

        const SizedBox(width: 12),

        FiltroDropdownWidget(
          valor: valorFiltro,
          opciones: opcionesFiltro,
          alCambiar: alCambiarFiltro,
        ),
      ],
    );
  }
}
