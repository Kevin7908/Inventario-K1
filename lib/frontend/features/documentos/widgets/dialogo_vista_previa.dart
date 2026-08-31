import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../share/share.dart';
import '../modelo/documento_imprimible.dart';
import '../servicio/constructor_pdf.dart';

/// La vista previa del impreso, con sus botones de imprimir y guardar.
///
/// **Es la única de la aplicación.** Recibe un [DocumentoImprimible] ya armado,
/// así que sirve igual para una factura del mostrador, una reserva, una
/// cotización o una orden: quien la abre traduce su modelo y esta pinta.
///
/// Vive en `features/documentos/` y no en `share/` por dos razones, las dos de
/// las reglas: depende de paquetes de pub.dev (`printing`), y conoce el modelo
/// de dominio del impreso.
///
/// Parámetros:
/// - [documento]: qué imprimir.
///
/// Ejemplo:
/// ```dart
/// await DialogoVistaPrevia.mostrar(context, documento: doc);
/// ```
class DialogoVistaPrevia extends StatelessWidget {
  const DialogoVistaPrevia({super.key, required this.documento});

  final DocumentoImprimible documento;

  /// Abre el diálogo. Devuelve cuando el usuario lo cierra.
  static Future<void> mostrar(
    BuildContext context, {
    required DocumentoImprimible documento,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => DialogoVistaPrevia(documento: documento),
      );

  /// Nombre con el que se guarda o se comparte: «Factura-de-venta-F-000123».
  ///
  /// Sin espacios ni barras, que es lo que rompe un nombre de archivo en
  /// Windows y en Linux por igual.
  String get _nombreArchivo =>
      '${documento.titulo}-${documento.numero}'.replaceAll(RegExp(r'[\s/\\]+'), '-');

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
              titulo: documento.titulo,
              numero: documento.numero,
              alCerrar: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: PdfPreview(
                // El constructor ignora el formato que ofrece la barra: el
                // documento se diseñó en carta y cambiarlo a A4 desde aquí
                // descuadraría los anchos de las columnas.
                build: (_) => const ConstructorPdf().construir(documento),
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
    required this.alCerrar,
  });

  final String titulo;
  final String numero;
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
