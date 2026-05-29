import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

// TopBar básico sin botón de acción primaria
class TopBarWidget extends StatelessWidget {
  final String titulo;
  final Widget? accionesSufijo;
  final bool mostrarBotonVolver;
  final VoidCallback? alPresionarVolver;

  const TopBarWidget({
    super.key,
    required this.titulo,
    this.accionesSufijo,
    this.mostrarBotonVolver = false,
    this.alPresionarVolver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      color: ColoresApp.bgCard,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (mostrarBotonVolver) ...[
                _BotonVolver(alPresionar: alPresionarVolver),
                const SizedBox(width: 12),
              ],
              Text(
                titulo,
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          accionesSufijo ?? const _BotonNotificaciones(),
        ],
      ),
    );
  }
}

// TopBar con botón de acción primaria (+ Agregar)
class TopBarConBoton extends StatelessWidget {
  final String titulo;
  final String etiquetaBoton;
  final VoidCallback? alPresionarBoton;
  final bool mostrarBotonVolver;
  final VoidCallback? alPresionarVolver;

  const TopBarConBoton({
    super.key,
    required this.titulo,
    required this.etiquetaBoton,
    this.alPresionarBoton,
    this.mostrarBotonVolver = false,
    this.alPresionarVolver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      color: ColoresApp.bgCard,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (mostrarBotonVolver) ...[
                _BotonVolver(alPresionar: alPresionarVolver),
                const SizedBox(width: 12),
              ],
              Text(
                titulo,
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const _BotonNotificaciones(),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: alPresionarBoton,
                icon: const Icon(Icons.add, size: 16),
                label: Text(etiquetaBoton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColoresApp.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widgets internos

class _BotonVolver extends StatelessWidget {
  final VoidCallback? alPresionar;
  const _BotonVolver({this.alPresionar});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: alPresionar ?? () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
      label: const Text('Volver'),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.textMedium,
        side: const BorderSide(color: ColoresApp.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _BotonNotificaciones extends StatelessWidget {
  const _BotonNotificaciones();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: ColoresApp.textMedium,
            size: 22,
          ),
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: ColoresApp.bgContent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: ColoresApp.accentRed,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
