// 모션 인식 시연·수동 E2E 진입점 (카메라 → WS → Supabase).
//
// main.dart/app.dart는 전혀 건드리지 않는다 — 대신 이 파일을 별도 진입점으로
// 지정해서 실행한다:
//
//   flutter run -d chrome -t lib/main_movement_debug.dart
//
// 토큰을 손으로 붙여넣지 않는다. `.env`의 DEMO_EMAIL/DEMO_PASSWORD로 자동
// 로그인하고, WS 연결 시점에 현재 세션의 access token을 읽는다. 세션은
// 브라우저에 저장되고 supabase_flutter가 만료 전에 자동 갱신하므로 1시간이
// 지나도 새로고침만 하면 된다. 연결이 4003으로 끊기면 토큰이 아니라 모션
// 동의/수집이 OFF인 것이다(PUT /api/v1/family/motion/consent, /collection).
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'design_system/theme/app_theme.dart';
import 'design_system/theme/app_scroll_behavior.dart';
import 'features/movement/browser_camera_frame_source.dart';
import 'features/movement/browser_live_transport.dart';
import 'features/movement/movement_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  await _ensureDemoSession();
  runApp(const _MovementDebugApp());
}

/// 저장된 세션이 없을 때만 .env의 시연 계정으로 로그인한다.
Future<void> _ensureDemoSession() async {
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) return;
  final email = dotenv.env['DEMO_EMAIL']?.trim() ?? '';
  final password = dotenv.env['DEMO_PASSWORD'] ?? '';
  if (email.isEmpty || password.isEmpty) {
    throw StateError('frontend/.env에 DEMO_EMAIL, DEMO_PASSWORD를 채워야 합니다.');
  }
  await auth.signInWithPassword(email: email, password: password);
}

class _MovementDebugApp extends StatelessWidget {
  const _MovementDebugApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movement Debug',
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      home: MovementScreen(
        // 빌드 시점이 아니라 연결 직전에 평가되므로 항상 갱신된 토큰이 들어간다.
        backendWsUri: AppConfig.movementLiveStreamUri.replace(
          queryParameters: {
            'token': Supabase.instance.client.auth.currentSession!.accessToken,
          },
        ),
        cameraFrameSourceFactory: BrowserCameraFrameSource.new,
        transportFactory: BrowserLiveTransport.connect,
      ),
    );
  }
}
