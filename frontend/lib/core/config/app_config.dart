import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppConfig {
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  /// `WS /api/v1/movement/live/stream`(B-1/B-3) 접속 주소. backendUrl의
  /// http(s) 스킴을 ws(s)로 바꿔서 파생한다.
  static Uri get movementLiveStreamUri {
    final base = Uri.parse(backendUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: wsScheme, path: '/api/v1/movement/live/stream');
  }

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (url.isNotEmpty && key.isNotEmpty) {
      await Supabase.initialize(url: url, publishableKey: key);
    }
  }
}
