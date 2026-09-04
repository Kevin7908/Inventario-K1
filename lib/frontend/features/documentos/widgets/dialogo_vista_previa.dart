import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../share/share.dart';
import '../modelo/documento_imprimible.dart';
import '../servicio/constructor_pdf.dart';
import '../servicio/formato_impreso.dart';

/// La vista previa del impreso, con sus botones de imprimir y guardar.
///
/// **Es la única de la aplicación.** Recibe un [DocumentoImprimible] ya armado,
/// así que sirve igual para una factura del mostrador, una reserva, una
/// cotización, una orden, una deuda o una remisión de compra: quien la abre
/// traduce su modelo y esta pinta.
///
/// Vive en `features/documentos/` y no en `share/` por dos razones, las dos de
/// las reglas: depende de paquetes de pub.dev (`printing`), y conoce el modelo
/// de dominio del impreso.
///
/// Parámetros:
/// - [documento]: qué imprimir.
/// - [formato]: en qué papel se abre. Es el del taller, de
///   `leerAjustesImpresion`. Los botones de arriba lo cambian **solo para esta
///   impresión**: la orden que se entrega con la moto va en carta aunque la
///   caja imprima tirilla todo el día. Cambiar el del taller es ir a
///   Configuración.
///
/// Ejemplo:
/// ```dart
/// await DialogoVistaPrevia.mostrar(
///   context,
///   documento: doc,
///   formato: ajustes.formato,
/// );
/// ```
class DialogoVistaPrevia extends StatefulWidget {
  const DialogoVistaPrevia({
    super.key,
    required this.documento,
    this.formato = FormatoImpreso.carta,
  });

  final DocumentoImprimible documento;
  final FormatoImpreso formato;

  /// Abre el diálogo. Devuelve cuando el usuario lo cierra.
  static Future<void> mostrar(
    BuildContext context, {
    required DocumentoImprimible documento,
    FormatoImpreso formato = FormatoImpreso.carta,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoVistaPrevia(
          documento: documento,
          formato: formato,
        ),
      );

  @override
  State<DialogoVistaPrevia> createState() => _DialogoVistaPreviaState();
}

class _DialogoVistaPreviaState extends State<DialogoVistaPrevia> {
  late FormatoImpreso _formato = widget.formato;

  /// Nombre con el que se guarda o se comparte: «Factura-de-venta-F-000123».
  ///
  /// Sin espacios ni barras, que es lo que rompe un nombre de archivo en
  /// Windows y en Linux por igual.
  String get _nombreArchivo =>
      '${widget.documento.titulo}-${widget.documento.numero}'
          .replaceAll(RegExp(r'[\s/\\]+'), '-');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Column(
          children: [
            _Encabezado(
              titulo: widget.documento.titulo,
              numero: widget.documento.numero,
              formato: _formato,
              alCambiarFormato: (f) => setState(() => _formato = f),
              alCerrar: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: PdfPreview(
                // La clave fuerza un estado nuevo al cambiar de papel: sin
                // ella el visor se queda con el PDF anterior, porque solo
                // rearma su documento si le cambia el callback.
                key: ValueKey(_formato),
                // El constructor ignora el formato que ofrece la barra del
                // visor: el papel lo decide el selector de arriba, que es el
                // que además reacomoda las columnas.
                build: (_) => const ConstructorPdf()
                    .construir(widget.documento, formato: _formato),
                pdfFileName: '$_nombreArchivo.pdf',
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                useActions: true,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: ColoresApp.goGreen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.titulo,
    required this.numero,
    required this.formato,
    required this.alCambiarFormato,
    required this.alCerrar,
  });

  final String titulo;
  final String numero;
  final FormatoImpreso formato;
  final ValueChanged<FormatoImpreso> alCambiarFormato;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ColoresApp.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TipografiaApp.heading3),
                const SizedBox(height: 2),
                Text(numero, style: TipografiaApp.caption),
              ],
            ),
          ),
          // Los tres formatos a la vista y no un desplegable: son tres y el
          // gesto es comparar, no elegir de una lista.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opcion in FormatoImpreso.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChipFiltro(
                    etiqueta: opcion.etiqueta,
                    seleccionado: opcion == formato,
                    alPresionar: () => alCambiarFormato(opcion),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          BotonIcono(
            icono: Icons.close,
            tooltip: 'Cerrar',
            alPresionar: alCerrar,
          ),
        ],
      ),
    );
  }
}
