import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../share2/share2.dart';
import '../../ventas/servicios/provider/servicios_provider.dart';
import '../../ventas/servicios/widgets/dialogo_servicios.dart';

/// Pestaña "Servicios" de Configuración: catálogo de servicios del taller en
/// formato de tabla, con búsqueda y alta/edición/eliminación.
///
/// Reutiliza [DialogoServicio] del módulo de Ventas en lugar de duplicar el
/// formulario: es el mismo catálogo visto desde otra pantalla.
///
/// Lee [serviciosProvider] directamente (en lugar de
/// `serviciosFiltradosProvider`) para mostrar también los servicios inactivos
/// —de ahí la columna "Estado"— sin alterar el filtro que comparte con Ventas.
class TabServicios extends ConsumerStatefulWidget {
  const TabServicios({super.key});

  @override
  ConsumerState<TabServicios> createState() => _TabServiciosState();
}

class _TabServiciosState extends ConsumerState<TabServicios> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<Servicio> _filtrar(List<Servicio> servicios) {
    final query = _busqueda.trim().toLowerCase();
    if (query.isEmpty) return servicios;

    return servicios
        .where(
          (s) =>
              s.nombre.toLowerCase().contains(query) ||
              (s.descripcion?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
  }

  void _mostrarError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor: ColoresApp.statusDanger,
      ),
    );
  }

  Future<void> _eliminar(Servicio servicio) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar "${servicio.nombre}"?',
      mensaje: 'Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final error =
        await ref.read(serviciosProvider.notifier).eliminar(servicio.id);
    if (!mounted || error == null) return;
    _mostrarError(error);
  }

  @override
  Widget build(BuildContext context) {
    final asyncServicios = ref.watch(serviciosProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BarraBusqueda(
                controlador: _busquedaController,
                placeholder: 'Buscar servicio...',
                ancho: 320,
                alCambiar: (texto) => setState(() => _busqueda = texto),
              ),
              const Spacer(),
              BotonPrimario(
                etiqueta: 'Agregar servicio',
                icono: Icons.add,
                alPresionar: () => DialogoServicio.mostrar(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: asyncServicios.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: ColoresApp.goGreen),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error al cargar servicios: $e',
                  style: TipografiaApp.cuerpo,
                ),
              ),
              data: (servicios) => _tabla(_filtrar(servicios)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabla(List<Servicio> servicios) {
    return TablaGenerica<Servicio>(
      items: servicios,
      mensajeVacio: _busqueda.trim().isEmpty
          ? 'Aún no hay servicios registrados'
          : 'Ningún servicio coincide con la búsqueda',
      columnas: [
        ColumnaTabla(
          titulo: 'Servicio',
          flex: 3,
          constructor: (s) => Text(
            s.nombre,
            style: TipografiaApp.cuerpoMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Descripción',
          flex: 4,
          constructor: (s) => Text(
            (s.descripcion?.trim().isNotEmpty ?? false) ? s.descripcion! : '—',
            style: TipografiaApp.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ColumnaTabla(
          titulo: 'Estado',
          flex: 2,
          constructor: (s) => IndicadorEstado(
            etiqueta: s.activo ? 'Activo' : 'Inactivo',
            color: s.activo
                ? ColoresApp.statusSuccess
                : ColoresApp.statusNeutral,
            colorFondo: s.activo
                ? ColoresApp.statusSuccessBg
                : ColoresApp.statusNeutralBg,
            conPunto: true,
          ),
        ),
        ColumnaTabla(
          titulo: 'Acciones',
          ancho: 88,
          alineacion: Alignment.centerRight,
          constructor: (s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonIcono(
                icono: Icons.edit_outlined,
                tooltip: 'Editar',
                alPresionar: () =>
                    DialogoServicio.mostrar(context, servicioAEditar: s),
              ),
              BotonIcono(
                icono: Icons.delete_outline_rounded,
                tooltip: 'Eliminar',
                color: ColoresApp.statusDanger,
                alPresionar: () => _eliminar(s),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
