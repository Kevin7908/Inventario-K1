import 'package:flutter/material.dart';
import 'package:inventario_k1/frontend/features/clientes/view_model/clientes_view_model.dart';
import 'package:provider/provider.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/share/database/locator.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../view_model/motos_view_model.dart';
import '../widgets/dialogo_motos.dart';
import '../widgets/tarjeta_moto_widget.dart';

class MotosVista extends StatefulWidget {
  const MotosVista({super.key});

  @override
  State<MotosVista> createState() => _MotosVistaState();
}

class _MotosVistaState extends State<MotosVista> {

  late final MotosViewModel _vm;
  late final ClientesViewModel _clientesVm;

  @override
  void initState() {
    super.initState();
    _vm = locator<MotosViewModel>();
    _clientesVm = locator<ClientesViewModel>();
  }

  //  Diálogo crear
  Future<void> _abrirCrear(BuildContext context) async {
    await DialogoMoto.mostrar(
      context,
      viewModel: _vm,
      clientesVm: _clientesVm,
    );
  }

  // Diálogo editar 
  Future<void> _abrirEditar(BuildContext context, Moto moto) async {
    await DialogoMoto.mostrar(
      context,
      viewModel: _vm,
      clientesVm: _clientesVm,
      moto: moto,
    );
  }

///////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
  // Confirmación eliminar (poner mi conformar nuevo)
  Future<void> _confirmarEliminar(
    BuildContext context,
    Moto moto,
    MotosViewModel vm,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar moto?',
          style: TextStyle(color: ColoresApp.textDark, fontSize: 17),
        ),
        content: Text(
          'Se eliminará la ${moto.marca} ${moto.modelo}'
          '${moto.placa != null ? ' (${moto.placa})' : ''} de forma permanente.',
          style: const TextStyle(color: ColoresApp.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: ColoresApp.textMedium),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final error = await vm.eliminar(moto.id);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $error'),
            backgroundColor: ColoresApp.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MotosViewModel>.value(
      value: _vm,
      child: Consumer<MotosViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: ColoresApp.bgContent,
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Top bar 
                SliverToBoxAdapter(
                  child: TopBarConBoton(
                    titulo: 'Motos',
                    etiquetaBoton: 'Agregar',
                    alPresionarBoton: () => _abrirCrear(context),
                  ),
                ),

                // Barra de búsqueda 
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: BarraBusquedaWidget(
                      placeholder:
                          'Buscar por marca, modelo, placa, cliente…',
                      alCambiar: vm.buscar,
                    ),
                  ),
                ),

                //  Contador de resultados
                if (vm.estado == EstadoMotos.cargado)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${vm.motos.length} moto${vm.motos.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresApp.textLight,
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Cuerpo según estado 
                _buildCuerpo(context, vm),

                // Padding inferior
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCuerpo(BuildContext context, MotosViewModel vm) {
    // Estado: Cargando
    if (vm.estado == EstadoMotos.cargando) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: ColoresApp.primary),
        ),
      );
    }

    // Estado: Error
    if (vm.estado == EstadoMotos.error) {
      return SliverFillRemaining(
        child: EstadoErrorWidget(
          mensaje: vm.mensajeError ?? 'Error desconocido',
          alReintentar: () {},
        ),
      );
    }

    // Estado: Lista vacía
    if (vm.motos.isEmpty) {
      return SliverFillRemaining(
        child: EstadoVacioWidget(
          textoCTA: '',
          icono: Icons.two_wheeler_outlined,
          textoSinDatos: vm.textoBusqueda.isNotEmpty
              ? 'Sin resultados'
              : 'Sin motos aún',
          textoSinResultados: vm.textoBusqueda.isNotEmpty
              ? 'Prueba con otro término de búsqueda'
              : 'Agrega tu primera moto tocando "Agregar"',
        ),
      );
    }

    // Estado: Grilla de tarjetas
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final moto = vm.motos[index];
            return TarjetaMotoWidget(
              key: ValueKey(moto.id),
              moto: moto,
              alEditar: () => _abrirEditar(context, moto),
              alEliminar: () => _confirmarEliminar(context, moto, vm),
            );
          },
          childCount: vm.motos.length,
        ),
      ),
    );
  }
}