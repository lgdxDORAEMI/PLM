import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'app.dart';
import 'routing/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  if (AppConfig.hasSupabaseConfig) {
    AuthSessionStore.instance.update(
      accountId: null,
      roles: {},
      husbandLinked: false,
    );
  }
  ActiveRoleStore.instance.restoreFor(AuthSessionStore.instance);
  runApp(const PLMApp());
}
