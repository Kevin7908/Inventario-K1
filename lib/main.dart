import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend/features/configuracion/modelo/clave_configuracion.dart';
import 'core/iva_app.dart';
import 'frontend/features/autenticacion/vista/portal_sesion.dart';
import 'frontend/features/configuracion/provider/configuracion_provider.dart';
import 'frontend/share/temas/colores_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ya no hay `setupLocator()`: la única base de datos y todos los
  // repositorios los construye Riverpod. `get_it` salió del proyecto con la
  // migración de `autenticacion` (`CLAUDE.md` §3).
  //
  // El contenedor se crea a mano —y se le entrega a `UncontrolledProviderScope`
  // en vez de dejar que `ProviderScope` haga el suyo— para poder leer la
  // configuración **antes del primer frame**. Es el mismo contenedor que usará
  // la aplicación, así que la base de datos se abre una sola vez.
  final contenedor = ProviderContainer();
  await _aplicarConfiguracion(contenedor);

  runApp(
    UncontrolledProviderScope(
      container: contenedor,
      child: const MainApp(),
    ),
  );
}

/// Pasa a memoria lo que la app necesita saber antes de pintar nada.
///
/// Hoy es solo la tasa de IVA: es una global que leen funciones puras de
/// `core/iva_app.dart` desde el POS, las cotizaciones y las órdenes, así que
/// tiene que estar puesta antes de que cualquiera de esas pantallas calcule un
/// total. Si no se pudiera leer —base recién creada, disco ocupado—, la app
/// arranca igual con la tasa por defecto: quedarse en negro por no poder leer
/// un porcentaje sería peor que facturar sin IVA un rato.
///
/// El formato de impresión **no** se carga aquí: lo lee cada impresión, como
/// el nombre del taller, para que cambiarlo en Configuración se note sin
/// reiniciar (ver `leerAjustesImpresion`).
Future<void> _aplicarConfiguracion(ProviderContainer contenedor) async {
  try {
    final repositorio = contenedor.read(repositorioConfiguracionProvider);
    final porcentaje = await repositorio.leer(ClaveConfiguracion.ivaPorcentaje);
    configurarIva(double.tryParse(porcentaje.trim()) ?? 0);
  } catch (_) {
    // Sin tasa configurada se factura sin IVA, que es el valor por defecto de
    // la clave y lo que hace hoy el taller.
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InventarioK1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: ColoresApp.goGreen),
        fontFamily: 'GeneralSans',
        scaffoldBackgroundColor: ColoresApp.bgApp,
        useMaterial3: true,
      ),
      home: const PortalSesion(),
    );
  }
}
