import 'package:flutter/material.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../share2/share2.dart';
import 'identidad_proveedor.dart';

/// Tarjeta de un proveedor en la grilla del catálogo.
///
/// Replica la tarjeta del mockup: el marcador de almacén —igual para todos,
/// ver [IdentidadProveedor]—, el nombre,
/// NIT en monoespaciada y las líneas de contacto, teléfono y productos que
/// surte. Vive en el módulo y no en share2 porque traduce un [Proveedor] —un
/// modelo de dominio— a la [TarjetaCatalogo] compartida.
class TarjetaProveedor extends StatelessWidget {
  const TarjetaProveedor({
    super.key,
    required this.proveedor,
    required this.productos,
    this.alPresionar,
    this.alEditar,
    this.alEliminar,
  });

  final Proveedor proveedor;

  /// Cuántos productos surte. Llega ya calculado por un `GROUP BY`.
  final int productos;

  final VoidCallback? alPresionar;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final nit = proveedor.nitCedula?.trim() ?? '';

    return TarjetaCatalogo(
      marcador: const MarcadorIdentidad(
        icono: IdentidadProveedor.icono,
        color: IdentidadProveedor.color,
        lado: 48,
        radio: 14,
      ),
      titulo: proveedor.nombre,
      alPresionar: alPresionar,
      acciones: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!proveedor.activo) ...[
            const IndicadorEstado(
              etiqueta: 'Inactivo',
              color: ColoresApp.statusNeutral,
              colorFondo: ColoresApp.statusNeutralBg,
            ),
            const SizedBox(width: 8),
          ],
          BotonIcono(
            icono: Icons.edit_outlined,
            tooltip: 'Editar',
            alPresionar: alEditar,
          ),
          BotonIcono(
            icono: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: ColoresApp.statusDanger,
            alPresionar: alEliminar,
          ),
        ],
      ),
      pie: _Contacto(proveedor: proveedor, productos: productos, nit: nit),
    );
  }
}

/// Líneas de datos del pie de la tarjeta.
///
/// Los campos opcionales que están vacíos no dejan hueco: la tarjeta se
/// encoge, y la grilla ya reserva el alto del caso completo.
class _Contacto extends StatelessWidget {
  const _Contacto({
    required this.proveedor,
    required this.productos,
    required this.nit,
  });

  final Proveedor proveedor;
  final int productos;
  final String nit;

  @override
  Widget build(BuildContext context) {
    final contacto = proveedor.contacto?.trim() ?? '';
    final telefono = proveedor.telefono?.trim() ?? '';
    final ciudad = proveedor.ciudad?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nit.isNotEmpty) ...[
          Text(
            'NIT $nit',
            style: TipografiaApp.monoespaciada(
              TipografiaApp.caption.copyWith(
                fontSize: 12,
                color: ColoresApp.textMuted,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 11),
        ],
        if (contacto.isNotEmpty) ...[
          FilaDato(icono: Icons.person_outline_rounded, texto: contacto),
          const SizedBox(height: 9),
        ],
        if (telefono.isNotEmpty) ...[
          FilaDato(icono: Icons.phone_outlined, texto: telefono),
          const SizedBox(height: 9),
        ],
        if (ciudad.isNotEmpty) ...[
          FilaDato(icono: Icons.location_on_outlined, texto: ciudad),
          const SizedBox(height: 9),
        ],
        FilaDato(
          icono: Icons.inventory_2_outlined,
          texto: productos == 1 ? '1 producto' : '$productos productos',
          color: ColoresApp.castletonGreen,
          destacado: true,
        ),
      ],
    );
  }
}
