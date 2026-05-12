import 'package:get_it/get_it.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../frontend/features/autenticacion/view_model/auth_view_model.dart';
import '../../../frontend/features/autenticacion/view_model/registro_view_model.dart';
import '../../../frontend/features/categorias/view_model/categorias_view_model.dart';
import '../../../frontend/features/clientes/view_model/clientes_view_model.dart';
import '../../../frontend/features/proveedores/view_model/proveedores_view_model.dart';
import '../../../frontend/features/unidades_medida/view_model/unidad_medida_view_model.dart';
import '../../../frontend/features/productos/view_model/productos_view_model.dart';

import '../../features/autenticacion/repositorio/repositorio_auth.dart';
import '../../features/autenticacion/repositorio/repositorio_auth_impl.dart'; // ← FALTABA
import '../../features/categorias/repositorio/repositorio_categorias_impl.dart';
import '../../features/clientes/repositorio/repositorio_cliente.dart';
import '../../features/clientes/repositorio/repositorio_cliente_impl.dart';
import '../../features/productos/repositorio/repositorio_producto_impl.dart';
import '../../features/proveedores/repositorio/repositorio_proveedor_impl.dart';
import '../../features/unidades_medida/repositorio/repositorio_unidades_medida_impl.dart';

import '../servicios/servicio_email.dart';
import '../servicios/servicio_verificacion.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Base de datos
  locator.registerLazySingleton<AppDb>(() => AppDb());

  // Servicios (no dependen de nada)
  locator.registerLazySingleton<ServicioVerificacion>(
    () => ServicioVerificacion(),
  );
  locator.registerLazySingleton<ServicioEmail>(
    () => ServicioEmail.gmail(
      email: 'inventariok12484@gmail.com',
      appPassword: 'cfbr wgiw iiug brhy',
    ),
  );

  // Repositorios (dependen de AppDb)
  locator.registerLazySingleton<RepositorioAuth>(
    () => RepositorioAuthImpl(locator<AppDb>()),
  );
  locator.registerLazySingleton<RepositorioCategoriasImpl>(
    () => RepositorioCategoriasImpl(locator<AppDb>()),
  );
  locator.registerLazySingleton<RepositorioUnidadesMedidaImpl>(
    () => RepositorioUnidadesMedidaImpl(locator<AppDb>()),
  );
  locator.registerLazySingleton<RepositorioProveedoresImpl>(
    () => RepositorioProveedoresImpl(locator<AppDb>()),
  );
  locator.registerLazySingleton<RepositorioProductosImpl>(
    () => RepositorioProductosImpl(locator<AppDb>()),
  );
  locator.registerLazySingleton<RepositorioClientes>(
  () => RepositorioClientesImpl(locator<AppDb>()),
);

  // ViewModels de Auth (dependen de Repositorios + Servicios)
  locator.registerLazySingleton<AuthViewModel>(
    () => AuthViewModel(
      locator<RepositorioAuth>(),
      locator<ServicioEmail>(),
    ),
  );
  locator.registerLazySingleton<RegistroViewModel>(
    () => RegistroViewModel(
      locator<RepositorioAuth>(),
      locator<ServicioEmail>(),
      locator<ServicioVerificacion>(),
    ),
  );

  // ViewModels del resto de la app
  locator.registerLazySingleton<CategoriasViewModel>(
    () => CategoriasViewModel(locator<RepositorioCategoriasImpl>()),
  );
  locator.registerFactory<UnidadesMedidaViewModel>(
    () => UnidadesMedidaViewModel(locator<RepositorioUnidadesMedidaImpl>()),
  );
  locator.registerLazySingleton<ProveedoresViewModel>(
    () => ProveedoresViewModel(locator<RepositorioProveedoresImpl>()),
  );
  locator.registerLazySingleton<ProductosViewModel>(
    () => ProductosViewModel(locator<RepositorioProductosImpl>()),
  );
  locator.registerLazySingleton<ClientesViewModel>(
    () => ClientesViewModel(locator<RepositorioClientes>()),
  );
}
