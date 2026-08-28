import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../provider/tecnico_provider.dart';
import '../widgets/grilla_tecnicos.dart';
import 'tecnico_formulario_vista.dart';

/// Pantalla de Técnicos: personal mecánico del taller en grilla.
///
/// Igual que Productos, Categorías y Proveedores, hospeda la navegación
/// interna del módulo —catálogo y formulario— sin rutas globales. El alta y
/// la edición van en página completa, no en diálogo.
class TecnicosVista extends ConsumerStatefulWidget {
  const TecnicosVista({super.key});

  @override
  ConsumerState<TecnicosVista> createState() => _TecnicosVistaState();
}

/// Vista activa dentro del módulo.
enum _Pantalla { lista, formulario }

class _TecnicosVistaState extends ConsumerState<TecnicosVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  _Pantalla _pantalla = _Pantalla.lista;
  Tecnico? _seleccionado;

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
      ref.read(tecnicosProvider.notifier).buscar(texto);
    });
  }

  void _nuevoTecnico() => setState(() {
    _seleccionado = null;
    _pantalla = _Pantalla.formulario;
  });

  void _editar(Tecnico tecnico) => setState(() {
    _seleccionado = tecnico;
    _pantalla = _Pantalla.formulario;
  });

  void _volverALista() => setState(() => _pantalla = _Pantalla.lista);

  @override
  Widget build(BuildContext context) {
    return switch (_pantalla) {
      _Pantalla.lista => _lista(),
      _Pantalla.formulario => TecnicoFormularioVista(
        tecnicoAEditar: _seleccionado,
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
            const _EncabezadoTecnicos(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BarraBusqueda(
                    controlador: _busquedaController,
                    focoTeclado: _focoBusqueda,
                    placeholder: 'Buscar técnico o cédula...',
                    alCambiar: _alBuscar,
                  ),
                ),
                const SizedBox(width: 20),
                BotonPrimario(
                  etiqueta: 'Nuevo técnico',
                  icono: Icons.add,
                  alPresionar: _nuevoTecnico,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _ChipsEstado(),
            const SizedBox(height: 16),
            Expanded(child: GrillaTecnicos(alEditar: _editar)),
          ],
        ),
      ),
    );
  }
}

/// Encabezado con los conteos del catálogo.
class _EncabezadoTecnicos extends ConsumerWidget {
  const _EncabezadoTecnicos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(tecnicosResumenProvider).value;
    final total = resumen?.total ?? 0;
    final activos = resumen?.activos ?? 0;

    final buffer = StringBuffer('Personal mecánico del taller');
    if (total > 0) {
      buffer.write(total == 1 ? ' · 1 técnico' : ' · $total técnicos');
      if (activos < total) buffer.write(' · $activos activos');
    }

    return EncabezadoConCuenta(
      titulo: 'Técnicos',
      subtitulo: buffer.toString(),
    );
  }
}

/// Chips de filtro por estado (sigue trabajando en el taller o no).
class _ChipsEstado extends ConsumerWidget {
  const _ChipsEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(
      tecnicosProvider.select((s) => s.value?.filtroActivo),
    );

    void filtrar(bool? valor) =>
        ref.read(tecnicosProvider.notifier).filtrarPorActivo(valor);

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
