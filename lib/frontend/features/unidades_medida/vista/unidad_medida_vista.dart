import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share2/share2.dart';
import '../provider/unidades_medida_provider.dart';

enum _Modo { lista, formulario }

/// Pestaña "Unidades de medida" de Configuración: tabla paginada y filtrable
/// por nombre, con creación, edición y eliminación. Vive fuera de `share2`
/// porque conecta directamente con [unidadesMedidaProvider] (Riverpod) —
/// share2 es puramente presentacional.
class UnidadesMedidaVista extends ConsumerStatefulWidget {
  const UnidadesMedidaVista({super.key});

  @override
  ConsumerState<UnidadesMedidaVista> createState() =>
      _UnidadesMedidaVistaState();
}

class _UnidadesMedidaVistaState extends ConsumerState<UnidadesMedidaVista> {
  static const int _itemsPorPagina = 50;

  _Modo _modo = _Modo.lista;
  UnidadMedida? _unidadEnEdicion;
  int _pagina = 0;
  bool _guardando = false;

  final _busquedaController = TextEditingController();
  final _nombreController = TextEditingController();
  final _abreviaturaController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _tipoSeleccionado = UnidadMedida.tiposDisponibles.first;

  @override
  void dispose() {
    _busquedaController.dispose();
    _nombreController.dispose();
    _abreviaturaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _abrirFormularioNuevo() {
    setState(() {
      _unidadEnEdicion = null;
      _nombreController.clear();
      _abreviaturaController.clear();
      _descripcionController.clear();
      _tipoSeleccionado = UnidadMedida.tiposDisponibles.first;
      _modo = _Modo.formulario;
    });
  }

  void _abrirFormularioEditar(UnidadMedida unidad) {
    setState(() {
      _unidadEnEdicion = unidad;
      _nombreController.text = unidad.nombre;
      _abreviaturaController.text = unidad.abreviatura;
      _descripcionController.text = unidad.descripcion ?? '';
      _tipoSeleccionado = unidad.tipo;
      _modo = _Modo.formulario;
    });
  }

  void _cerrarFormulario() => setState(() => _modo = _Modo.lista);

  void _mostrarError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error, style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo)),
        backgroundColor: ColoresApp.statusDanger,
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);

    final notifier = ref.read(unidadesMedidaProvider.notifier);
    final unidadEnEdicion = _unidadEnEdicion;
    final error = unidadEnEdicion == null
        ? await notifier.crear(
            nombre: _nombreController.text,
            abreviatura: _abreviaturaController.text,
            tipo: _tipoSeleccionado,
            descripcion: _descripcionController.text,
          )
        : await notifier.actualizar(
            id: unidadEnEdicion.id!,
            nombre: _nombreController.text,
            abreviatura: _abreviaturaController.text,
            tipo: _tipoSeleccionado,
            descripcion: _descripcionController.text,
          );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (error != null) {
      _mostrarError(error);
      return;
    }
    _cerrarFormulario();
  }

  Future<void> _eliminar(UnidadMedida unidad) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar "${unidad.nombre}"?',
      mensaje: 'Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;

    final error =
        await ref.read(unidadesMedidaProvider.notifier).eliminar(unidad.id!);
    if (!mounted || error == null) return;
    _mostrarError(error);
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(unidadesMedidaProvider);

    return estadoAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      ),
      error: (e, _) => Center(
        child: Text('Error al cargar unidades: $e', style: TipografiaApp.cuerpo),
      ),
      data: (estado) =>
          _modo == _Modo.formulario ? _formulario() : _lista(estado),
    );
  }

  Widget _lista(UnidadesMedidaState estado) {
    final unidades = estado.filtradas;
    final totalPaginas =
        unidades.isEmpty ? 1 : (unidades.length / _itemsPorPagina).ceil();
    final paginaActual = _pagina.clamp(0, totalPaginas - 1);
    final inicio = paginaActual * _itemsPorPagina;
    final itemsPagina =
        unidades.skip(inicio).take(_itemsPorPagina).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BarraBusqueda(
                controlador: _busquedaController,
                placeholder: 'Buscar unidad...',
                ancho: 320,
                alCambiar: (texto) {
                  setState(() => _pagina = 0);
                  ref.read(unidadesMedidaProvider.notifier).buscar(texto);
                },
              ),
              const Spacer(),
              BotonPrimario(
                etiqueta: 'Agregar unidad',
                icono: Icons.add,
                alPresionar: _abrirFormularioNuevo,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TablaGenerica<UnidadMedida>(
              items: itemsPagina,
              mensajeVacio: _busquedaController.text.isEmpty
                  ? 'Aún no hay unidades de medida registradas'
                  : 'Ninguna unidad coincide con la búsqueda',
              columnas: [
                ColumnaTabla(
                  titulo: 'Unidad',
                  flex: 2,
                  constructor: (u) =>
                      Text(u.nombre, style: TipografiaApp.cuerpoMedium),
                ),
                ColumnaTabla(
                  titulo: 'Abreviatura',
                  flex: 2,
                  constructor: (u) => Text(
                    u.abreviatura,
                    style: TipografiaApp.monoespaciada(
                      TipografiaApp.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.goGreen,
                      ),
                    ),
                  ),
                ),
                ColumnaTabla(
                  titulo: 'Uso típico',
                  flex: 4,
                  constructor: (u) => Text(
                    (u.descripcion?.trim().isNotEmpty ?? false)
                        ? u.descripcion!
                        : '—',
                    style: TipografiaApp.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ColumnaTabla(
                  titulo: 'Acciones',
                  ancho: 88,
                  alineacion: Alignment.centerRight,
                  constructor: (u) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BotonIcono(
                        icono: Icons.edit_outlined,
                        tooltip: 'Editar',
                        alPresionar: () => _abrirFormularioEditar(u),
                      ),
                      BotonIcono(
                        icono: Icons.delete_outline_rounded,
                        tooltip: 'Eliminar',
                        color: ColoresApp.statusDanger,
                        alPresionar: () => _eliminar(u),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PaginacionWidget(
            paginaActual: paginaActual,
            totalPaginas: totalPaginas,
            totalItems: unidades.length,
            itemsPorPagina: _itemsPorPagina,
            alCambiarPagina: (p) => setState(() => _pagina = p),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    final esEdicion = _unidadEnEdicion != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _guardando ? null : _cerrarFormulario,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded,
                        size: 16, color: ColoresApp.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Cancelar',
                      style: TipografiaApp.cuerpoMedium.copyWith(
                        color: ColoresApp.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              esEdicion ? 'Editar unidad de medida' : 'Nueva unidad de medida',
              style: TipografiaApp.heading1,
            ),
            const SizedBox(height: 4),
            Text(
              'Completa la información de la unidad',
              style: TipografiaApp.cuerpo.copyWith(
                color: ColoresApp.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            PanelSeccion(
              titulo: 'Información de la unidad',
              icono: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: CampoTexto(
                          etiqueta: 'Nombre',
                          controlador: _nombreController,
                          placeholder: 'Ej: Kilogramo',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CampoTexto(
                          etiqueta: 'Abreviatura',
                          controlador: _abreviaturaController,
                          placeholder: 'Ej: kg',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectorWidget<String>(
                          etiqueta: 'Tipo',
                          valor: _tipoSeleccionado,
                          opciones: UnidadMedida.tiposDisponibles,
                          constructorEtiqueta: (t) =>
                              t[0].toUpperCase() + t.substring(1),
                          alCambiar: (v) =>
                              setState(() => _tipoSeleccionado = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CampoTexto(
                          etiqueta: 'Uso típico',
                          controlador: _descripcionController,
                          placeholder: 'Ej: Repuestos individuales',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _guardando ? null : _cerrarFormulario,
                  child: Text(
                    'Cancelar',
                    style: TipografiaApp.cuerpoMedium.copyWith(
                      color: ColoresApp.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BotonPrimario(
                  etiqueta: _guardando ? 'Guardando...' : 'Guardar',
                  icono: Icons.check,
                  alPresionar: _guardando ? null : _guardar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
