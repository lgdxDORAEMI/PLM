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
    return base.replace(
      scheme: wsScheme,
      path: '/api/v1/movement/live/stream',
      queryParameters: {
        'token':
            'eyJhbGciOiJFUzI1NiIsImtpZCI6ImFiZjQyODYzLWM2MzAtNDA1OS05ODk5LWYyYTU5MjgwZDFhNiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL21la3Fianp0bXNiZWJ0cXlidHVjLnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiI1ZTQ1M2IwMy1mMThjLTQ5MDItOWQyZi02ZWVhNTBkOTUzZmQiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzg5NTQ3NTA2LCJpYXQiOjE3ODk1NDM5MDYsImVtYWlsIjoidGVzdDFAZ21haWwuY29tIiwicGhvbmUiOiIiLCJhcHBfbWV0YWRhdGEiOnsicHJvdmlkZXIiOiJlbWFpbCIsInByb3ZpZGVycyI6WyJlbWFpbCJdfSwidXNlcl9tZXRhZGF0YSI6eyJlbWFpbF92ZXJpZmllZCI6dHJ1ZX0sInJvbGUiOiJhdXRoZW50aWNhdGVkIiwiYWFsIjoiYWFsMSIsImFtciI6W3sibWV0aG9kIjoicGFzc3dvcmQiLCJ0aW1lc3RhbXAiOjE3ODk1NDM5MDZ9XSwic2Vzc2lvbl9pZCI6ImE5MDE4MzRhLWI3NTQtNGRiYS04YjMxLTFkMzVkOTM1MDc3ZCIsImlzX2Fub255bW91cyI6ZmFsc2V9.-JGMSg07RZ8C3n3LUOGUOemw1r2kEIKpnnElLf9G7R2MJCJmy9fwUM0qFy3G01H-zNmkQ8lqxKuJDImZzHdfgw',
      },
    );
    //// TODO: 테스트용 임시 코드 — queryParameters는 확인 끝나면 삭제
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
