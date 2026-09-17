// 모션 인식 WS→Supabase 수동 E2E 확인 전용 진입점.
//
// main.dart/app.dart는 전혀 건드리지 않는다 — 대신 이 파일을 별도 진입점으로
// 지정해서 실행한다:
//
//   flutter run -d chrome -t lib/main_movement_debug.dart
//
// 그래서 다른 사람이 평소처럼 `flutter run`(= main.dart)을 실행하는 데는
// 아무 영향이 없다. 확인이 끝나면 이 파일만 지우면 된다(다른 파일 되돌릴 것 없음).
import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'design_system/theme/app_theme.dart';
import 'features/movement/browser_camera_frame_source.dart';
import 'features/movement/browser_live_transport.dart';
import 'features/movement/movement_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  runApp(const _MovementDebugApp());
}

class _MovementDebugApp extends StatelessWidget {
  const _MovementDebugApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movement Debug',
      theme: AppTheme.light,
      home: MovementScreen(
        // TODO: PowerShell로 발급받은 access_token을 아래 자리에 붙여넣고 실행할 것.
        backendWsUri: AppConfig.movementLiveStreamUri.replace(
          queryParameters: {
            'token':
                'paste token here', // TODO: PowerShell로 발급받은 access_token을 붙여넣을 것.
          },
        ),
        cameraFrameSourceFactory: BrowserCameraFrameSource.new,
        transportFactory: BrowserLiveTransport.connect,
      ),
    );
  }
}
