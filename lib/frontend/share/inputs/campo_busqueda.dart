import 'package:flutter/material.dart';

import '../botones/boton_icono.dart';
import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';
import 'cuadro_seleccion.dart';

/// Selector con buscador para listas largas: clientes, motos, técnicos.
///
/// Es la versión share del `AppSearch` legacy. Se usa donde
/// [SelectorWidget] no alcanza: un desplegable con cientos de opciones no se
/// puede recorrer, así que aquí el campo abre un cuadro con buscador y la lista
/// ya filtrada.
///
/// Envuelve un `FormField`, así que dentro de un `Form` participa de
/// `validate()` igual que un [CampoTexto]: si no hay selección y [validador] lo
/// exige, el borde se pinta en rojo y el mensaje aparece debajo.
///
/// El widget en sí no guarda estado —la selección la manda el padre por
/// [valor]—; el cuadro que se abre sí mantiene el texto tecleado mientras está
/// en pantalla, que es estado de un modal y muere con él.
///
/// Parámetros:
/// - [etiqueta]: texto mostrado encima del campo.
/// - [valor]: opción seleccionada, o `null` si no hay ninguna.
/// - [opciones]: lista completa entre la que elegir.
/// - [constructorEtiqueta]: convierte cada opción en su texto principal. Es
///   también el texto sobre el que busca el cuadro.
/// - [constructorDetalle]: segunda línea opcional de cada opción (el teléfono
///   de un cliente, la placa de una moto). También entra en la búsqueda.
/// - [alCambiar]: se llama con la opción elegida, o con `null` al limpiar.
/// - [placeholder]: texto del campo cuando no hay selección.
/// - [placeholderBusqueda]: texto del buscador dentro del cuadro.
/// - [validador]: valida la selección dentro de un `Form`.
/// - [alAgregar]: si se pasa, el cuadro muestra un botón para crear una opción
///   nueva sin salir de él (dar de alta un cliente desde la ficha de una moto).
/// - [etiquetaAgregar]: texto de ese botón.
///
/// Ejemplo:
/// ```dart
/// CampoBusqueda<Cliente>(
///   etiqueta: 'Dueño *',
///   valor: _cliente,
///   opciones: clientes,
///   constructorEtiqueta: (c) => c.nombreCompleto,
///   constructorDetalle: (c) => c.telefono,
///   alCambiar: (c) => setState(() => _cliente = c),
///   validador: (c) => c == null ? 'Elige un cliente.' : null,
/// )
/// ```
class CampoBusqueda<T> extends StatelessWidget {
  const CampoBusqueda({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.constructorEtiqueta,
    required this.alCambiar,
    this.constructorDetalle,
    this.placeholder = 'Seleccionar…',
    this.placeholderBusqueda = 'Buscar…',
    this.validador,
    this.alAgregar,
    this.etiquetaAgregar = 'Agregar',
  });

  final String etiqueta;
  final T? valor;
  final List<T> opciones;
  final String Function(T opcion) constructorEtiqueta;
  final String? Function(T opcion)? constructorDetalle;
  final ValueChanged<T?> alCambiar;
  final String placeholder;
  final String placeholderBusqueda;
  final String? Function(T?)? validador;
  final VoidCallback? alAgregar;
  final String etiquetaAgregar;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: valor,
      validator: validador,
      builder: (campo) {
        final error = campo.errorText;
        final seleccion = valor;

        Future<void> abrir() async {
          final elegido = await showDialog<Seleccion<T>>(
            context: context,
            builder: (_) => CuadroSeleccion<T>(
              titulo: etiqueta,
              opciones: opciones,
              constructorEtiqueta: constructorEtiqueta,
              constructorDetalle: constructorDetalle,
              placeholderBusqueda: placeholderBusqueda,
              seleccionado: seleccion,
              alAgregar: alAgregar,
              etiquetaAgregar: etiquetaAgregar,
            ),
          );
          if (elegido == null) return;
          campo.didChange(elegido.valor);
          alCambiar(elegido.valor);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(etiqueta, style: TipografiaApp.etiquetaCampo),
            const SizedBox(height: 7),
            // `borderRadius` en la decoración y en el InkWell, sin ClipRRect:
            // recortar una capa entera para unas esquinas es más caro.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: abrir,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: ColoresApp.bgInput,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: error == null
                          ? ColoresApp.borderInput
                          : ColoresApp.statusDanger,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: ColoresApp.textDisabled,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          seleccion == null
                              ? placeholder
                              : constructorEtiqueta(seleccion),
                          style: seleccion == null
                              ? TipografiaApp.deshabilitado(
                                  TipografiaApp.cuerpo,
                                )
                              : TipografiaApp.cuerpo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (seleccion != null)
                        BotonIcono(
                          icono: Icons.close_rounded,
                          tooltip: 'Quitar selección',
                          alPresionar: () {
                            campo.didChange(null);
                            alCambiar(null);
                          },
                        )
                      else
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: ColoresApp.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: TipografiaApp.caption.copyWith(
                  color: ColoresApp.statusDanger,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
