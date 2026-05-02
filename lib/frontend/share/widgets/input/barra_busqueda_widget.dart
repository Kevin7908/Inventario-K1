import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

// Widget reutilizable de búsqueda
class BarraBusquedaWidget extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String>? alCambiar;

  const BarraBusquedaWidget({
    super.key,
    required this.placeholder,
    this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: TextField(
        onChanged: alCambiar,
        style: const TextStyle(color: ColoresApp.textDark, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            color: ColoresApp.textLight,
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: ColoresApp.textLight,
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// Widget reutilizable de filtro por dropdown
class FiltroDropdownWidget extends StatelessWidget {
  final String valor;
  final List<String> opciones;
  final ValueChanged<String?>? alCambiar;

  const FiltroDropdownWidget({
    super.key,
    required this.valor,
    required this.opciones,
    this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          onChanged: alCambiar,
          style: const TextStyle(color: ColoresApp.textDark, fontSize: 13),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: ColoresApp.textMedium,
            size: 18,
          ),
          items: opciones
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
        ),
      ),
    );
  }
}
