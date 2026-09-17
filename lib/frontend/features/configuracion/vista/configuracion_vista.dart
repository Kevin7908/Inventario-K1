import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../layout/encabezado_con_cuenta.dart';
import '../../../share/share.dart';
import '../../../../backend/share/dominio/permiso.dart';
import '../../autenticacion/provider/auth_providers.dart';
import '../../autenticacion/vista/usuarios_vista.dart';
import '../../especializacion/vista/especializacion_vista.dart';
import '../../motos/vista/motos_vista.dart';
import '../../unidades_medida/vista/unidad_medida_vista.dart';
import '../widgets/tab_general.dart';
import '../widgets/tab_marcas.dart';
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
    final tabActivo = _tabActivo.clamp(0, esAdmin ? 6 : 5);

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
              TabSecundariaDato(
                etiqueta: 'Marcas y modelos',
                alPresionar: () => _cambiarTab(5),
              ),
              if (esAdmin)
                TabSecundariaDato(
                  etiqueta: 'Usuarios',
                  alPresionar: () => _cambiarTab(6),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: IndexedStack(
              index: tabActivo,
              children: [
                const TabGeneral(),
                const UnidadesMedidaVista(),
                const EspecializacionesVista(),
                const TabServicios(),
                const MotosVista(),
                const TabMarcas(),
                if (esAdmin) const UsuariosVista(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
