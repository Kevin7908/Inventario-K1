import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share/widgets/botones/accion_boton.dart';
import '../../../share/widgets/output/badge_estado.dart';


class TarjetaMotoWidget extends StatefulWidget {
  const TarjetaMotoWidget({
    super.key,
    required this.moto,
    this.alEditar,
    this.alEliminar,
  });

  final Moto moto;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  State<TarjetaMotoWidget> createState() => _TarjetaMotoWidgetState();
}

class _TarjetaMotoWidgetState extends State<TarjetaMotoWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.moto;

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
                  ? ColoresApp.primary.withOpacity(0.55)
                  : ColoresApp.border,
              width: _hovering ? 1.5 : 1.0,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: ColoresApp.primary.withOpacity(0.08),
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
                _Cabecera(moto: m),
                const SizedBox(height: 14),
                const Divider(height: 1, color: ColoresApp.border),
                const SizedBox(height: 12),
                _SeccionDetalles(moto: m),
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

// Cabecera 

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.moto});
  final Moto moto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar con iniciales
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: moto.activo
                ? ColoresApp.primaryLight
                : ColoresApp.statusDebtBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              moto.iniciales,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color:
                    moto.activo ? ColoresApp.primary : ColoresApp.accentRed,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Marca + Modelo
              Text(
                '${moto.marca} ${moto.modelo}',
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Placa (si existe)
              if (moto.placa != null && moto.placa!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ColoresApp.primaryLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    moto.placa!.toUpperCase(),
                    style: const TextStyle(
                      color: ColoresApp.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        BadgeEstado(activo: moto.activo),
      ],
    );
  }
}

// Sección de detalles 

class _SeccionDetalles extends StatelessWidget {
  const _SeccionDetalles({required this.moto});
  final Moto moto;

  @override
  Widget build(BuildContext context) {
    final m = moto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cliente propietario
        if (m.nombreCliente != null && m.nombreCliente!.isNotEmpty)
          _FilaDato(
            icono: Icons.person_outline_rounded,
            texto: m.nombreCliente!,
          ),
        // Año
        if (m.anio != null)
          _FilaDato(
            icono: Icons.calendar_today_outlined,
            texto: m.anio.toString(),
          ),
        // Cilindraje
        if (m.cilindraje != null)
          _FilaDato(
            icono: Icons.speed_outlined,
            texto: '${m.cilindraje} cc',
          ),
        // Color
        if (m.color != null && m.color!.isNotEmpty)
          _FilaDato(
            icono: Icons.palette_outlined,
            texto: m.color!,
          ),
        // VIN / Chasis
        if (m.vin != null && m.vin!.isNotEmpty)
          _FilaDato(
            icono: Icons.confirmation_number_outlined,
            texto: 'VIN: ${m.vin!}',
          ),
        // Número motor
        if (m.numeroMotor != null && m.numeroMotor!.isNotEmpty)
          _FilaDato(
            icono: Icons.settings_outlined,
            texto: 'Motor: ${m.numeroMotor!}',
          ),
        // Kilometraje inicial
        if (m.kilometrajeInicial > 0)
          _FilaDato(
            icono: Icons.route_outlined,
            texto: '${m.kilometrajeInicial} km iniciales',
          ),
        // Notas
        if (m.notas != null && m.notas!.isNotEmpty)
          _FilaDato(icono: Icons.notes_outlined, texto: m.notas!),
      ],
    );
  }
}

// ─── Fila de dato genérica ────────────────────────────────────────────────────

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

// ─── Botones de acción ────────────────────────────────────────────────────────

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