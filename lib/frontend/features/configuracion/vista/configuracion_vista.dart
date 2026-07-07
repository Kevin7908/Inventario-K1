import 'package:flutter/material.dart';

import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../../especializacion/vista/especializacion_vista.dart';
import '../../unidades_medida/vista/unidad_medida_vista.dart';

/// Pantalla de Configuración: ajustes generales del negocio y catálogos base.
///
/// Consolida, como pestañas, catálogos que antes eran secciones propias del
/// sidebar (Unidades de medida, Especializaciones).
class ConfiguracionVista extends StatefulWidget {
  const ConfiguracionVista({super.key});

  @override
  State<ConfiguracionVista> createState() => _ConfiguracionVistaState();
}

class _ConfiguracionVistaState extends State<ConfiguracionVista> {
  int _tabActivo = 0;

  void _cambiarTab(int indice) => setState(() => _tabActivo = indice);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoConCuenta(
            titulo: 'Configuración',
            subtitulo: 'Ajustes generales del negocio y catálogos base',
          ),
          const SizedBox(height: 24),
          BarraTabsSecundaria(
            indiceActivo: _tabActivo,
            tabs: [
              TabSecundariaDato(
                etiqueta: 'General',
                alPresionar: () => _cambiarTab(0),
              ),
              TabSecundariaDato(
                etiqueta: 'Unidades de medida',
                alPresionar: () => _cambiarTab(1),
              ),
              TabSecundariaDato(
                etiqueta: 'Especializaciones',
                alPresionar: () => _cambiarTab(2),
              ),
              TabSecundariaDato(
                etiqueta: 'Servicios',
                alPresionar: () => _cambiarTab(3),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: IndexedStack(
              index: _tabActivo,
              children: const [
                _TabGeneral(),
                UnidadesMedidaVista(),
                EspecializacionesVista(),
                _TabServiciosPendiente(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabGeneral extends StatefulWidget {
  const _TabGeneral();

  @override
  State<_TabGeneral> createState() => _TabGeneralState();
}

class _TabGeneralState extends State<_TabGeneral> {
  final _nombreController =
      TextEditingController(text: 'Taller Inventario K1');
  final _nitController = TextEditingController(text: '901.555.222-8');
  final _telefonoController = TextEditingController(text: '602 555 7788');
  final _direccionController =
      TextEditingController(text: 'Cra. 8 #23-45, Cali');
  final _ivaController = TextEditingController(text: '19');

  @override
  void dispose() {
    _nombreController.dispose();
    _nitController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _ivaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PanelSeccion(
        titulo: 'Datos del negocio',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CampoTexto(
                    etiqueta: 'Nombre del taller',
                    controlador: _nombreController,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: CampoTexto(
                    etiqueta: 'NIT',
                    controlador: _nitController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CampoTexto(
                    etiqueta: 'Teléfono',
                    controlador: _telefonoController,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: CampoTexto(
                    etiqueta: 'Dirección',
                    controlador: _direccionController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CampoTexto(
                    etiqueta: 'IVA por defecto (%)',
                    controlador: _ivaController,
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 24),
            BotonPrimario(
              etiqueta: 'Guardar cambios',
              icono: Icons.check,
              alPresionar: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _TabServiciosPendiente extends StatelessWidget {
  const _TabServiciosPendiente();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.construction_rounded,
            size: 48,
            color: ColoresApp.textSecondary,
          ),
          const SizedBox(height: 16),
          Text('Servicios', style: TipografiaApp.heading2),
          const SizedBox(height: 8),
          Text('Catálogo en construcción', style: TipografiaApp.caption),
        ],
      ),
    );
  }
}
