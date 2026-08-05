import 'package:flutter/material.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../share2/share2.dart';

/// Íconos que un proveedor puede tener guardados.
///
/// [clave] es lo que va en la columna `icono` de la base —en inglés, porque ya
/// hay datos guardados así— y [nombre] es la etiqueta que ve el usuario.
/// Es `const` y de nivel superior: una sola instancia para toda la app, en vez
/// de una lista nueva por cada tarjeta construida.
const List<({String clave, IconData icono, String nombre})> iconosProveedor = [
  (clave: 'local_shipping', icono: Icons.local_shipping_outlined, nombre: 'Camión'),
  (clave: 'store', icono: Icons.store_outlined, nombre: 'Almacén'),
  (clave: 'factory', icono: Icons.factory_outlined, nombre: 'Fábrica'),
  (clave: 'handshake', icono: Icons.handshake_outlined, nombre: 'Acuerdo'),
  (clave: 'inventory', icono: Icons.inventory_2_outlined, nombre: 'Inventario'),
  (clave: 'build', icono: Icons.build_outlined, nombre: 'Herramienta'),
  (clave: 'oil_barrel', icono: Icons.oil_barrel_outlined, nombre: 'Lubricantes'),
  (clave: 'settings', icono: Icons.settings_outlined, nombre: 'Repuestos'),
  (clave: 'electrical_services', icono: Icons.electrical_services_outlined, nombre: 'Eléctrico'),
  (clave: 'construction', icono: Icons.construction_outlined, nombre: 'Taller'),
];

/// Ícono guardado del proveedor, o el camión del diseño si no reconoce la
/// clave. El mockup dibuja todos los proveedores con un camión; el modelo ya
/// guarda cuál eligió el usuario, así que se respeta esa elección.
IconData iconoDeProveedor(String clave) {
  for (final opcion in iconosProveedor) {
    if (opcion.clave == clave) return opcion.icono;
  }
  return Icons.local_shipping_outlined;
}

/// Tarjeta de un proveedor en la grilla del catálogo.
///
/// Replica la tarjeta del mockup: marcador con el ícono del proveedor, nombre,
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
    final color = colorDeHex(proveedor.colorHex) ?? ColoresApp.statusInfo;
    final nit = proveedor.nitCedula?.trim() ?? '';

    return TarjetaCatalogo(
      marcador: MarcadorIdentidad(
        icono: iconoDeProveedor(proveedor.icono),
        color: color,
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
