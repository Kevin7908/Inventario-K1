import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/configuracion/modelo/clave_configuracion.dart';
import '../../../../core/iva_app.dart';
import '../../../share/share.dart';
import '../provider/configuracion_provider.dart';

/// Los datos del negocio: nombre, NIT, contacto y ubicación.
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
  /// Un controlador por clave editable. En un mapa y no en seis campos porque
  /// así agregar una clave no obliga a tocar `initState`, `dispose` y el
  /// guardado por separado.
  final _controladores = <ClaveConfiguracion, TextEditingController>{
    for (final clave in _editables) clave: TextEditingController(),
  };

  /// Las que el usuario puede cambiar hoy. `moneda` e `ivaPorcentaje` quedan
  /// fuera a propósito: se guardan en la tabla pero **nadie las lee todavía**
  /// —`core/formato.dart` fija el peso colombiano y `kIva` es una constante de
  /// compilación—, y un campo que se deja editar sin que cambie nada es peor
  /// que no ofrecerlo.
  static const _editables = [
    ClaveConfiguracion.nombreNegocio,
    ClaveConfiguracion.nit,
    ClaveConfiguracion.telefono,
    ClaveConfiguracion.direccion,
    ClaveConfiguracion.ciudad,
  ];

  bool _cargado = false;
  bool _guardando = false;

  @override
  void dispose() {
    for (final controlador in _controladores.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  /// Vuelca lo guardado en los campos, **una sola vez**. Si se hiciera en cada
  /// emisión del stream, guardar pisaría lo que el usuario está tecleando.
  void _volcar(Map<ClaveConfiguracion, String> valores) {
    if (_cargado) return;
    _cargado = true;
    for (final clave in _editables) {
      _controladores[clave]!.text = valores[clave] ?? clave.porDefecto;
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final repositorio = ref.read(repositorioConfiguracionProvider);
    try {
      for (final clave in _editables) {
        await repositorio.guardar(clave, _controladores[clave]!.text.trim());
      }
      if (!mounted) return;
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
              child: PanelSeccion(
                titulo: 'Datos del negocio',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AvisoEnLinea(
                      tono: TonoAviso.informacion,
                      mensaje: 'Esto es lo que sale impreso en la cabecera de '
                          'las facturas, reservas y cotizaciones.',
                    ),
                    const SizedBox(height: 16),
                    FilaCampos(
                      hijos: [
                        CampoTexto(
                          etiqueta: 'Nombre del taller',
                          controlador:
                              _controladores[ClaveConfiguracion.nombreNegocio]!,
                        ),
                        CampoTexto(
                          etiqueta: 'NIT',
                          controlador: _controladores[ClaveConfiguracion.nit]!,
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
                    FilaCampos(
                      hijos: [
                        CampoTexto(
                          etiqueta: 'Ciudad',
                          controlador:
                              _controladores[ClaveConfiguracion.ciudad]!,
                        ),
                        const _CampoInformativo(
                          etiqueta: 'Moneda',
                          valor: 'Peso colombiano (COP \$)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _CampoInformativo(
                      etiqueta: 'IVA',
                      valor: hayIva
                          ? etiquetaIva
                          : 'Sin IVA. Los precios del catálogo son el total.',
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Un dato del negocio que hoy **no se puede cambiar desde aquí**.
///
/// Se muestra deshabilitado en vez de esconderse porque el usuario necesita
/// saber con qué moneda y con qué IVA está trabajando la app; y no editable
/// porque cambiarlo no cambiaría nada: los dos viven en el código
/// (`core/formato.dart` y `core/iva_app.dart`).
class _CampoInformativo extends StatelessWidget {
  const _CampoInformativo({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return CampoTexto(
      etiqueta: etiqueta,
      controlador: TextEditingController(text: valor),
      habilitado: false,
    );
  }
}
