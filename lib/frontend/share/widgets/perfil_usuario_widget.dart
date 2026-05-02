import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

class PerfilUsuarioWidget extends StatelessWidget {
  final String nombre;
  final String rol;

  const PerfilUsuarioWidget({
    super.key,
    required this.nombre,
    required this.rol,
  });

  String _obtenerIniciales(String nombre) {
    final parts = nombre.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final iniciales = _obtenerIniciales(nombre);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ColoresApp.borderSidebar)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: ColoresApp.primary,
            child: Text(
              iniciales,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  color: ColoresApp.textWhite,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                rol,
                style: const TextStyle(
                  color: ColoresApp.textSidebarMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
