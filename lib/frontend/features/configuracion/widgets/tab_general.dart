import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/configuracion/modelo/clave_configuracion.dart';
import '../../../../core/iva_app.dart';
import '../../../share/share.dart';
import '../../documentos/servicio/formato_impreso.dart';
import '../provider/configuracion_provider.dart';

/// Los datos del negocio: nombre, NIT, contacto, ubicación, IVA y papel.
///
/// **Es lo que sale impreso en la cabecera de cada factura**, así que no es
/// decoración: mientras estos campos estuvieron quemados en el código, todo
/// documento habría salido a nombre de un taller inventado.
///
/// Los campos son los de [ClaveConfiguracion], no una lista propia: agregar un
/// dato del negocio es agregar una clave allá, y aquí aparece sola.
class TabGeneral extends ConsumerStatefulWidget {
  const TabGeneral({super.key});

  @override
  ConsumerState<TabGeneral> createState() => _TabGeneralState();
}

class _TabGeneralState extends ConsumerState<TabGeneral> {
  /// Un controlador por clave de texto. En un mapa y no en seis campos porque
  /// así agregar una clave no obliga a tocar `initState`, `dispose` y el
  /// guardado por separado.
  final _controladores = <ClaveConfiguracion, TextEditingController>{
    for (final clave in _textos) clave: TextEditingController(),
  };

  /// Las que se escriben tal cual, sin interpretar.
  ///
  /// El IVA y el formato de impresión quedan fuera **porque no son texto
  /// libre**: uno es un porcentaje que hay que validar y aplicar en memoria al
  /// guardar, y el otro es un enum que se elige de una lista. Cada uno tiene su
  /// campo más abajo.
  static const _textos = [
    ClaveConfiguracion.nombreNegocio,
    ClaveConfiguracion.nit,
    ClaveConfiguracion.telefono,
    ClaveConfiguracion.direccion,
    ClaveConfiguracion.ciudad,
  ];

  final _iva = TextEditingController();
  FormatoImpreso _formato = FormatoImpreso.carta;

  bool _cargado = false;
  bool _guardando = false;

  @override
  void dispose() {
    for (final controlador in _controladores.values) {
      controlador.dispose();
    }
    _iva.dispose();
    super.dispose();
  }

  /// Vuelca lo guardado en los campos, **una sola vez**. Si se hiciera en cada
  /// emisión del stream, guardar pisaría lo que el usuario está tecleando.
  void _volcar(Map<ClaveConfiguracion, String> valores) {
    if (_cargado) return;
    _cargado = true;
    for (final clave in _textos) {
      _controladores[clave]!.text = valores[clave] ?? clave.porDefecto;
    }
    _iva.text = valores[ClaveConfiguracion.ivaPorcentaje] ??
        ClaveConfiguracion.ivaPorcentaje.porDefecto;
    _formato = FormatoImpreso.desdeCodigo(
      valores[ClaveConfiguracion.formatoImpresion] ??
          ClaveConfiguracion.formatoImpresion.porDefecto,
    );
  }

  /// Lo que se teclea en el campo de IVA, ya interpretado y acotado.
  ///
  /// Una coma decimal se acepta —el teclado colombiano la pone antes que el
  /// punto— y lo que no sea un número se lee como 0, que es no cobrar IVA. El
  /// recorte a `0..100` lo hace [configurarIva]; aquí se repite para poder
  /// guardar el mismo número que se aplica.
  int get _ivaTecleado {
    final texto = _iva.text.trim().replaceAll(',', '.');
    return (double.tryParse(texto) ?? 0).clamp(0, 100).round();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final repositorio = ref.read(repositorioConfiguracionProvider);
    try {
      for (final clave in _textos) {
        await repositorio.guardar(clave, _controladores[clave]!.text.trim());
      }
      final porcentaje = _ivaTecleado;
      await repositorio.guardar(
        ClaveConfiguracion.ivaPorcentaje,
        '$porcentaje',
      );
      await repositorio.guardar(
        ClaveConfiguracion.formatoImpresion,
        _formato.codigo,
      );

      // La tasa se aplica **en memoria y en el acto**: `main()` la carga al
      // arrancar, pero quien la acaba de cambiar no debería tener que
      // reiniciar para que el POS calcule con ella.
      configurarIva(porcentaje);

      if (!mounted) return;
      // Se repite el número guardado porque no siempre es el tecleado: un
      // «250» se recorta a 100 y el usuario tiene que enterarse aquí.
      _iva.text = '$porcentaje';
      MensajeApp.exito(context, 'Datos del negocio guardados.');
    } catch (e) {
      if (!mounted) return;
      MensajeApp.error(context, 'No se pudieron guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncValores = ref.watch(configuracionProvider);

    return asyncValores.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      ),
      error: (e, _) => EstadoVacio(
        icono: Icons.error_outline,
        titulo: 'No se pudo leer la configuración',
        pista: '$e',
      ),
      data: (valores) {
        _volcar(valores);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AtajosFormulario(
              alGuardar: _guardando ? null : _guardar,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelSeccion(
                    titulo: 'Datos del negocio',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AvisoEnLinea(
                          tono: TonoAviso.informacion,
                          mensaje:
                              'Esto es lo que sale impreso en la cabecera de '
                              'las facturas, reservas y cotizaciones.',
                        ),
                        const SizedBox(height: 16),
                        FilaCampos(
                          hijos: [
                            CampoTexto(
                              etiqueta: 'Nombre del taller',
                              controlador: _controladores[
                                  ClaveConfiguracion.nombreNegocio]!,
                            ),
                            CampoTexto(
                              etiqueta: 'NIT',
                              controlador:
                                  _controladores[ClaveConfiguracion.nit]!,
                              monoespaciado: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilaCampos(
                          hijos: [
                            CampoTexto(
                              etiqueta: 'Teléfono',
                              controlador:
                                  _controladores[ClaveConfiguracion.telefono]!,
                            ),
                            CampoTexto(
                              etiqueta: 'Dirección',
                              controlador:
                                  _controladores[ClaveConfiguracion.direccion]!,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CampoTexto(
                          etiqueta: 'Ciudad',
                          controlador:
                              _controladores[ClaveConfiguracion.ciudad]!,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  PanelSeccion(
                    titulo: 'Impuestos e impresión',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CampoIva(controlador: _iva),
                        const SizedBox(height: 18),
                        _SelectorFormato(
                          formato: _formato,
                          alCambiar: (f) => setState(() => _formato = f),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Sin parámetro de carga: `BotonPrimario` no lo tiene y
                  // el idioma del repo es cambiar la etiqueta y anular el
                  // callback, como hace «Cobrando…» en el punto de venta.
                  BotonPrimario(
                    etiqueta: _guardando ? 'Guardando…' : 'Guardar cambios',
                    icono: Icons.check,
                    alPresionar: _guardando ? null : _guardar,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El porcentaje de IVA del taller, con la advertencia de qué alcanza a
/// cambiar.
///
/// La aclaración no es un adorno: **cambiar la tasa no reescribe lo ya
/// emitido**. Cada documento guarda el IVA con el que se cerró, y así tiene
/// que ser —una factura de hace un año se cobró con la tasa de entonces—. Sin
/// esa línea, la primera reacción de cualquiera al subir el IVA sería ir a
/// mirar por qué las facturas viejas no cambiaron.
class _CampoIva extends StatelessWidget {
  const _CampoIva({required this.controlador});

  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: CampoTexto(
            etiqueta: 'IVA (%)',
            controlador: controlador,
            placeholder: '0',
            soloEnteros: true,
            maximoCaracteres: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hayIva
              ? 'Los precios del catálogo ya lo incluyen: el renglón del '
                  'documento lo discrimina, no lo suma. En 0 no se imprime.'
              : 'Hoy el taller no factura IVA, así que el renglón no se '
                  'imprime en ningún documento. Los precios del catálogo son '
                  'el total.',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        const SizedBox(height: 6),
        Text(
          'Cambiarlo afecta a lo que se emita de aquí en adelante. Las '
          'facturas, cotizaciones y órdenes ya cerradas conservan el IVA con '
          'el que se hicieron.',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
      ],
    );
  }
}

/// En qué papel salen los impresos del taller.
class _SelectorFormato extends StatelessWidget {
  const _SelectorFormato({required this.formato, required this.alCambiar});

  final FormatoImpreso formato;
  final ValueChanged<FormatoImpreso> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GrupoRadio<FormatoImpreso>(
          etiqueta: 'Formato de impresión',
          valor: formato,
          opciones: FormatoImpreso.values,
          constructorEtiqueta: (f) => f.etiqueta,
          alCambiar: alCambiar,
        ),
        const SizedBox(height: 8),
        Text(
          'El papel con el que se abre cada impresión. La vista previa deja '
          'cambiarlo para un documento suelto sin tocar esta opción: la orden '
          'que se entrega con la moto puede ir en carta aunque la caja imprima '
          'tirilla.',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
      ],
    );
  }
}
