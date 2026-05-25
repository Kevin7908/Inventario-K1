import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventario_k1/frontend/share/nav/navegacion.dart';
import 'package:inventario_k1/frontend/share/temas/colores_app.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: ColoresApp.primary),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: ColoresApp.bgContent,
        useMaterial3: true,
      ),
      home: const Navegacion(),
    );
  }
}
