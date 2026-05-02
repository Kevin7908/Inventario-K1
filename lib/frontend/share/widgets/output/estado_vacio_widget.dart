import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EstadoVacioWidget
//
// Widget genérico para mostrar un estado vacío en cualquier sección.
// Reemplaza los _EstadoVacio privados repetidos en cada vista.
//
// Ejemplo de uso en CategoríasVista:
//   EstadoVacioWidget(
//     icono: Icons.category_outlined,
//     textoSinDatos: 'Sin categorías aún',
//     textoSinResultados: 'No hay categorías que coincidan con tu búsqueda.',
//     textoCTA: 'Crea tu primera categoría presionando "Agregar".',
//     hayFiltro: vm.consultaBusqueda.isNotEmpty,
//   )
//
// Ejemplo de uso en UnidadesMedidaVista:
//   EstadoVacioWidget(
//     icono: Icons.straighten_outlined,
//     textoSinDatos: 'Sin unidades aún',
//     textoSinResultados: 'Ninguna unidad coincide con tu búsqueda.',
//     textoCTA: 'Crea tu primera unidad presionando "Agregar".',
//     hayFiltro: vm.consultaBusqueda.isNotEmpty,
//   )
// ─────────────────────────────────────────────────────────────────────────────
class EstadoVacioWidget extends StatelessWidget {
  final IconData icono;
  final String textoSinDatos;
  final String textoSinResultados;
  final String textoCTA;
  final bool hayFiltro;

  const EstadoVacioWidget({
    super.key,
    required this.icono,
    required this.textoSinDatos,
    required this.textoSinResultados,
    required this.textoCTA,
    this.hayFiltro = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ColoresApp.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: ColoresApp.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              hayFiltro ? 'Sin resultados' : textoSinDatos,
              style: const TextStyle(
                color: ColoresApp.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hayFiltro ? textoSinResultados : textoCTA,
              style: const TextStyle(
                color: ColoresApp.textMedium,
                fontSize: 13.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
