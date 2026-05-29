import 'package:flutter/material.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';
import '../../../share/widgets/output/badge_estado.dart';

// Mapa de íconos (top-level const — instancia única en toda la app)
const Map<String, IconData> _iconosProveedorMapa = {
  'store': Icons.store_outlined,
  'local_shipping': Icons.local_shipping_outlined,
  'factory': Icons.factory_outlined,
  'handshake': Icons.handshake_outlined,
  'inventory': Icons.inventory_2_outlined,
  'build': Icons.build_outlined,
  'oil_barrel': Icons.oil_barrel_outlined,
  'settings': Icons.settings_outlined,
  'electrical_services': Icons.electrical_services_outlined,
  'construction': Icons.construction_outlined,
};

class TarjetaProveedorWidget extends StatefulWidget {
  const TarjetaProveedorWidget({
    super.key,
    required this.proveedor,
    this.alEditar,
    this.alEliminar,
  });

  final Proveedor proveedor;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  State<TarjetaProveedorWidget> createState() => _TarjetaProveedorWidgetState();
}

class _TarjetaProveedorWidgetState extends State<TarjetaProveedorWidget> {
  bool _hovering = false;

  // Cache: se calcula UNA vez, no en cada rebuild
  late final Color _color = _colorDesdeHex(widget.proveedor.colorHex);
  late final Color _colorFondo = _color.withOpacity(0.10);
  late final IconData _icono =
      _iconosProveedorMapa[widget.proveedor.icono] ?? Icons.store_outlined;

  static Color _colorDesdeHex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return ColoresApp.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proveedor;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering ? _color.withOpacity(0.55) : ColoresApp.border,
              width: _hovering ? 1.5 : 1.0,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: _color.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabecera
                _Cabecera(
                  nombre: p.nombre,
                  nitCedula: p.nitCedula,
                  activo: p.activo,
                  icono: _icono,
                  color: _color,
                  colorFondo: _colorFondo,
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: ColoresApp.border),
                const SizedBox(height: 12),

                // Datos de contacto
                _SeccionContacto(proveedor: p),

                const SizedBox(height: 14),
                const Divider(height: 1, color: ColoresApp.border),
                const SizedBox(height: 10),

                // Botones
                _BotonesAccion(
                  alEditar: widget.alEditar,
                  alEliminar: widget.alEliminar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.nombre,
    required this.nitCedula,
    required this.activo,
    required this.icono,
    required this.color,
    required this.colorFondo,
  });

  final String nombre;
  final String? nitCedula;
  final bool activo;
  final IconData icono;
  final Color color;
  final Color colorFondo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: colorFondo, shape: BoxShape.circle),
          child: Icon(icono, color: color, size: 24),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (nitCedula != null && nitCedula!.isNotEmpty) ...[
                const SizedBox(height: 3),

                Text(
                  'NIT: $nitCedula',
                  style: const TextStyle(
                    color: ColoresApp.textLight,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 8),

        BadgeEstado(activo: activo),
      ],
    );
  }
}

// Sección de contacto
class _SeccionContacto extends StatelessWidget {
  const _SeccionContacto({required this.proveedor});

  final Proveedor proveedor;

  @override
  Widget build(BuildContext context) {
    final p = proveedor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.contacto != null && p.contacto!.isNotEmpty)
          _FilaDato(icono: Icons.person_outline_rounded, texto: p.contacto!),
        if (p.telefono != null && p.telefono!.isNotEmpty)
          _FilaDato(icono: Icons.phone_outlined, texto: p.telefono!),
        if (p.email != null && p.email!.isNotEmpty)
          _FilaDato(icono: Icons.email_outlined, texto: p.email!),
        if (p.direccion != null && p.direccion!.isNotEmpty)
          _FilaDato(icono: Icons.location_on_outlined, texto: p.direccion!),
        if (p.ciudad != null && p.ciudad!.isNotEmpty)
          _FilaDato(icono: Icons.apartment_outlined, texto: p.ciudad!),
      ],
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icono, size: 14, color: ColoresApp.textLight),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: ColoresApp.textMedium,
                fontSize: 12.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonesAccion extends StatelessWidget {
  const _BotonesAccion({this.alEditar, this.alEliminar});

  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AccionBoton(
          icono: Icons.edit_outlined,
          alPresionar: alEditar,
          tooltip: 'Editar',
        ),
        const SizedBox(width: 8),
        AccionBoton(
          icono: Icons.delete_outline_rounded,
          alPresionar: alEliminar,
          tooltip: 'Eliminar',
          esDestructivo: true,
        ),
      ],
    );
  }
}
