import 'package:flutter/material.dart';
import 'package:inventario_k1/core/debounce.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class BarraBusquedaWidget extends StatefulWidget {
  const BarraBusquedaWidget({
    super.key,
    required this.placeholder,
    this.alCambiar,
    this.debounceMs = 0,
  });

  final String placeholder;
  final ValueChanged<String>? alCambiar;

  /// Milisegundos de debounce. 0 = sin debounce (comportamiento original).
  final int debounceMs;

  @override
  State<BarraBusquedaWidget> createState() => _BarraBusquedaWidgetState();
}

class _BarraBusquedaWidgetState extends State<BarraBusquedaWidget> {
  Debouncer? _debouncer;

  @override
  void initState() {
    super.initState();
    if (widget.debounceMs > 0) {
      _debouncer =
          Debouncer(delay: Duration(milliseconds: widget.debounceMs));
    }
  }

  @override
  void dispose() {
    _debouncer?.dispose();
    super.dispose();
  }

  void _onChanged(String valor) {
    if (_debouncer != null) {
      _debouncer!(() => widget.alCambiar?.call(valor));
    } else {
      widget.alCambiar?.call(valor);
    }
  }

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
        onChanged: _onChanged,
        style: const TextStyle(color: ColoresApp.textDark, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: widget.placeholder,
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

class FiltroDropdownWidget extends StatelessWidget {
  const FiltroDropdownWidget({
    super.key,
    required this.valor,
    required this.opciones,
    this.alCambiar,
  });

  final String valor;
  final List<String> opciones;
  final ValueChanged<String?>? alCambiar;

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
