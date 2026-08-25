import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share2/share2.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../autenticacion/provider/auth_providers.dart';
import '../../autenticacion/vista/usuarios_vista.dart';
import '../../especializacion/vista/especializacion_vista.dart';
import '../../motos/vista/motos_vista.dart';
import '../../unidades_medida/vista/unidad_medida_vista.dart';
import '../widgets/tab_servicios.dart';

/// Pantalla de Configuración: ajustes generales del negocio y catálogos base.
///
/// Consolida, como pestañas, catálogos que antes eran secciones propias del
/// sidebar (Unidades de medida, Especializaciones, Servicios).
///
/// **Usuarios solo aparece para un administrador.** Esconder la pestaña es
/// cortesía, no seguridad: quien llegue a la vista por otro camino encuentra
/// un aviso, y toda escritura la vuelve a comprobar el repositorio contra la
/// base.
class ConfiguracionVista extends ConsumerStatefulWidget {
  const ConfiguracionVista({super.key});

  @override
  ConsumerState<ConfiguracionVista> createState() => _ConfiguracionVistaState();
}

class _ConfiguracionVistaState extends ConsumerState<ConfiguracionVista> {
  int _tabActivo = 0;

  void _cambiarTab(int indice) => setState(() => _tabActivo = indice);

  @override
  Widget build(BuildContext context) {
    // Se pregunta por el permiso, no por el rol: el rol solo decide con qué
    // permisos nace una cuenta, y de ahí en adelante manda `usuario_permisos`.
    final esAdmin = ref.watch(puedeProvider(Permiso.usuariosAdministrar));

    // Al perder el rol con la pestaña de Usuarios abierta, el índice apuntaría
    // a una pestaña que ya no existe.
    final tabActivo = _tabActivo.clamp(0, esAdmin ? 5 : 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoConCuenta(
            titulo: 'Configuración',
            subtitulo: 'Ajustes generales del negocio y catálogos base',
          ),
          const SizedBox(height: 20),
          BarraTabsSecundaria(
            indiceActivo: tabActivo,
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
              TabSecundariaDato(
                etiqueta: 'Motos',
                alPresionar: () => _cambiarTab(4),
              ),
              if (esAdmin)
                TabSecundariaDato(
                  etiqueta: 'Usuarios',
                  alPresionar: () => _cambiarTab(5),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: IndexedStack(
              index: tabActivo,
              children: [
                const _TabGeneral(),
                const UnidadesMedidaVista(),
                const EspecializacionesVista(),
                const TabServicios(),
                const MotosVista(),
                if (esAdmin) const UsuariosVista(),
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
  final _nombreController = TextEditingController(text: 'Taller Inventario K1');
  final _nitController = TextEditingController(text: '901.555.222-8');
  final _telefonoController = TextEditingController(text: '602 555 7788');
  final _direccionController =
      TextEditingController(text: 'Cra. 8 #23-45, Cali');
  final _monedaController =
      TextEditingController(text: 'Peso colombiano (COP \$)');
  final _ivaController = TextEditingController(text: '19%');

  @override
  void dispose() {
    _nombreController.dispose();
    _nitController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _monedaController.dispose();
    _ivaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: PanelSeccion(
          titulo: 'Datos del negocio',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Fila(
                izquierda: CampoTexto(
                  etiqueta: 'Nombre del taller',
                  controlador: _nombreController,
                ),
                derecha: CampoTexto(
                  etiqueta: 'NIT',
                  controlador: _nitController,
                  monoespaciado: true,
                ),
              ),
              const SizedBox(height: 16),
              _Fila(
                izquierda: CampoTexto(
                  etiqueta: 'Teléfono',
                  controlador: _telefonoController,
                ),
                derecha: CampoTexto(
                  etiqueta: 'Dirección',
                  controlador: _direccionController,
                ),
              ),
              const SizedBox(height: 16),
              _Fila(
                izquierda: CampoTexto(
                  etiqueta: 'Moneda',
                  controlador: _monedaController,
                ),
                derecha: CampoTexto(
                  etiqueta: 'IVA por defecto',
                  controlador: _ivaController,
                ),
              ),
              const SizedBox(height: 22),
              BotonPrimario(
                etiqueta: 'Guardar cambios',
                icono: Icons.check,
                alPresionar: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dos campos lado a lado, replicando la grilla de 2 columnas del mockup.
class _Fila extends StatelessWidget {
  const _Fila({required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: izquierda),
        const SizedBox(width: 16),
        Expanded(child: derecha),
      ],
    );
  }
}
