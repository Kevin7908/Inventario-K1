// frontend/features/proveedores/vistas/proveedores_vista.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/share/database/locator.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/botones/dialogo_confirmar_eliminar_widget.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/chip_filtro_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../view_model/proveedores_view_model.dart';
import '../widgets/dialogo_proveedor_widget.dart';
import '../widgets/tarjeta_proveedor_widget.dart';

class ProveedoresVista extends StatefulWidget {
  const ProveedoresVista({super.key});

  @override
  State<ProveedoresVista> createState() => _ProveedoresVistaState();
}

class _ProveedoresVistaState extends State<ProveedoresVista> {
  late final ProveedoresViewModel _vm;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _vm = locator<ProveedoresViewModel>();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _vm.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _vm.buscar(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProveedoresViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: ColoresApp.bgContent,
        body: Column(
          children: [
            // ── TopBar: no depende del VM → nunca se reconstruye por datos
            Consumer<ProveedoresViewModel>(
              builder: (context, vm, _) => TopBarConBoton(
                titulo: 'Proveedores',
                etiquetaBoton: 'Agregar',
                alPresionarBoton: () =>
                    DialogoProveedor.mostrar(context, viewModel: vm),
              ),
            ),

            BarraBusquedaWidget(
              placeholder: 'Buscar proveedor, NIT, ciudad...',
              alCambiar: _onSearchChanged,
            ),

            // ── El Consumer queda confinado al cuerpo de datos
            const Expanded(child: _CuerpoLista()),
          ],
        ),
      ),
    );
  }
}
class _CuerpoLista extends StatelessWidget {
  const _CuerpoLista();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedoresViewModel>(
      builder: (context, vm, _) {
        if (vm.estaCargando) {
          return const Center(
            child: CircularProgressIndicator(color: ColoresApp.primary),
          );
        }

        if (vm.estado == EstadoProveedores.error) {
          return EstadoErrorWidget(
            mensaje: vm.mensajeError ?? 'Error desconocido',
            alReintentar: vm.cargarProveedores,
          );
        }

        if (vm.proveedores.isEmpty) {
          return EstadoVacioWidget(
            icono: Icons.store_mall_directory_outlined,
            textoSinDatos: 'Sin proveedores aún',
            textoSinResultados: 'No hay proveedores que coincidan.',
            textoCTA: 'Crea tu primer proveedor presionando "Agregar".',
            hayFiltro:
                vm.consultaBusqueda.isNotEmpty || vm.filtroActivo != null,
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _ChipsFiltro(vm: vm),
                    const SizedBox(height: 14),
                    _ContadorProveedores(total: vm.proveedores.length),
                  ],
                ),
              ),
            ),
            _SliverGrillaProveedores(vm: vm),
          ],
        );
      },
    );
  }
}

class _ChipsFiltro extends StatelessWidget {
  const _ChipsFiltro({required this.vm});

  final ProveedoresViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ChipFiltro(
          etiqueta: 'Todos',
          seleccionado: vm.filtroActivo == null,
          alPresionar: () => vm.filtrarPorActivo(null),
        ),
        const SizedBox(width: 8),
        ChipFiltro(
          etiqueta: 'Activos',
          seleccionado: vm.filtroActivo == true,
          alPresionar: () => vm.filtrarPorActivo(true),
          color: const Color(0xFF10B981),
        ),
        const SizedBox(width: 8),
        ChipFiltro(
          etiqueta: 'Inactivos',
          seleccionado: vm.filtroActivo == false,
          alPresionar: () => vm.filtrarPorActivo(false),
          color: ColoresApp.textLight,
        ),
      ],
    );
  }
}

class _ContadorProveedores extends StatelessWidget {
  const _ContadorProveedores({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$total PROVEEDOR${total == 1 ? '' : 'ES'}',
      style: const TextStyle(
        color: ColoresApp.textLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}
class _SliverGrillaProveedores extends StatelessWidget {
  const _SliverGrillaProveedores({required this.vm});

  final ProveedoresViewModel vm;

  static const double _maxAnchoCelda = 340.0;
  static const double _espaciado = 16.0;
  static const double _alturaCelda = 320.0;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final proveedor = vm.proveedores[i];
            return TarjetaProveedorWidget(
              key: ValueKey(proveedor.id),
              proveedor: proveedor,
              alEditar: () => DialogoProveedor.mostrar(
                context,
                proveedorAEditar: proveedor,
                viewModel: vm,
              ),
              alEliminar: () => DialogoConfirmarEliminar.mostrar(
                context: context,
                nombreElemento: proveedor.nombre,
                tipoElemento: 'proveedor',
                onConfirmar: () => vm.eliminarProveedor(proveedor.id!),
              ),
            );
          },
          childCount: vm.proveedores.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _maxAnchoCelda,
          crossAxisSpacing: _espaciado,
          mainAxisSpacing: _espaciado,
          mainAxisExtent: _alturaCelda,
        ),
      ),
    );
  }
}