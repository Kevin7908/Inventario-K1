import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../backend/features/clientes/repositorio/repositorio_cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../view_model/clientes_view_model.dart';

final repositorioClientesProvider = Provider<RepositorioClientes>(
  name: 'repositorioClientesProvider',
  (ref) => RepositorioClientesImpl(ref.watch(appDatabaseProvider)),
);

final clientesProvider = ChangeNotifierProvider<ClientesViewModel>(
  name: 'clientesProvider',
  (ref) => ClientesViewModel(ref.watch(repositorioClientesProvider)),
);