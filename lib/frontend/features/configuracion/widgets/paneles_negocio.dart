import 'package:flutter/material.dart';

import '../../../../backend/features/configuracion/modelo/clave_configuracion.dart';
import '../../../share/share.dart';

/// Los dos paneles de texto libre de la pestaña General: quién es el taller y
/// qué dice el pie de sus facturas.
///
/// Viven aquí y no dentro de `TabGeneral` porque ese archivo pasaba de las 300
/// líneas de las reglas, y porque estos dos bloques son **solo presentación**:
/// reciben los controladores ya creados y no deciden nada. El estado —cargar,
/// guardar, aplicar la tasa— se queda en la pestaña, que es de quien es.
///
/// Reciben el mapa entero de controladores y no uno por campo por lo mismo que
/// `TabGeneral` lo tiene así: agregar un dato del negocio es agregar una clave
/// a [ClaveConfiguracion], y no tres parámetros repartidos por dos archivos.

/// Nombre, NIT, contacto, ubicación y los datos fiscales del encabezado.
///
/// **Es lo que sale impreso en la cabecera de cada documento.** Los campos
/// fiscales —responsabilidad de IVA y actividad económica— son texto libre a
/// propósito: se imprimen tal cual y ningún cálculo los consume.
///
/// Parámetros:
/// - [controladores]: los de `TabGeneral`, uno por clave de texto.
///
/// Ejemplo:
/// ```dart
/// PanelDatosNegocio(controladores: _controladores)
/// ```
class PanelDatosNegocio extends StatelessWidget {
  const PanelDatosNegocio({super.key, required this.controladores});

  final Map<ClaveConfiguracion, TextEditingController> controladores;

  TextEditingController _de(ClaveConfiguracion clave) => controladores[clave]!;

  @override
  Widget build(BuildContext context) {
    return PanelSeccion(
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
            controlador: _de(ClaveConfiguracion.nombreNegocio),
          ),
          CampoTexto(
            etiqueta: 'NIT',
            controlador:
                _de(ClaveConfiguracion.nit),
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
                _de(ClaveConfiguracion.telefono),
          ),
          CampoTexto(
            etiqueta: 'Dirección',
            controlador:
                _de(ClaveConfiguracion.direccion),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FilaCampos(
        hijos: [
          CampoTexto(
            etiqueta: 'Ciudad',
            controlador:
                _de(ClaveConfiguracion.ciudad),
          ),
          CampoTexto(
            etiqueta: 'Correo',
            controlador:
                _de(ClaveConfiguracion.correo),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FilaCampos(
        hijos: [
          CampoTexto(
            etiqueta: 'Responsabilidad de IVA',
            placeholder: 'Responsable de IVA',
            controlador: _de(ClaveConfiguracion.regimenIva),
          ),
          CampoTexto(
            etiqueta: 'Actividad económica',
            placeholder: '4530',
            controlador: _de(ClaveConfiguracion.actividadEconomica),
            monoespaciado: true,
          ),
        ],
      ),
    ],
  ),
);
  }
}

/// La letra pequeña que cierra cada factura: condiciones, garantía, avisos.
///
/// Vacío, la factura no lleva pie. Es deliberado: un texto de ejemplo que
/// nadie revisó lo lee el cliente como una promesa del taller.
///
/// Parámetros:
/// - [controladores]: los de `TabGeneral`, uno por clave de texto.
///
/// Ejemplo:
/// ```dart
/// PanelPieFactura(controladores: _controladores)
/// ```
class PanelPieFactura extends StatelessWidget {
  const PanelPieFactura({super.key, required this.controladores});

  final Map<ClaveConfiguracion, TextEditingController> controladores;

  TextEditingController _de(ClaveConfiguracion clave) => controladores[clave]!;

  @override
  Widget build(BuildContext context) {
    return PanelSeccion(
  titulo: 'Pie de la factura',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CampoTexto(
        etiqueta: 'Condiciones y avisos',
        placeholder: 'Después de 5 días calendario no se '
            'aceptan devoluciones. Conserve esta factura '
            'para cambios.',
        controlador:
            _de(ClaveConfiguracion.notaFactura),
        lineas: 3,
      ),
      const SizedBox(height: 8),
      Text(
        'Sale al pie de cada factura, tal como se escriba. '
        'Vacío, la factura no lleva pie: un texto inventado '
        'el cliente lo lee como una promesa del taller.',
        style: TipografiaApp.caption
            .copyWith(color: ColoresApp.textMuted),
      ),
    ],
  ),
);
  }
}
