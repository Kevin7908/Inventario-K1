import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_moto_impl.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../view_model/motos_view_model.dart';

final repositorioMotosProvider = Provider<RepositorioMotos>(
  name: 'repositorioMotosProvider',
  (ref) => RepositorioMotosImpl(ref.watch(appDatabaseProvider)),
);

final motosProvider = ChangeNotifierProvider<MotosViewModel>(
  name: 'motosProvider',
  (ref) => MotosViewModel(ref.watch(repositorioMotosProvider)),
);

/// Lista de motos filtradas por clienteId para el picker de nueva orden.
final motosPorClienteProvider = Provider.family<List<Moto>, int>(
  name: 'motosPorClienteProvider',
  (ref, clienteId) {
    final vm = ref.watch(motosProvider);
    return vm.motos
        .where((m) => m.clienteId == clienteId && m.activo)
        .toList(growable: false);
  },
);