import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';
import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../share/widgets/botones/accion_boton.dart';
import '../../../share/widgets/output/badge_estado.dart';

/// Tarjeta que muestra toda la información de contacto de un [Cliente].
/// Se usa dentro del SliverGrid de [ClientesVista].
class TarjetaClienteWidget extends StatefulWidget {
  const TarjetaClienteWidget({
    super.key,
    required this.cliente,
    this.alEditar,
    this.alEliminar,
  });

  final Cliente cliente;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  State<TarjetaClienteWidget> createState() => _TarjetaClienteWidgetState();
}

class _TarjetaClienteWidgetState extends State<TarjetaClienteWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;

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
              color: _hovering
                  ? ColoresApp.primary.withValues(alpha: 0.55)
                  : ColoresApp.border,
              width: _hovering ? 1.5 : 1.0,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: ColoresApp.primary.withValues(alpha: 0.08),
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
                _Cabecera(cliente: c),
                const SizedBox(height: 14),
                const Divider(height: 1, color: ColoresApp.border),
                const SizedBox(height: 12),
                _SeccionContacto(cliente: c),
                const SizedBox(height: 14),
                const Divider(height: 1, color: ColoresApp.border),
                const SizedBox(height: 10),
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
  const _Cabecera({required this.cliente});
  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cliente.activo
                ? ColoresApp.primaryLight
                : ColoresApp.statusDebtBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              cliente.iniciales,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cliente.activo ? ColoresApp.primary : ColoresApp.accentRed,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cliente.nombreCompleto,
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (cliente.cedula != null && cliente.cedula!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'CC: ${cliente.cedula}',
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
        BadgeEstado(activo: cliente.activo),
      ],
    );
  }
}

class _SeccionContacto extends StatelessWidget {
  const _SeccionContacto({required this.cliente});
  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final c = cliente;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (c.telefono != null && c.telefono!.isNotEmpty)
          _FilaDato(icono: Icons.phone_outlined, texto: c.telefono!),
        if (c.email != null && c.email!.isNotEmpty)
          _FilaDato(icono: Icons.email_outlined, texto: c.email!),
        if (c.ciudad != null && c.ciudad!.isNotEmpty)
          _FilaDato(icono: Icons.apartment_outlined, texto: c.ciudad!),
        if (c.direccion != null && c.direccion!.isNotEmpty)
          _FilaDato(icono: Icons.location_on_outlined, texto: c.direccion!),
        if (c.notas != null && c.notas!.isNotEmpty)
          _FilaDato(icono: Icons.notes_outlined, texto: c.notas!),
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