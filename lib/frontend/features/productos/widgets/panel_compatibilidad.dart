import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/marca_moto.dart';
import '../../../../backend/features/productos/modelo/compatibilidad.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../../autenticacion/widgets/si_puede.dart';
import '../../motos/provider/marcas_provider.dart';
import '../provider/compatibilidades_provider.dart';

/// A qué motos le sirve este repuesto.
///
/// Sustituye al bloque de texto libre que había: la compatibilidad caía dentro
/// de `productos.descripcion`, así que la pregunta que el mostrador hace todo
/// el día —«¿esta pastilla le sirve a una Pulsar?»— solo se podía responder
/// leyendo párrafos a ojo.
///
/// Es `ConsumerWidget` él mismo y no la ficha entera: agregar una
/// compatibilidad no tiene por qué repintar el resto del detalle
/// (`CLAUDE.md` §3).
///
/// Parámetros:
/// - [productoId]: de qué producto se listan las compatibilidades.
///
/// Ejemplo:
/// ```dart
/// PanelCompatibilidad(productoId: producto.id!)
/// ```
class PanelCompatibilidad extends ConsumerWidget {
  const PanelCompatibilidad({super.key, required this.productoId});

  final int productoId;

  Future<void> _quitar(
    BuildContext context,
    WidgetRef ref,
    Compatibilidad linea,
  ) async {
    final resultado =
        await ref.read(repositorioCompatibilidadesProvider).eliminar(linea.id);
    if (!context.mounted) return;
    if (resultado case Fallo(:final mensaje)) {
      MensajeApp.error(context, mensaje);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLineas = ref.watch(compatibilidadesProvider(productoId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Compatibilidad',
                style: TipografiaApp.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SiPuede(
              permiso: Permiso.productosEditar,
              child: BotonIcono(
                icono: Icons.add,
                tooltip: 'Agregar moto compatible',
                alPresionar: () =>
                    _DialogoCompatibilidad.mostrar(context, productoId),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        asyncLineas.when(
          loading: () => const SizedBox(
            height: 44,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ColoresApp.goGreen,
                ),
              ),
            ),
          ),
          error: (e, _) => AvisoEnLinea(mensaje: 'No se pudo leer: $e'),
          data: (lineas) => lineas.isEmpty
              ? Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: ColoresApp.bgInput,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: ColoresApp.borderFila),
                  ),
                  child: Text(
                    'Sin información de compatibilidad',
                    style: TipografiaApp.caption
                        .copyWith(color: ColoresApp.textDisabled),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final linea in lineas)
                      _ChipCompatibilidad(
                        linea: linea,
                        alQuitar: () => _quitar(context, ref, linea),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Una moto compatible. Las de marca se pintan más fuerte: valen por todas las
/// de esa marca, así que dicen más que una de modelo.
class _ChipCompatibilidad extends StatelessWidget {
  const _ChipCompatibilidad({required this.linea, required this.alQuitar});

  final Compatibilidad linea;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final deMarca = linea.esDeMarca;
    final cilindraje = linea.cilindraje;

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: deMarca ? ColoresApp.greenChipBg : ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: deMarca ? ColoresApp.goGreen : ColoresApp.borderFila,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cilindraje == null
                ? linea.etiqueta
                : '${linea.etiqueta} · $cilindraje cc',
            style: TipografiaApp.caption.copyWith(
              color: deMarca ? ColoresApp.goGreen : ColoresApp.textPrimary,
              fontWeight: deMarca ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 2),
          SiPuede(
            permiso: Permiso.productosEditar,
            child: BotonIcono(
              icono: Icons.close_rounded,
              tooltip: 'Quitar',
              alPresionar: alQuitar,
            ),
          ),
        ],
      ),
    );
  }
}

/// Elegir a qué moto le sirve el repuesto: una marca entera o un modelo.
class _DialogoCompatibilidad extends ConsumerStatefulWidget {
  const _DialogoCompatibilidad({required this.productoId});

  final int productoId;

  static Future<void> mostrar(BuildContext context, int productoId) {
    return showDialog(
      context: context,
      builder: (_) => _DialogoCompatibilidad(productoId: productoId),
    );
  }

  @override
  ConsumerState<_DialogoCompatibilidad> createState() =>
      _DialogoCompatibilidadState();
}

class _DialogoCompatibilidadState
    extends ConsumerState<_DialogoCompatibilidad> {
  MarcaMoto? _marca;
  ModeloMoto? _modelo;
  bool _guardando = false;

  Future<void> _guardar() async {
    final marca = _marca;
    if (marca == null) return;
    setState(() => _guardando = true);

    final repo = ref.read(repositorioCompatibilidadesProvider);
    // Sin modelo elegido, la línea vale por toda la marca. Es la diferencia
    // entre «sirve para cualquier Yamaha» y «solo para la FZ 2.0».
    final resultado = _modelo == null
        ? await repo.agregarMarca(
            productoId: widget.productoId,
            marcaId: marca.id,
          )
        : await repo.agregarModelo(
            productoId: widget.productoId,
            modeloId: _modelo!.id,
          );

    if (!mounted) return;
    switch (resultado) {
      case Exito():
        Navigator.of(context).pop();
        MensajeApp.exito(context, 'Compatibilidad agregada.');
      case Fallo(:final mensaje):
        MensajeApp.error(context, mensaje);
        setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marcas = ref.watch(marcasActivasProvider).value ?? const [];
    final modelos = _marca == null
        ? const <ModeloMoto>[]
        : (ref.watch(modelosMotoProvider(_marca!.id)).value ?? const [])
            .where((m) => m.activo)
            .toList(growable: false);

    return AtajosFormulario(
      alGuardar: _guardando || _marca == null ? null : _guardar,
      alCancelar: _guardando ? null : () => Navigator.of(context).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 460,
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Moto compatible', style: TipografiaApp.heading3),
              const SizedBox(height: 20),
              CampoBusqueda<MarcaMoto>(
                etiqueta: 'Marca *',
                valor: _marca,
                opciones: marcas,
                constructorEtiqueta: (m) => m.nombre,
                placeholder: 'Elegir marca…',
                placeholderBusqueda: 'Buscar marca…',
                alCambiar: (m) => setState(() {
                  _marca = m;
                  // Al cambiar de marca, el modelo de la anterior deja de
                  // tener sentido.
                  _modelo = null;
                }),
              ),
              const SizedBox(height: 16),
              CampoBusqueda<ModeloMoto>(
                etiqueta: 'Modelo',
                valor: _modelo,
                opciones: modelos,
                constructorEtiqueta: (m) => m.nombre,
                constructorDetalle: (m) =>
                    m.cilindraje == null ? null : '${m.cilindraje} cc',
                placeholder: 'Toda la marca',
                placeholderBusqueda: 'Buscar modelo…',
                alCambiar: (m) => setState(() => _modelo = m),
              ),
              const SizedBox(height: 6),
              Text(
                _modelo == null
                    ? 'Sin modelo, el repuesto vale para toda la marca.'
                    : 'Solo para este modelo.',
                style: TipografiaApp.caption,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BotonSecundario(
                    etiqueta: 'Cancelar',
                    alPresionar: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  BotonPrimario(
                    etiqueta: 'Agregar',
                    alPresionar:
                        _guardando || _marca == null ? null : _guardar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
