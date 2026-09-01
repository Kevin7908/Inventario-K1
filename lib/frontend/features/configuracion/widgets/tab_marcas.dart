import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/marca_moto.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../../motos/provider/marcas_provider.dart';
import '../../motos/widgets/dialogo_marca_moto.dart';
import '../../motos/widgets/dialogo_modelo_moto.dart';

/// Pestaña «Marcas y modelos» de Configuración.
///
/// Dos paneles: las marcas a la izquierda y los modelos de la seleccionada a
/// la derecha. Es el mismo gesto que el panel de categorías del catálogo, y
/// por la misma razón: un modelo no se entiende sin su marca.
///
/// **No hay botón de eliminar.** Una marca la referencian motos y
/// compatibilidades de producto, así que se da de baja (`REGLAS_BD.md` §1.4);
/// borrarla rompería el historial de taller de esas motos.
class TabMarcas extends ConsumerStatefulWidget {
  const TabMarcas({super.key});

  @override
  ConsumerState<TabMarcas> createState() => _TabMarcasState();
}

class _TabMarcasState extends ConsumerState<TabMarcas> {
  int? _marcaSeleccionada;

  Future<void> _alternarMarca(MarcaMoto marca) async {
    final resultado = await ref
        .read(repositorioMarcasMotoProvider)
        .cambiarEstadoMarca(marca.id, activa: !marca.activo);
    if (!mounted) return;
    switch (resultado) {
      case Exito():
        MensajeApp.exito(
          context,
          marca.activo ? 'Marca dada de baja.' : 'Marca reactivada.',
        );
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
    }
  }

  Future<void> _alternarModelo(ModeloMoto modelo) async {
    final resultado = await ref
        .read(repositorioMarcasMotoProvider)
        .cambiarEstadoModelo(modelo.id, activo: !modelo.activo);
    if (!mounted) return;
    switch (resultado) {
      case Exito():
        MensajeApp.exito(
          context,
          modelo.activo ? 'Modelo dado de baja.' : 'Modelo reactivado.',
        );
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMarcas = ref.watch(marcasMotoProvider);

    return asyncMarcas.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ColoresApp.goGreen),
      ),
      error: (e, _) => Center(
        child: AvisoEnLinea(mensaje: 'No se pudo leer el catálogo: $e'),
      ),
      data: (marcas) {
        // La selección se resuelve aquí y no en el estado: si la marca elegida
        // desaparece, el panel de modelos cae solo en la primera en vez de
        // quedarse apuntando a un id que ya no está.
        final seleccionada = marcas.isEmpty
            ? null
            : marcas.firstWhere(
                (m) => m.id == _marcaSeleccionada,
                orElse: () => marcas.first,
              );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 320,
              child: _PanelMarcas(
                marcas: marcas,
                seleccionada: seleccionada,
                alSeleccionar: (m) =>
                    setState(() => _marcaSeleccionada = m.id),
                alEditar: (m) => DialogoMarcaMoto.mostrar(context, marca: m),
                alAlternar: _alternarMarca,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: seleccionada == null
                  ? const EstadoVacio(
                      icono: Icons.two_wheeler_outlined,
                      titulo: 'Todavía no hay marcas',
                      pista: 'Crea la primera para poder registrar motos.',
                    )
                  : _PanelModelos(
                      marca: seleccionada,
                      alAlternar: _alternarModelo,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// La columna de marcas, con su alta y su baja lógica.
class _PanelMarcas extends StatelessWidget {
  const _PanelMarcas({
    required this.marcas,
    required this.seleccionada,
    required this.alSeleccionar,
    required this.alEditar,
    required this.alAlternar,
  });

  final List<MarcaMoto> marcas;
  final MarcaMoto? seleccionada;
  final ValueChanged<MarcaMoto> alSeleccionar;
  final ValueChanged<MarcaMoto> alEditar;
  final ValueChanged<MarcaMoto> alAlternar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Marcas', style: TipografiaApp.heading3),
            ),
            SiPuede(
              permiso: Permiso.configuracionEditar,
              child: BotonIcono(
                icono: Icons.add,
                tooltip: 'Nueva marca',
                alPresionar: () => DialogoMarcaMoto.mostrar(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: marcas.length,
            // Todas las filas miden igual: con `itemExtent` Flutter se salta
            // el cálculo de layout de cada una (`CLAUDE.md` §2).
            //
            // 64 y no 60: la fila lleva dos líneas de texto —20,25 px de
            // `cuerpoMedium` y 17,5 de `caption`— más 8 de separación abajo y
            // 16 de relleno arriba y abajo. Con 60 quedaban 36 para 37,75 y
            // Flutter pintaba la franja amarilla del desborde en cada marca.
            itemExtent: 64,
            itemBuilder: (context, i) {
              final marca = marcas[i];
              return _FilaMarca(
                marca: marca,
                seleccionada: marca.id == seleccionada?.id,
                alSeleccionar: () => alSeleccionar(marca),
                alEditar: () => alEditar(marca),
                alAlternar: () => alAlternar(marca),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilaMarca extends StatelessWidget {
  const _FilaMarca({
    required this.marca,
    required this.seleccionada,
    required this.alSeleccionar,
    required this.alEditar,
    required this.alAlternar,
  });

  final MarcaMoto marca;
  final bool seleccionada;
  final VoidCallback alSeleccionar;
  final VoidCallback alEditar;
  final VoidCallback alAlternar;

  @override
  Widget build(BuildContext context) {
    final modelos = marca.modelos == 1 ? '1 modelo' : '${marca.modelos} modelos';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: seleccionada ? ColoresApp.greenChipBg : ColoresApp.bgCard,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: alSeleccionar,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        marca.nombre,
                        style: TipografiaApp.cuerpoMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        marca.activo ? modelos : '$modelos · dada de baja',
                        style: TipografiaApp.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SiPuede(
                  permiso: Permiso.configuracionEditar,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BotonIcono(
                        icono: Icons.edit_outlined,
                        tooltip: 'Renombrar',
                        alPresionar: alEditar,
                      ),
                      BotonIcono(
                        icono: marca.activo
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        tooltip: marca.activo
                            ? 'Dar de baja'
                            : 'Reactivar',
                        alPresionar: alAlternar,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Los modelos de la marca elegida. Es `Consumer` él mismo para que cambiar de
/// marca no reconstruya la columna de la izquierda (`CLAUDE.md` §3).
class _PanelModelos extends ConsumerWidget {
  const _PanelModelos({required this.marca, required this.alAlternar});

  final MarcaMoto marca;
  final ValueChanged<ModeloMoto> alAlternar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncModelos = ref.watch(modelosMotoProvider(marca.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Modelos de ${marca.nombre}',
                style: TipografiaApp.heading3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SiPuede(
              permiso: Permiso.configuracionEditar,
              child: BotonPrimario(
                etiqueta: 'Nuevo modelo',
                icono: Icons.add,
                alPresionar: () =>
                    DialogoModeloMoto.mostrar(context, marca: marca),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: asyncModelos.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: ColoresApp.goGreen),
            ),
            error: (e, _) => AvisoEnLinea(mensaje: 'No se pudo leer: $e'),
            data: (modelos) => modelos.isEmpty
                ? const EstadoVacio(
                    icono: Icons.list_alt_outlined,
                    titulo: 'Esta marca no tiene modelos',
                    pista: 'Se pueden registrar motos sin modelo, pero con el '
                        'modelo puesto se sabe qué repuestos le sirven.',
                  )
                : TablaGenerica<ModeloMoto>(
                    items: modelos,
                    columnas: [
                      ColumnaTabla(
                        titulo: 'Modelo',
                        flex: 3,
                        constructor: (m) => Text(
                          m.nombre,
                          style: TipografiaApp.cuerpoMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ColumnaTabla(
                        titulo: 'Cilindraje',
                        constructor: (m) => Text(
                          m.cilindraje == null ? '—' : '${m.cilindraje} cc',
                          style: TipografiaApp.cuerpo,
                        ),
                      ),
                      ColumnaTabla(
                        titulo: 'Estado',
                        constructor: (m) => IndicadorEstado(
                          etiqueta: m.activo ? 'Activo' : 'De baja',
                          color: m.activo
                              ? ColoresApp.statusSuccess
                              : ColoresApp.statusNeutral,
                          colorFondo: m.activo
                              ? ColoresApp.statusSuccessBg
                              : ColoresApp.statusNeutralBg,
                        ),
                      ),
                      ColumnaTabla(
                        titulo: '',
                        ancho: 96,
                        alineacion: Alignment.centerRight,
                        constructor: (m) => SiPuede(
                          permiso: Permiso.configuracionEditar,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BotonIcono(
                                icono: Icons.edit_outlined,
                                tooltip: 'Editar',
                                alPresionar: () => DialogoModeloMoto.mostrar(
                                  context,
                                  marca: marca,
                                  modelo: m,
                                ),
                              ),
                              BotonIcono(
                                icono: m.activo
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                tooltip:
                                    m.activo ? 'Dar de baja' : 'Reactivar',
                                alPresionar: () => alAlternar(m),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
