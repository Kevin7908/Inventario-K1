import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Cantidad de una línea, con `–`, `+` **y el número editable a mano**.
///
/// Los botones sirven para ajustar de a uno; escribir directamente sirve para
/// saltar a 12 sin pulsar doce veces. Es la pieza que llevan el carrito del
/// punto de venta, las líneas de una cotización y las de una orden, así que
/// vive aquí y no en ninguno de esos módulos.
///
/// **Es `StatefulWidget` por excepción**, como [FilaTabla] con su hover: el
/// `TextEditingController` es estado efímero del propio campo. La cantidad de
/// verdad la manda el padre por [cantidad] y el widget no decide nada; si el
/// padre rechaza un cambio, el campo se vuelve a sincronizar solo.
///
/// El texto se escribe sin separadores de miles a propósito: es un campo que
/// se teclea, y un `12.000` que hay que reinterpretar al escribir estorba más
/// de lo que ayuda. Las cantidades del sistema son pequeñas.
///
/// Parámetros:
/// - [cantidad]: valor actual.
/// - [alCambiar]: se llama con el valor nuevo, ya recortado a [minimo] y
///   [maximo]. Si es `null`, el control se ve deshabilitado.
/// - [minimo]: por debajo no baja. Por defecto 1. Un padre que quiera que el
///   `–` sirva para borrar la línea pasa `0` y trata ese valor como "quitar":
///   es lo que hace el carrito del diseño, que no tiene papelera.
/// - [maximo]: tope opcional (el stock disponible, por ejemplo).
/// - [permitirDecimales]: habilita cantidades como `2,5` (litros, horas).
///   Por defecto solo enteros.
///
/// Ejemplo:
/// ```dart
/// ControlCantidad(
///   cantidad: item.cantidad,
///   alCambiar: (valor) => notifier.cambiarCantidad(indice, valor),
/// )
/// ```
class ControlCantidad extends StatefulWidget {
  const ControlCantidad({
    super.key,
    required this.cantidad,
    required this.alCambiar,
    this.minimo = 1,
    this.maximo,
    this.permitirDecimales = false,
  });

  final double cantidad;
  final ValueChanged<double>? alCambiar;
  final double minimo;
  final double? maximo;
  final bool permitirDecimales;

  /// Texto plano de una cantidad: `2` y no `2.0`, `2.5` con decimales.
  static String comoTexto(double valor) =>
      valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : '$valor';

  @override
  State<ControlCantidad> createState() => _ControlCantidadState();
}

class _ControlCantidadState extends State<ControlCantidad> {
  late final TextEditingController _controlador =
      TextEditingController(text: ControlCantidad.comoTexto(widget.cantidad));
  final _foco = FocusNode();

  /// Último valor que se le avisó al padre. Evita el aviso doble: al pulsar
  /// Enter el campo confirma, y acto seguido pierde el foco y volvería a
  /// confirmar lo mismo antes de que el padre alcance a reconstruir.
  late double _ultimoAvisado = widget.cantidad;

  @override
  void initState() {
    super.initState();
    // Al salir del campo se confirma lo escrito. Sin esto, teclear y hacer
    // clic fuera dejaría el número en pantalla sin haber avisado al padre.
    _foco.addListener(() {
      if (!_foco.hasFocus) _confirmar(_controlador.text);
    });
  }

  @override
  void didUpdateWidget(ControlCantidad anterior) {
    super.didUpdateWidget(anterior);
    _ultimoAvisado = widget.cantidad;
    // El padre es la fuente de verdad. Se compara contra el texto y no contra
    // la cantidad anterior porque el caso que importa es justo el que no
    // cambia nada: el padre rechazó lo que se escribió y hay que devolver el
    // campo a lo que él dice.
    if (_foco.hasFocus) return;
    final texto = ControlCantidad.comoTexto(widget.cantidad);
    if (_controlador.text != texto) _controlador.text = texto;
  }

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  double _acotar(double valor) {
    final tope = widget.maximo;
    if (valor < widget.minimo) return widget.minimo;
    if (tope != null && valor > tope) return tope;
    return valor;
  }

  /// Interpreta lo tecleado. Un campo vacío o ilegible vuelve al valor
  /// anterior en vez de mandar un cero al padre.
  void _confirmar(String texto) {
    final leido = double.tryParse(texto.replaceAll(',', '.'));
    if (leido == null) {
      _controlador.text = ControlCantidad.comoTexto(widget.cantidad);
      return;
    }
    final valor =
        _acotar(widget.permitirDecimales ? leido : leido.roundToDouble());
    _controlador.text = ControlCantidad.comoTexto(valor);
    _avisar(valor);
  }

  void _sumar(double delta) {
    final valor = _acotar(widget.cantidad + delta);
    if (valor == widget.cantidad) return;
    _controlador.text = ControlCantidad.comoTexto(valor);
    _avisar(valor);
  }

  void _avisar(double valor) {
    if (valor == _ultimoAvisado) return;
    _ultimoAvisado = valor;
    widget.alCambiar?.call(valor);
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.alCambiar != null;
    final tope = widget.maximo;
    final puedeBajar = activo && widget.cantidad > widget.minimo;
    final puedeSubir = activo && (tope == null || widget.cantidad < tope);

    // Las medidas son las del diseño: dos cuadros de 28 con radio 8, el de
    // restar con borde sobre blanco y el de sumar en verde macizo, y el número
    // suelto en medio.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Cuadro(
          icono: Icons.remove_rounded,
          tooltip: widget.minimo <= 0 && widget.cantidad <= 1
              ? 'Quitar de la lista'
              : 'Quitar una unidad',
          alPresionar: puedeBajar ? () => _sumar(-1) : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: TextField(
            controller: _controlador,
            focusNode: _foco,
            enabled: activo,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.permitirDecimales,
            ),
            // Sin decimales el filtro ya descarta el punto, así que el
            // `roundToDouble` de `_confirmar` es solo una red de seguridad.
            inputFormatters: [
              widget.permitirDecimales
                  ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                  : FilteringTextInputFormatter.digitsOnly,
            ],
            style: TipografiaApp.cuerpoMedium.copyWith(fontSize: 13),
            onSubmitted: _confirmar,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Cuadro(
          icono: Icons.add_rounded,
          tooltip: 'Agregar una unidad',
          verde: true,
          alPresionar: puedeSubir ? () => _sumar(1) : null,
        ),
      ],
    );
  }
}

/// Botón cuadrado de 28 del diseño. El de restar va con borde sobre blanco y
/// el de sumar en verde macizo.
class _Cuadro extends StatelessWidget {
  const _Cuadro({
    required this.icono,
    required this.tooltip,
    required this.alPresionar,
    this.verde = false,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? alPresionar;
  final bool verde;

  @override
  Widget build(BuildContext context) {
    final deshabilitado = alPresionar == null;
    final fondo = verde
        ? (deshabilitado ? ColoresApp.border : ColoresApp.goGreen)
        : ColoresApp.bgCard;
    final contenido = verde
        ? (deshabilitado ? ColoresApp.textDisabled : ColoresApp.textOnPrimary)
        : (deshabilitado ? ColoresApp.textDisabled : ColoresApp.textSecondary);

    final boton = Material(
      color: fondo,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        hoverColor:
            verde ? ColoresApp.castletonGreen : ColoresApp.bgCardHover,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: verde ? null : Border.all(color: ColoresApp.borderInput),
          ),
          child: Icon(icono, size: 15, color: contenido),
        ),
      ),
    );

    return deshabilitado ? boton : Tooltip(message: tooltip, child: boton);
  }
}
