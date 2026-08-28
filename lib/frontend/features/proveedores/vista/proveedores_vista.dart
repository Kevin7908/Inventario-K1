import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../provider/proveedores_provider.dart';
import '../widgets/grilla_proveedores.dart';
import 'proveedor_formulario_vista.dart';

/// Pantalla de Proveedores: distribuidores y casas de repuestos en grilla.
///
/// Igual que Productos y Categorías, hospeda la navegación interna del módulo
/// —catálogo y formulario— sin rutas globales. El alta y la edición van en
/// página completa, no en diálogo.
class ProveedoresVista extends ConsumerStatefulWidget {
  const ProveedoresVista({super.key});

  @override
  ConsumerState<ProveedoresVista> createState() => _ProveedoresVistaState();
}

/// Vista activa dentro del módulo.
enum _Pantalla { lista, formulario }

class _ProveedoresVistaState extends ConsumerState<ProveedoresVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  _Pantalla _pantalla = _Pantalla.lista;
  Proveedor? _seleccionado;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(proveedoresProvider.notifier).buscar(texto);
    });
  }

  void _nuevoProveedor() => setState(() {
    _seleccionado = null;
    _pantalla = _Pantalla.formulario;
  });

  void _editar(Proveedor proveedor) => setState(() {
    _seleccionado = proveedor;
    _pantalla = _Pantalla.formulario;
  });

  void _volverALista() => setState(() => _pantalla = _Pantalla.lista);

  @override
  Widget build(BuildContext context) {
    return switch (_pantalla) {
      _Pantalla.lista => _lista(),
      _Pantalla.formulario => ProveedorFormularioVista(
        proveedorAEditar: _seleccionado,
        alCerrar: _volverALista,
      ),
    };
  }

  /// La raíz no observa ningún provider: cada bloque se suscribe al suyo, así
  /// que escribir en el buscador no reconstruye el encabezado ni los chips.
  Widget _lista() {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EncabezadoProveedores(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busquedaController,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar proveedor, NIT, ciudad...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nuevo proveedor',
                  icono: Icons.add,
                  alPresionar: _nuevoProveedor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _ChipsEstado(),
            const SizedBox(height: 16),
            Expanded(child: GrillaProveedores(alEditar: _editar)),
          ],
        ),
      ),
    );
  }
}

/// Encabezado con los conteos del catálogo.
class _EncabezadoProveedores extends ConsumerWidget {
  const _EncabezadoProveedores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(proveedoresResumenProvider).value;
    final total = resumen?.total ?? 0;
    final activos = resumen?.activos ?? 0;

    final buffer = StringBuffer('Distribuidores y casas de repuestos');
    if (total > 0) {
      buffer.write(total == 1 ? ' · 1 proveedor' : ' · $total proveedores');
      if (activos < total) buffer.write(' · $activos activos');
    }

    return EncabezadoConCuenta(
      titulo: 'Proveedores',
      subtitulo: buffer.toString(),
    );
  }
}

/// Chips de filtro por estado.
///
/// El diseño no los tiene, pero el modelo distingue activo de inactivo desde
/// siempre y la grilla mezclaría ambos sin forma de separarlos.
class _ChipsEstado extends ConsumerWidget {
  const _ChipsEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(
      proveedoresProvider.select((s) => s.value?.filtroActivo),
    );

    void filtrar(bool? valor) =>
        ref.read(proveedoresProvider.notifier).filtrarPorActivo(valor);

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        ChipFiltro(
          etiqueta: 'Todos',
          seleccionado: activo == null,
          alPresionar: () => filtrar(null),
        ),
        ChipFiltro(
          etiqueta: 'Activos',
          seleccionado: activo == true,
          colorActivo: ColoresApp.statusSuccess,
          alPresionar: () => filtrar(true),
        ),
        ChipFiltro(
          etiqueta: 'Inactivos',
          seleccionado: activo == false,
          colorActivo: ColoresApp.statusNeutral,
          alPresionar: () => filtrar(false),
        ),
      ],
    );
  }
}
