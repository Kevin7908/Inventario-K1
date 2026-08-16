import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../core/resultado.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../provider/cliente_provider.dart';
import '../widgets/grilla_clientes.dart';
import 'cliente_detalle_vista.dart';
import 'cliente_formulario_vista.dart';

/// Pantalla de Clientes: quiénes son y qué motos tienen, en grilla.
///
/// Igual que Productos, Proveedores y Técnicos, hospeda la navegación interna
/// del módulo —catálogo, ficha y formulario— sin rutas globales. El alta y la
/// edición van en página completa, no en diálogo.
class ClientesVista extends ConsumerStatefulWidget {
  const ClientesVista({super.key});

  @override
  ConsumerState<ClientesVista> createState() => _ClientesVistaState();
}

/// Vista activa dentro del módulo.
enum _Pantalla { lista, detalle, formulario }

class _ClientesVistaState extends ConsumerState<ClientesVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  _Pantalla _pantalla = _Pantalla.lista;
  Cliente? _seleccionado;

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
      ref.read(clientesProvider.notifier).buscar(texto);
    });
  }

  void _nuevoCliente() => setState(() {
    _seleccionado = null;
    _pantalla = _Pantalla.formulario;
  });

  void _abrirFicha(Cliente cliente) => setState(() {
    _seleccionado = cliente;
    _pantalla = _Pantalla.detalle;
  });

  void _editar() => setState(() => _pantalla = _Pantalla.formulario);

  /// Tras guardar se vuelve a la lista y no a la ficha: el cliente que tenía
  /// en memoria quedó desactualizado, y releerlo solo para pintarlo un
  /// instante no aporta nada.
  void _volverALista() => setState(() {
    _seleccionado = null;
    _pantalla = _Pantalla.lista;
  });

  Future<void> _eliminar(Cliente cliente) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar a "${cliente.nombreCompleto}"?',
      mensaje: 'Se borrarán también sus motos. Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final resultado =
        await ref.read(clientesProvider.notifier).eliminar(cliente.id);
    if (!mounted) return;

    if (resultado case Fallo(:final mensaje)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensaje,
            style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
          ),
          backgroundColor: ColoresApp.statusDanger,
        ),
      );
      return;
    }
    _volverALista();
  }

  @override
  Widget build(BuildContext context) {
    final cliente = _seleccionado;

    return switch (_pantalla) {
      _Pantalla.lista => _lista(),
      _Pantalla.detalle when cliente != null => ClienteDetalleVista(
        cliente: cliente,
        alVolver: _volverALista,
        alEditar: _editar,
        alEliminar: () => _eliminar(cliente),
      ),
      _Pantalla.formulario => ClienteFormularioVista(
        clienteAEditar: cliente,
        alCerrar: _volverALista,
      ),
      // Sin cliente seleccionado no hay ficha que pintar.
      _Pantalla.detalle => _lista(),
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
            const _EncabezadoClientes(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busquedaController,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar por nombre, cédula, teléfono o ciudad...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nuevo cliente',
                  icono: Icons.add,
                  alPresionar: _nuevoCliente,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: GrillaClientes(alAbrir: _abrirFicha)),
          ],
        ),
      ),
    );
  }
}

/// Encabezado con los conteos del catálogo.
class _EncabezadoClientes extends ConsumerWidget {
  const _EncabezadoClientes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(clientesResumenProvider).value;
    final total = resumen?.total ?? 0;
    final conSaldo = resumen?.conSaldo ?? 0;

    final buffer = StringBuffer('Información de contacto y vehículos asociados');
    if (total > 0) {
      buffer.write(total == 1 ? ' · 1 cliente' : ' · $total clientes');
      if (conSaldo > 0) buffer.write(' · $conSaldo con saldo');
    }

    return EncabezadoConCuenta(
      titulo: 'Clientes',
      subtitulo: buffer.toString(),
    );
  }
}
