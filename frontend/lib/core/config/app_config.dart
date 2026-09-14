import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppConfig {
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (url.isNotEmpty && key.isNotEmpty) {
      await Supabase.initialize(url: url, publishableKey: key);
    }
  }
}
