import 'package:flutter/material.dart';

import '../temas/colores_app.dart';
import '../temas/tipografia_app.dart';

/// Campo de fecha con etiqueta que abre el calendario del sistema.
///
/// Se elige en el calendario y no se teclea a propósito: escribir una fecha a
/// mano invita a formatos distintos ("12/9/26", "2026-09-12") y obliga a
/// validar lo que el selector ya garantiza.
///
/// [formatear] llega desde fuera porque share2 no puede depender de `intl`:
/// quien lo usa le pasa `formatearFecha` de `core/formato.dart`, que es el
/// único formateador de fechas del proyecto.
///
/// Igual que [CampoBusqueda], no guarda estado: recibe [valor] del padre y
/// avisa por [alCambiar].
///
/// Parámetros:
/// - [etiqueta]: texto mostrado encima del campo.
/// - [valor]: fecha seleccionada, o `null` si todavía no hay ninguna.
/// - [alCambiar]: se llama con la fecha elegida. Si es `null`, el campo queda
///   deshabilitado.
/// - [primeraFecha] / [ultimaFecha]: extremos que acepta el calendario. Por
///   defecto, de hoy a tres años.
/// - [formatear]: convierte la fecha en el texto visible. Pasarle siempre
///   `formatearFecha`, no una implementación nueva.
/// - [placeholder]: qué mostrar mientras [valor] es `null`.
///
/// Ejemplo:
/// ```dart
/// CampoFecha(
///   etiqueta: 'Vigente hasta',
///   valor: _vigencia,
///   formatear: formatearFecha,
///   alCambiar: (fecha) => setState(() => _vigencia = fecha),
/// )
/// ```
class CampoFecha extends StatelessWidget {
  const CampoFecha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    required this.formatear,
    this.primeraFecha,
    this.ultimaFecha,
    this.placeholder = '—',
  });

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime>? alCambiar;
  final String Function(DateTime fecha) formatear;
  final DateTime? primeraFecha;
  final DateTime? ultimaFecha;
  final String placeholder;

  Future<void> _elegir(BuildContext context) async {
    final cambiar = alCambiar;
    if (cambiar == null) return;

    final hoy = DateTime.now();
    final desde = primeraFecha ?? hoy;
    final hasta = ultimaFecha ?? hoy.add(const Duration(days: 365 * 3));
    // `initialDate` fuera del rango revienta el selector.
    var inicial = valor ?? hoy;
    if (inicial.isBefore(desde)) inicial = desde;
    if (inicial.isAfter(hasta)) inicial = hasta;

    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: desde,
      lastDate: hasta,
    );
    if (elegida != null) cambiar(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final deshabilitado = alCambiar == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: TipografiaApp.etiquetaCampo),
        const SizedBox(height: 7),
        InkWell(
          onTap: deshabilitado ? null : () => _elegir(context),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: ColoresApp.bgInput,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: ColoresApp.borderInput),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valor == null ? placeholder : formatear(valor!),
                    style: valor == null
                        ? TipografiaApp.deshabilitado(TipografiaApp.cuerpo)
                        : TipografiaApp.cuerpo,
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: deshabilitado
                      ? ColoresApp.textDisabled
                      : ColoresApp.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
