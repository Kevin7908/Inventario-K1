import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../temas/colores_app.dart';
import 'formateador_miles.dart';
import '../temas/tipografia_app.dart';

/// Campo de texto de propósito general con etiqueta arriba.
///
/// Usa `TextFormField`, así que funciona igual suelto o dentro de un `Form`:
/// si se le pasa [validador], participa de la validación del formulario.
///
/// Parámetros:
/// - [etiqueta]: texto mostrado encima del campo.
/// - [controlador]: controla el valor del campo.
/// - [placeholder]: texto de ejemplo cuando el campo está vacío.
/// - [alCambiar]: callback ejecutado en cada cambio de texto.
/// - [validador]: valida el valor dentro de un `Form`. Devuelve el mensaje de
///   error, o `null` si el valor es válido.
/// - [lineas]: alto del campo en líneas. Por defecto 1.
/// - [autofocus]: pone el foco en el campo al construirse.
/// - [monoespaciado]: usa fuente monoespaciada para el valor. Útil en códigos
///   donde alinear dígitos ayuda a leerlos (NIT, SKU, cédula).
/// - [soloEnteros]: rechaza todo lo que no sea un dígito mientras se escribe.
///   Para importes en pesos y cantidades, que en este sistema no llevan
///   decimales.
/// - [maximoCaracteres]: corta la escritura al llegar al límite. Es el que
///   hace que un teléfono no pueda tener once dígitos: el validador avisa
///   después, esto no deja ni teclearlo.
/// - [comoPrecio]: agrupa los miles mientras se escribe (`45000` se ve
///   `45.000`) y antepone el `$`. El valor que sale del controlador sigue
///   siendo el texto formateado: quien guarda lo pasa por
///   `normalizarDigitos`.
/// - [soloLectura]: se ve y se puede copiar, pero no se escribe. Para lo que
///   la app calcula sola, como el SKU de un producto.
/// - [nodoFoco]: para encadenar el orden de tabulación desde la vista.
/// - [alEnviar]: se dispara con Enter. En un campo de una sola línea Enter ya
///   envía el formulario (`CLAUDE.md` §8); `Ctrl+Enter` lo resuelve
///   `AtajosFormulario` para los de varias.
/// - [oculto]: pinta el contenido con puntos, para contraseñas.
/// - [alAlternarOculto]: si se pasa, aparece el ojo que muestra y esconde el
///   texto. El campo **no guarda** ese estado —share es sin estado—: lo lleva
///   quien lo usa y vuelve por [oculto].
///
/// Ejemplo:
/// ```dart
/// CampoTexto(
///   etiqueta: 'Nombre del taller',
///   controlador: _nombreController,
/// )
///
/// CampoTexto(
///   etiqueta: 'Nombre *',
///   controlador: _nombreCtrl,
///   autofocus: true,
///   validador: (v) =>
///       (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
/// )
///
/// CampoTexto(
///   etiqueta: 'Precio *',
///   controlador: _precioCtrl,
///   soloEnteros: true,
/// )
/// ```
class CampoTexto extends StatelessWidget {
  static final FormateadorMiles _miles = FormateadorMiles();

  /// Los formateadores que aplican, según lo que se haya pedido. El orden
  /// importa: primero se filtra lo que no es dígito, después se recorta al
  /// máximo y al final se agrupan los miles.
  List<TextInputFormatter>? get _formateadores {
    final lista = <TextInputFormatter>[
      if (soloEnteros || comoPrecio) FilteringTextInputFormatter.digitsOnly,
      if (maximoCaracteres != null)
        LengthLimitingTextInputFormatter(maximoCaracteres),
      if (comoPrecio) _miles,
    ];
    return lista.isEmpty ? null : lista;
  }

  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.placeholder,
    this.alCambiar,
    this.validador,
    this.lineas = 1,
    this.autofocus = false,
    this.monoespaciado = false,
    this.soloEnteros = false,
    this.maximoCaracteres,
    this.comoPrecio = false,
    this.soloLectura = false,
    this.habilitado = true,
    this.nodoFoco,
    this.alEnviar,
    this.oculto = false,
    this.alAlternarOculto,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final String? placeholder;
  final ValueChanged<String>? alCambiar;
  final String? Function(String?)? validador;
  final int lineas;
  final bool autofocus;
  final bool monoespaciado;
  final bool soloEnteros;
  final int? maximoCaracteres;
  final bool comoPrecio;
  final bool soloLectura;

  final FocusNode? nodoFoco;
  final ValueChanged<String>? alEnviar;
  final bool oculto;
  final VoidCallback? alAlternarOculto;

  /// En `false` el campo se ve pero no se escribe. Se usa cuando el documento
  /// que lo contiene está cerrado: quitarlo de la pantalla escondería el dato,
  /// y lo que hace falta es poder leerlo sin poder cambiarlo.
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: TipografiaApp.etiquetaCampo),
        const SizedBox(height: 7),
        TextFormField(
          controller: controlador,
          focusNode: nodoFoco,
          enabled: habilitado,
          readOnly: soloLectura,
          onChanged: alCambiar,
          onFieldSubmitted: alEnviar,
          validator: validador,
          obscureText: oculto,
          maxLines: oculto ? 1 : lineas,
          autofocus: autofocus,
          keyboardType:
              (soloEnteros || comoPrecio) ? TextInputType.number : null,
          inputFormatters: _formateadores,
          style: monoespaciado
              ? TipografiaApp.monoespaciada(TipografiaApp.cuerpo)
              : TipografiaApp.cuerpo,
          decoration: InputDecoration(
            prefixText: comoPrecio ? r'$ ' : null,
            prefixStyle: TipografiaApp.cuerpo.copyWith(
              color: ColoresApp.textMuted,
            ),
            hintText: placeholder,
            hintStyle: TipografiaApp.deshabilitado(TipografiaApp.cuerpo),
            filled: true,
            fillColor: soloLectura ? ColoresApp.bgCardHover : ColoresApp.bgInput,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            suffixIcon: alAlternarOculto == null
                ? null
                : IconButton(
                    onPressed: alAlternarOculto,
                    icon: Icon(
                      oculto
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: ColoresApp.textMuted,
                    ),
                    tooltip: oculto ? 'Mostrar' : 'Ocultar',
                    splashRadius: 18,
                  ),
            border: borde(ColoresApp.borderInput),
            enabledBorder: borde(ColoresApp.borderInput),
            focusedBorder: borde(ColoresApp.borderFocus),
            errorBorder: borde(ColoresApp.statusDanger),
            focusedErrorBorder: borde(ColoresApp.statusDanger),
            errorStyle: TipografiaApp.caption.copyWith(
              color: ColoresApp.statusDanger,
            ),
          ),
        ),
      ],
    );
  }
}
