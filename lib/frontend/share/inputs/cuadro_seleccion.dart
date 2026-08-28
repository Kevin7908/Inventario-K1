import 'package:flutter/material.dart';

import '../botones/boton_icono.dart';
import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'barra_busqueda.dart';

/// Envoltorio del valor devuelto por el cuadro.
///
/// Hace falta para distinguir "cerré sin elegir" (`null` del `showDialog`) de
/// "elegí explícitamente nada", que con un `T?` pelado serían lo mismo.
class Seleccion<T> {
  const Seleccion(this.valor);
  final T? valor;
}

/// Cuadro que abre `CampoBusqueda`: buscador arriba y lista filtrada debajo.
///
/// Está en su propio archivo por tamaño, no porque se use suelto: el barrel de
/// `inputs/` **no** lo exporta. Quien quiera este selector usa `CampoBusqueda`,
/// que es el que se integra con `Form`.
class CuadroSeleccion<T> extends StatefulWidget {
  const CuadroSeleccion({
    super.key,
    required this.titulo,
    required this.opciones,
    required this.constructorEtiqueta,
    required this.constructorDetalle,
    required this.placeholderBusqueda,
    required this.seleccionado,
    required this.alAgregar,
    required this.etiquetaAgregar,
  });

  final String titulo;
  final List<T> opciones;
  final String Function(T) constructorEtiqueta;
  final String? Function(T)? constructorDetalle;
  final String placeholderBusqueda;
  final T? seleccionado;
  final VoidCallback? alAgregar;
  final String etiquetaAgregar;

  @override
  State<CuadroSeleccion<T>> createState() => CuadroSeleccionState<T>();
}

class CuadroSeleccionState<T> extends State<CuadroSeleccion<T>> {
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<T> get _filtradas {
    final texto = _busqueda.trim().toLowerCase();
    if (texto.isEmpty) return widget.opciones;
    return widget.opciones
        .where((opcion) {
          final etiqueta = widget.constructorEtiqueta(opcion).toLowerCase();
          final detalle =
              widget.constructorDetalle?.call(opcion)?.toLowerCase() ?? '';
          return etiqueta.contains(texto) || detalle.contains(texto);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: ColoresApp.bgCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: ColoresApp.shadowMedium,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        // El fondo lo pinta el `Container`, pero las filas son `ListTile`:
        // sin un `Material` en medio, el resaltado de la fila elegida y el
        // ripple del tap se pintarían detrás de la decoración y no se verían.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.titulo, style: TipografiaApp.heading3),
                    ),
                    BotonIcono(
                      icono: Icons.close_rounded,
                      tooltip: 'Cerrar',
                      alPresionar: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                child: BarraBusqueda(
                  controlador: _busquedaCtrl,
                  placeholder: widget.placeholderBusqueda,
                  alCambiar: (texto) => setState(() => _busqueda = texto),
                ),
              ),
              Flexible(
                child: lista.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                        child: Text(
                          'Sin resultados para "${_busqueda.trim()}"',
                          style: TipografiaApp.caption,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        // Todas las filas miden igual: con `itemExtent` Flutter
                        // se salta el cálculo de layout de cada una.
                        itemExtent: 56,
                        itemCount: lista.length,
                        itemBuilder: (context, i) {
                          final opcion = lista[i];
                          final detalle =
                              widget.constructorDetalle?.call(opcion) ?? '';
                          final elegida = opcion == widget.seleccionado;

                          return ListTile(
                            selected: elegida,
                            selectedTileColor: ColoresApp.greenChipBg,
                            title: Text(
                              widget.constructorEtiqueta(opcion),
                              style: TipografiaApp.cuerpoMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: detalle.isEmpty
                                ? null
                                : Text(
                                    detalle,
                                    style: TipografiaApp.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () =>
                                Navigator.of(context).pop(Seleccion<T>(opcion)),
                          );
                        },
                      ),
              ),
              if (widget.alAgregar != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.alAgregar!();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(widget.etiquetaAgregar),
                    style: TextButton.styleFrom(
                      foregroundColor: ColoresApp.goGreen,
                      textStyle: TipografiaApp.cuerpoMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
