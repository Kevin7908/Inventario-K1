import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/tecnicos/modelo/tecnico.dart';
import '../../../../../backend/features/ventas/servicios/modelo/servicio.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../../../tecnicos/provider/tecnico_provider.dart';
import '../provider/catalogo_orden_providers.dart';
import '../provider/orden_editor_provider.dart';

/// Catálogo de servicios del editor de órdenes: la lista de mano de obra.
///
/// ## La diferencia con cotizaciones
///
/// En una cotización, tocar un servicio lo manda directo a la lista de la
/// derecha y el precio se ajusta allá. Aquí no se puede: `ordenes_tareas`
/// exige **técnico** (`NOT NULL`) y una tarea sin técnico no es una tarea. Si
/// la línea cruzara a la derecha incompleta, habría que inventar un estado a
/// medias en memoria y decidir qué hace el autoguardado con ella.
///
/// Por eso la fila **se expande en el sitio**: al tocarla aparecen el selector
/// de técnico y el precio, y la línea cruza a la orden ya completa. También es
/// donde hay ancho para ponerlos —el panel derecho mide 360 px.
///
/// El técnico viene precargado con el de la última tarea de esta orden: una
/// moto la suele trabajar el mismo mecánico de principio a fin. El precio,
/// con el sugerido del catálogo.
class TablaServiciosOrden extends ConsumerStatefulWidget {
  const TablaServiciosOrden({
    super.key,
    required this.ordenId,
    required this.habilitado,
  });

  final int ordenId;

  /// En `false` la lista se ve pero no deja agregar: la orden ya está
  /// entregada o anulada.
  final bool habilitado;

  @override
  ConsumerState<TablaServiciosOrden> createState() =>
      _TablaServiciosOrdenState();
}

class _TablaServiciosOrdenState extends ConsumerState<TablaServiciosOrden> {
  /// Cuál fila está abierta. Es estado local de la interfaz: subirlo al editor
  /// haría que abrir una fila reconstruyera también el panel de la orden.
  int? _expandido;

  void _alternar(int servicioId) => setState(
        () => _expandido = _expandido == servicioId ? null : servicioId,
      );

  @override
  Widget build(BuildContext context) {
    final servicios = ref.watch(serviciosOrdenProvider(widget.ordenId));

    if (servicios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Ningún servicio coincide con la búsqueda.',
            textAlign: TextAlign.center,
            style: TipografiaApp.caption,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: servicios.length,
      // Sin `itemExtent`: la fila abierta mide distinto que las cerradas.
      itemBuilder: (context, i) {
        final servicio = servicios[i];
        return _FilaServicio(
          key: ValueKey(servicio.id),
          servicio: servicio,
          ordenId: widget.ordenId,
          habilitado: widget.habilitado,
          abierta: _expandido == servicio.id,
          alTocar: () => _alternar(servicio.id),
          alAgregar: () => setState(() => _expandido = null),
        );
      },
    );
  }
}

/// Una fila del catálogo de servicios: cerrada muestra nombre y precio
/// sugerido; abierta, los dos campos que le faltan a la tarea.
class _FilaServicio extends ConsumerStatefulWidget {
  const _FilaServicio({
    super.key,
    required this.servicio,
    required this.ordenId,
    required this.habilitado,
    required this.abierta,
    required this.alTocar,
    required this.alAgregar,
  });

  final Servicio servicio;
  final int ordenId;
  final bool habilitado;
  final bool abierta;
  final VoidCallback alTocar;
  final VoidCallback alAgregar;

  @override
  ConsumerState<_FilaServicio> createState() => _FilaServicioState();
}

class _FilaServicioState extends ConsumerState<_FilaServicio> {
  final _precio = TextEditingController();
  Tecnico? _tecnico;

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_FilaServicio anterior) {
    super.didUpdateWidget(anterior);
    // Al abrirse se precarga: el precio sugerido y el técnico que viene
    // trabajando la orden. En el caso normal solo hay que pulsar Enter.
    if (widget.abierta && !anterior.abierta) _precargar();
  }

  void _precargar() {
    final sugerido = widget.servicio.precioSugerido;
    _precio.text = sugerido > 0 ? '$sugerido' : '';

    final ultimo = ref
        .read(ordenEditorProvider(widget.ordenId))
        .value
        ?.ultimoTecnicoId;
    final tecnicos =
        ref.read(catalogoTecnicosProvider).value ?? const <Tecnico>[];
    _tecnico = ultimo == null
        ? null
        : tecnicos.where((t) => t.id == ultimo).firstOrNull;
  }

  bool get _completo =>
      _tecnico?.id != null && (int.tryParse(_precio.text) ?? 0) > 0;

  Future<void> _agregar() async {
    if (!_completo) return;
    // Se lee antes de ceder el turno: después del `await` el widget puede
    // haberse desmontado y `_tecnico` ya no serviría.
    final tecnicoId = _tecnico!.id!;
    final precio = int.parse(_precio.text);

    widget.alAgregar();
    await ref
        .read(ordenEditorProvider(widget.ordenId).notifier)
        .agregarServicio(
          widget.servicio,
          tecnicoId: tecnicoId,
          precio: precio,
        );
  }

  @override
  Widget build(BuildContext context) {
    final servicio = widget.servicio;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.abierta ? ColoresApp.bgCard : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.abierta ? ColoresApp.borderFocus : ColoresApp.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(servicio),
          if (widget.abierta) _formulario(),
        ],
      ),
    );
  }

  Widget _cabecera(Servicio servicio) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.habilitado ? widget.alTocar : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                widget.abierta
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: ColoresApp.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      servicio.nombre,
                      style: TipografiaApp.cuerpoMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (servicio.descripcion?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        servicio.descripcion!,
                        style: TipografiaApp.caption.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                servicio.precioSugerido == 0
                    ? 'A convenir'
                    : formatearPrecio(servicio.precioSugerido),
                style: servicio.precioSugerido == 0
                    ? TipografiaApp.deshabilitado(TipografiaApp.caption)
                    : TipografiaApp.cuerpoMedium.copyWith(
                        color: ColoresApp.castletonGreen,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Técnico, precio y el botón, en la propia fila. Sin diálogo: es un gesto
  /// de dos campos, y abrir un modal para eso corta el ritmo de armar la orden.
  Widget _formulario() {
    final tecnicos = [
      for (final t in ref.watch(catalogoTecnicosProvider).value ?? <Tecnico>[])
        if (t.activo) t,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: ColoresApp.borderFila, height: 18),
          FilaCampos(
            // El técnico manda: dos tercios para el buscador de nombres, uno
            // para el precio, que son cinco dígitos.
            pesos: const [2, 1],
            hijos: [
              CampoBusqueda<Tecnico>(
                etiqueta: 'Técnico *',
                valor: _tecnico,
                opciones: tecnicos,
                constructorEtiqueta: (t) => t.nombreCompleto,
                constructorDetalle: (t) => t.telefono,
                placeholder: 'Quién lo hace',
                alCambiar: (t) => setState(() => _tecnico = t),
              ),
              CampoTexto(
                etiqueta: 'Precio *',
                controlador: _precio,
                placeholder: '50000',
                soloEnteros: true,
                // Con el técnico ya puesto, el precio es lo único que puede
                // faltar: el foco cae ahí y desde ahí se llega al botón con
                // un Tab (§8).
                autofocus: _tecnico != null,
                // Habilita el botón sin esperar a perder el foco.
                alCambiar: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BotonPrimario(
            etiqueta: 'Agregar a la orden',
            icono: Icons.add,
            alPresionar: _completo ? _agregar : null,
          ),
        ],
      ),
    );
  }
}
