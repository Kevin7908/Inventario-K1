import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Grupo de opciones excluyentes, todas a la vista.
///
/// Alternativa a [SelectorWidget] cuando las opciones son pocas (dos a cuatro)
/// y conviene que se vean sin abrir nada: un desplegable esconde que existen,
/// y en una pantalla donde se cambia de opción a cada rato obliga a dos clics
/// en vez de uno.
///
/// Con más opciones que esas, el dropdown sigue siendo lo correcto: una fila
/// de seis pastillas no cabe y deja de leerse como un grupo.
///
/// Parámetros:
/// - [etiqueta]: texto encima del grupo. En `null` no se dibuja, para cuando
///   la fila ya viene titulada desde afuera.
/// - [valor]: opción activa.
/// - [opciones]: opciones disponibles, en el orden en que se pintan.
/// - [constructorEtiqueta]: convierte cada opción en su texto.
/// - [constructorIcono]: ícono opcional de cada opción, a la izquierda del
///   texto. En `null` no se dibuja ninguno.
/// - [alCambiar]: se llama con la opción elegida. Pulsar la que ya está activa
///   no lo llama.
/// - [habilitado]: en `false` el grupo se ve apagado y no responde.
///
/// Ejemplo:
/// ```dart
/// GrupoRadio<TipoItemCotizacion>(
///   etiqueta: 'Qué agregar',
///   valor: tipo,
///   opciones: TipoItemCotizacion.values,
///   constructorEtiqueta: (t) => t.etiqueta,
///   alCambiar: _cambiarTipo,
/// )
/// ```
class GrupoRadio<T> extends StatelessWidget {
  const GrupoRadio({
    super.key,
    required this.valor,
    required this.opciones,
    required this.constructorEtiqueta,
    required this.alCambiar,
    this.etiqueta,
    this.constructorIcono,
    this.habilitado = true,
  });

  final T valor;
  final List<T> opciones;
  final String Function(T opcion) constructorEtiqueta;
  final IconData? Function(T opcion)? constructorIcono;
  final ValueChanged<T> alCambiar;
  final String? etiqueta;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final titulo = etiqueta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (titulo != null) ...[
          Text(titulo, style: TipografiaApp.etiquetaCampo),
          const SizedBox(height: 7),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opcion in opciones)
              _Opcion(
                etiqueta: constructorEtiqueta(opcion),
                icono: constructorIcono?.call(opcion),
                activa: opcion == valor,
                habilitado: habilitado,
                alPresionar: () {
                  if (opcion != valor) alCambiar(opcion);
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Una pastilla del grupo: círculo de radio, ícono opcional y texto.
///
/// El círculo se dibuja a mano en vez de usar `Radio` de Material porque el
/// widget de Material trae su propio tema de color y su área táctil de 40 px,
/// que rompen la altura de la fila y no respetan [ColoresApp].
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.etiqueta,
    required this.activa,
    required this.habilitado,
    required this.alPresionar,
    this.icono,
  });

  final String etiqueta;
  final bool activa;
  final bool habilitado;
  final VoidCallback alPresionar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final acento = habilitado
        ? (activa ? ColoresApp.goGreen : ColoresApp.textSecondary)
        : ColoresApp.textDisabled;

    return Material(
      color: activa && habilitado ? ColoresApp.greenChipBg : ColoresApp.bgInput,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: habilitado ? alPresionar : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: activa && habilitado
                  ? ColoresApp.goGreen
                  : ColoresApp.borderInput,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Circulo(activa: activa, color: acento),
              if (icono != null) ...[
                const SizedBox(width: 8),
                Icon(icono, size: 16, color: acento),
              ],
              const SizedBox(width: 8),
              Text(
                etiqueta,
                style: TipografiaApp.cuerpo.copyWith(
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
                  color: acento,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El círculo del radio: anillo, y un punto lleno cuando está activo.
class _Circulo extends StatelessWidget {
  const _Circulo({required this.activa, required this.color});

  final bool activa;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 15,
      height: 15,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: activa ? color : ColoresApp.borderInput,
            width: activa ? 2 : 1.5,
          ),
        ),
        child: activa
            ? Center(
                child: SizedBox(
                  width: 6,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
