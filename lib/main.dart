import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/layout/layout_principal.dart';
import 'package:inventario_k1/frontend/share2/temas/colores_app.dart';

import 'backend/share/database/locator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Registra todas las dependencias antes de arrancar la app
  setupLocator();
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
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
      home: const LayoutPrincipal(),
    );
  }
}
