import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../share/share.dart';

/// Las seis casillas del código que llega por correo.
///
/// Cada dígito es una casilla: al escribir salta a la siguiente, con retroceso
/// vuelve a la anterior y pegar el código completo lo reparte entre las seis.
/// Cuando se llena la última, [alCompletar] dispara la verificación sin
/// obligar a buscar el botón.
///
/// Vive en el módulo y no en `share` porque hoy solo la usa la recuperación
/// de contraseña. Si aparece un segundo código —una confirmación de anulación,
/// por ejemplo—, es candidata a subir.
///
/// Parámetros:
/// - [alCambiar]: se llama con el código completo en cada tecla.
/// - [alCompletar]: se llama cuando las seis casillas están llenas.
/// - [largo]: cuántos dígitos. Seis por defecto.
class CampoCodigo extends StatefulWidget {
  const CampoCodigo({
    super.key,
    required this.alCambiar,
    this.alCompletar,
    this.largo = 6,
  });

  final ValueChanged<String> alCambiar;
  final ValueChanged<String>? alCompletar;
  final int largo;

  @override
  State<CampoCodigo> createState() => _CampoCodigoState();
}

class _CampoCodigoState extends State<CampoCodigo> {
  late final List<TextEditingController> _controladores;
  late final List<FocusNode> _focos;

  @override
  void initState() {
    super.initState();
    _controladores =
        List.generate(widget.largo, (_) => TextEditingController());
    _focos = List.generate(widget.largo, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    for (final f in _focos) {
      f.dispose();
    }
    super.dispose();
  }

  String get _codigo => _controladores.map((c) => c.text).join();

  void _alEscribir(int indice, String valor) {
    // Más de un carácter en una casilla pasa por dos vías: pegar el código
    // entero, o teclear un dígito en una casilla que ya tenía uno. Las dos se
    // resuelven igual —repartir desde aquí hacia la derecha—, y en el segundo
    // caso el dígito nuevo cae en la casilla siguiente, que es donde el
    // usuario lo quería.
    if (valor.length > 1) {
      _repartir(valor, indice);
      return;
    }

    if (valor.isNotEmpty && indice < widget.largo - 1) {
      _focos[indice + 1].requestFocus();
    }

    _avisar();
  }

  void _repartir(String texto, int desde) {
    final digitos = texto.replaceAll(RegExp(r'\D'), '');

    for (var i = 0; i < digitos.length && desde + i < widget.largo; i++) {
      _controladores[desde + i].text = digitos[i];
    }

    final ultima = (desde + digitos.length - 1).clamp(0, widget.largo - 1);
    _focos[ultima].requestFocus();
    _avisar();
  }

  void _avisar() {
    final codigo = _codigo;
    widget.alCambiar(codigo);
    if (codigo.length == widget.largo) widget.alCompletar?.call(codigo);
  }

  /// Retroceso en una casilla vacía vuelve a la anterior y la borra: es lo que
  /// espera quien se equivocó de dígito.
  KeyEventResult _alTeclear(int indice, KeyEvent evento) {
    if (evento is! KeyDownEvent ||
        evento.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_controladores[indice].text.isNotEmpty || indice == 0) {
      return KeyEventResult.ignored;
    }

    _controladores[indice - 1].clear();
    _focos[indice - 1].requestFocus();
    _avisar();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < widget.largo; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onKeyEvent: (_, evento) => _alTeclear(i, evento),
              child: _Casilla(
                controlador: _controladores[i],
                foco: _focos[i],
                autofocus: i == 0,
                alCambiar: (valor) => _alEscribir(i, valor),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Una casilla suelta. Aparte para que el `TextField` no se reconstruya con el
/// estado del grupo.
class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.controlador,
    required this.foco,
    required this.autofocus,
    required this.alCambiar,
  });

  final TextEditingController controlador;
  final FocusNode foco;
  final bool autofocus;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: controlador,
      focusNode: foco,
      autofocus: autofocus,
      onChanged: alCambiar,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TipografiaApp.monoespaciada(TipografiaApp.heading3),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: ColoresApp.bgInput,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: borde(ColoresApp.borderInput),
        enabledBorder: borde(ColoresApp.borderInput),
        focusedBorder: borde(ColoresApp.borderFocus),
      ),
    );
  }
}
