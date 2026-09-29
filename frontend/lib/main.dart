import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'app.dart';
import 'features/entry/services/app_session_restorer.dart';
import 'routing/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  if (AppConfig.hasSupabaseConfig) {
    await const AppSessionRestorer().restore();
  }
  ActiveRoleStore.instance.restoreFor(AuthSessionStore.instance);
  runApp(const PLMApp());
}
