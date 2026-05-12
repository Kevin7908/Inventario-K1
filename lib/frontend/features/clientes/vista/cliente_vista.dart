import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/share/database/locator.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/input/barra_busqueda_widget.dart';
import '../../../share/widgets/output/estado_error_widget.dart';
import '../../../share/widgets/output/estado_vacio_widget.dart';
import '../../../share/widgets/top_bar_widget.dart';
import '../view_model/clientes_view_model.dart';
import '../widget/dialogo_cliente_widget.dart';
import '../widget/tarjeta_cliente_widget.dart';

class ClientesVista extends StatefulWidget {
  const ClientesVista({super.key});

  @override
  State<ClientesVista> createState() => _ClientesVistaState();
}

class _ClientesVistaState extends State<ClientesVista> {
  late final ClientesViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = locator<ClientesViewModel>();
  }

  // ── Diálogo crear ─────────────────────────────────────────────────────────
  Future<void> _abrirCrear(BuildContext context) async {
    await DialogoCliente.mostrar(context, viewModel: _vm);
  }

  // ── Diálogo editar ────────────────────────────────────────────────────────
  Future<void> _abrirEditar(BuildContext context, Cliente cliente) async {
    await DialogoCliente.mostrar(context, viewModel: _vm, cliente: cliente);
  }

  // ── Confirmación eliminar ─────────────────────────────────────────────────
  Future<void> _confirmarEliminar(
    BuildContext context,
    Cliente cliente,
    ClientesViewModel vm,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar cliente?',
          style: TextStyle(color: ColoresApp.textDark, fontSize: 17),
        ),
        content: Text(
          'Se eliminará a ${cliente.nombreCompleto} de forma permanente.',
          style: const TextStyle(color: ColoresApp.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: ColoresApp.textMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final error = await vm.eliminar(cliente.id);
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
    return ChangeNotifierProvider<ClientesViewModel>.value(
      value: _vm,
      child: Consumer<ClientesViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: ColoresApp.bgContent,
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Top bar ───────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: TopBarConBoton(
                    titulo: 'Clientes',
                    etiquetaBoton: 'Agregar',
                    alPresionarBoton: () => _abrirCrear(context),
                  ),
                ),

                // ── Barra de búsqueda ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: BarraBusquedaWidget(
                      placeholder: 'Buscar por nombre, cédula, ciudad…',
                      alCambiar: vm.buscar,
                    ),
                  ),
                ),

                // ── Contador de resultados ────────────────────────────────────
                if (vm.estado == EstadoClientes.cargado)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${vm.clientes.length} cliente${vm.clientes.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresApp.textLight,
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Cuerpo según estado ───────────────────────────────────────
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

  Widget _buildCuerpo(BuildContext context, ClientesViewModel vm) {
    // Estado: Cargando
    if (vm.estado == EstadoClientes.cargando) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: ColoresApp.primary),
        ),
      );
    }

    // Estado: Error
    if (vm.estado == EstadoClientes.error) {
      return SliverFillRemaining(
        child: EstadoErrorWidget(
          mensaje: vm.mensajeError ?? 'Error desconocido',
          alReintentar: () {},
        ),
      );
    }

    // Estado: Lista vacía
    if (vm.clientes.isEmpty) {
      return SliverFillRemaining(
        child: EstadoVacioWidget(
          textoCTA: '',
          icono: Icons.people_outline,
          textoSinDatos: vm.textoBusqueda.isNotEmpty
              ? 'Sin resultados'
              : 'Sin clientes aún',
          textoSinResultados: vm.textoBusqueda.isNotEmpty
              ? 'Prueba con otro término de búsqueda'
              : 'Agrega tu primer cliente tocando "Agregar"',
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
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final cliente = vm.clientes[index];
            return TarjetaClienteWidget(
              key: ValueKey(cliente.id),
              cliente: cliente,
              alEditar: () => _abrirEditar(context, cliente),
              alEliminar: () => _confirmarEliminar(context, cliente, vm),
            );
          },
          childCount: vm.clientes.length,
        ),
      ),
    );
  }
}