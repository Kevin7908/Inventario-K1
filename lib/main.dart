import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'frontend/features/autenticacion/vista/portal_sesion.dart';
import 'frontend/share2/temas/colores_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Ya no hay `setupLocator()`: la única base de datos y todos los
  // repositorios los construye Riverpod. `get_it` salió del proyecto con la
  // migración de `autenticacion` (`CLAUDE.md` §3).
  runApp(const ProviderScope(child: MainApp()));
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
