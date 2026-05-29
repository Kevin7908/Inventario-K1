import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../backend/features/productos/modelo/producto.dart';
import '../../../share/temas/colores_app.dart';
import 'badget_estado_stock_widget.dart';

class DialogoDetalleProductoWidget extends StatelessWidget {
  const DialogoDetalleProductoWidget({super.key, required this.producto});

  final Producto producto;

  static void mostrar(BuildContext context, {required Producto producto}) {
    showDialog(
      context: context,
      builder: (_) => DialogoDetalleProductoWidget(producto: producto),
    );
  }

  static final _fmtPrecio = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final p = producto;

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          style: const TextStyle(
                            color: ColoresApp.textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${p.sku}',
                          style: const TextStyle(
                            color: ColoresApp.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  BadgeEstadoStock(estado: p.estadoStock),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: ColoresApp.textMedium,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: ColoresApp.bgContent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cuerpo scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen (vista previa completa)
                    _VistaPreviewImagen(imagenUrl: p.imagenUrl),

                    const SizedBox(height: 20),

                    // Precios
                    _SeccionPrecios(producto: p, fmt: _fmtPrecio),

                    const SizedBox(height: 16),
                    const Divider(color: ColoresApp.border, height: 1),
                    const SizedBox(height: 16),

                    // Stock
                    _SeccionStock(producto: p),

                    const SizedBox(height: 16),
                    const Divider(color: ColoresApp.border, height: 1),
                    const SizedBox(height: 16),

                    // Datos generales
                    _SeccionGeneral(producto: p),

                    if (p.descripcion != null &&
                        p.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(color: ColoresApp.border, height: 1),
                      const SizedBox(height: 16),
                      _etiquetaSeccion('Descripción'),
                      const SizedBox(height: 6),
                      Text(
                        p.descripcion!,
                        style: const TextStyle(
                          color: ColoresApp.textMedium,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Pie: botón cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresApp.textMedium,
                    side: const BorderSide(color: ColoresApp.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Subwidgets internos

class _VistaPreviewImagen extends StatelessWidget {
  const _VistaPreviewImagen({this.imagenUrl});
  final String? imagenUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        width: double.infinity,
        color: ColoresApp.bgContent,
        child: _buildContenido(),
      ),
    );
  }

  Widget _buildContenido() {
    if (imagenUrl == null || imagenUrl!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: ColoresApp.textLight,
            ),
            SizedBox(height: 8),
            Text(
              'Sin imagen',
              style: TextStyle(
                color: ColoresApp.textLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (imagenUrl!.startsWith('http://') ||
        imagenUrl!.startsWith('https://')) {
      return Image.network(
        imagenUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, e, st) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 40,
            color: ColoresApp.textLight,
          ),
        ),
      );
    }

    return Image.file(
      File(imagenUrl!),
      fit: BoxFit.contain,
      errorBuilder: (context, e, st) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 40,
          color: ColoresApp.textLight,
        ),
      ),
    );
  }
}


class _SeccionPrecios extends StatelessWidget {
  const _SeccionPrecios({
    required this.producto,
    required this.fmt,
  });
  final Producto producto;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiquetaSeccion('Precios'),
        const SizedBox(height: 10),
        Row(
          children: [
            _precioChip(
              label: 'Venta',
              valor: fmt.format(producto.precioVenta),
              destaque: true,
            ),
            const SizedBox(width: 10),
            _precioChip(
              label: 'Compra',
              valor: fmt.format(producto.precioCompra),
            ),
            if (producto.precioVentaTaller != null) ...[
              const SizedBox(width: 10),
              _precioChip(
                label: 'Taller',
                valor: fmt.format(producto.precioVentaTaller!),
              ),
            ],
          ],
        ),
        if (producto.aplicaIva) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 13, color: Color(0xFF10B981)),
              SizedBox(width: 4),
              Text(
                'Aplica IVA',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _precioChip({
    required String label,
    required String valor,
    bool destaque = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: destaque
            ? ColoresApp.primary.withValues(alpha: 0.08)
            : ColoresApp.bgContent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque
              ? ColoresApp.primary.withValues(alpha: 0.3)
              : ColoresApp.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: destaque ? ColoresApp.primary : ColoresApp.textLight,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              color: destaque ? ColoresApp.primary : ColoresApp.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


class _SeccionStock extends StatelessWidget {
  const _SeccionStock({required this.producto});
  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final stockStr = _fmt(p.stockActual);
    final minimoStr = _fmt(p.stockMinimo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiquetaSeccion('Stock'),
        const SizedBox(height: 10),
        Row(
          children: [
            _datoCompacto('Actual', '$stockStr ${'uds'}'),
            const SizedBox(width: 24),
            _datoCompacto('Mínimo', '$minimoStr ${'uds'}'),
            if (p.ubicacionBodega != null) ...[
              const SizedBox(width: 24),
              _datoCompacto('Ubicación', p.ubicacionBodega!),
            ],
          ],
        ),
      ],
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _datoCompacto(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ColoresApp.textLight,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: ColoresApp.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


class _SeccionGeneral extends StatelessWidget {
  const _SeccionGeneral({required this.producto});
  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiquetaSeccion('Información general'),
        const SizedBox(height: 10),
        if (p.categoriaNombre != null)
          _fila(Icons.category_outlined, 'Categoría', p.categoriaNombre!),
        if (p.proveedorNombre != null)
          _fila(Icons.store_outlined, 'Proveedor', p.proveedorNombre!),
        if (p.unidadMedidaNombre != null)
          _fila(Icons.straighten_outlined, 'Unidad', p.unidadMedidaNombre!),
        _fila(
          p.activo ? Icons.check_circle_outline : Icons.cancel_outlined,
          'Estado',
          p.activo ? 'Activo' : 'Inactivo',
        ),
      ],
    );
  }

  Widget _fila(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icono, size: 14, color: ColoresApp.textLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: ColoresApp.textLight,
              fontSize: 12.5,
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                color: ColoresApp.textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Helpers compartidos entre subwidgets

Widget _etiquetaSeccion(String texto) {
  return Text(
    texto.toUpperCase(),
    style: const TextStyle(
      color: ColoresApp.textLight,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );
}