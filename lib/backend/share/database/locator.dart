import 'package:get_it/get_it.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';

import '../../../frontend/features/autenticacion/view_model/auth_view_model.dart';
import '../../../frontend/features/autenticacion/view_model/registro_view_model.dart';
import '../../features/autenticacion/repositorio/repositorio_auth.dart';
import '../../features/autenticacion/repositorio/repositorio_auth_impl.dart';

import '../servicios/servicio_email.dart';
import '../servicios/servicio_verificacion.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Base de datos
  locator.registerLazySingleton<AppDb>(() => AppDb());

  // Servicios
  locator.registerLazySingleton<ServicioVerificacion>(
    () => ServicioVerificacion(),
  );
  locator.registerLazySingleton<ServicioEmail>(
    () => ServicioEmail.gmail(
      email: 'inventariok12484@gmail.com',
      appPassword: 'cfbr wgiw iiug brhy',
    ),
  );

  // Repositorios
  locator.registerLazySingleton<RepositorioAuth>(
    () => RepositorioAuthImpl(locator<AppDb>()),
  );
  // Productos, categorías, unidades de medida y proveedores ya no pasan por
  // aquí: sus repositorios los construye Riverpod (`repositorioXProvider`).

  // ViewModels de Auth
  locator.registerLazySingleton<AuthViewModel>(
    () => AuthViewModel(locator<RepositorioAuth>(), locator<ServicioEmail>()),
  );
  locator.registerLazySingleton<RegistroViewModel>(
    () => RegistroViewModel(
      locator<RepositorioAuth>(),
      locator<ServicioEmail>(),
      locator<ServicioVerificacion>(),
    ),
  );
}
