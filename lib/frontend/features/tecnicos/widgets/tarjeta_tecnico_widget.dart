import 'package:flutter/material.dart';

import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/accion_boton.dart';
import '../../../share/widgets/output/badge_estado.dart';

const List<Color> _coloresAvatar = [
  Color(0xFF3B82F6), // Azul
  Color(0xFF10B981), // Verde
  Color(0xFF8B5CF6), // Morado
  Color(0xFFF97316), // Naranja
  Color(0xFFEC4899), // Rosa
  Color(0xFF14B8A6), // Teal
  Color(0xFFEF4444), // Rojo
  Color(0xFFF59E0B), // Ámbar
];

Color _colorParaIniciales(String iniciales) {
  final code = iniciales.isNotEmpty ? iniciales.codeUnitAt(0) : 65;
  return _coloresAvatar[code % _coloresAvatar.length];
}

class TarjetaTecnicoWidget extends StatefulWidget {
  const TarjetaTecnicoWidget({
    super.key,
    required this.tecnico,
    this.alEditar,
    this.alEliminar,
  });

  final Tecnico tecnico;
  final VoidCallback? alEditar;
  final VoidCallback? alEliminar;

  @override
  State<TarjetaTecnicoWidget> createState() => _TarjetaTecnicoWidgetState();
}

class _TarjetaTecnicoWidgetState extends State<TarjetaTecnicoWidget> {
  bool _hovering = false;

  late final Color _colorAvatar =
      _colorParaIniciales(widget.tecnico.iniciales);
  late final Color _colorFondo = _colorAvatar.withOpacity(0.10);

  @override
  Widget build(BuildContext context) {
    final t = widget.tecnico;

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
                  ? _colorAvatar.withOpacity(0.50)
                  : ColoresApp.border,
              width: _hovering ? 1.5 : 1.0,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: _colorAvatar.withOpacity(0.08),
                      blurRadius: 16,
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
                // Cabecera (avatar + nombre + badge) 
                _CabeceraTecnico(
                  tecnico: t,
                  colorAvatar: _colorAvatar,
                  colorFondo: _colorFondo,
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: ColoresApp.border),
                const SizedBox(height: 12),

                // Datos de contacto
                _DatosContacto(tecnico: t),

                const Spacer(),
                const Divider(height: 1, color: ColoresApp.border),
                const SizedBox(height: 10),

                // Botones de acción 
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

class _CabeceraTecnico extends StatelessWidget {
  const _CabeceraTecnico({
    required this.tecnico,
    required this.colorAvatar,
    required this.colorFondo,
  });

  final Tecnico tecnico;
  final Color colorAvatar;
  final Color colorFondo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar con iniciales
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: colorFondo,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              tecnico.iniciales,
              style: TextStyle(
                color: colorAvatar,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
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
                tecnico.nombreCompleto,
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (tecnico.cedula != null && tecnico.cedula!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'CC: ${tecnico.cedula}',
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
        BadgeEstado(activo: tecnico.activo),
      ],
    );
  }
}

class _DatosContacto extends StatelessWidget {
  const _DatosContacto({required this.tecnico});

  final Tecnico tecnico;

  @override
  Widget build(BuildContext context) {
    final t = tecnico;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (t.telefono != null && t.telefono!.isNotEmpty)
          _FilaDato(icono: Icons.phone_outlined, texto: t.telefono!),
        if (t.email != null && t.email!.isNotEmpty)
          _FilaDato(icono: Icons.email_outlined, texto: t.email!),
        if (t.salarioBase != null)
          _FilaDato(
            icono: Icons.payments_outlined,
            texto:
                '\$${t.salarioBase!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
          ),
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