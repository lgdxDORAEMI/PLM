import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'app.dart';
import 'routing/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  ActiveRoleStore.instance.restoreFor(AuthSessionStore.instance);
  runApp(const PLMApp());
}
