import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import 'browser_camera_frame_source.dart';
import 'browser_live_transport.dart';
import 'movement_screen.dart';

/// WS→Supabase 연동을 수동으로 확인하기 위한 임시 디버그 진입점.
/// 실제 네비게이션(ProductMovementScreen)과는 완전히 분리된 독립 라우트다.
/// 확인이 끝나면 이 파일과 app_router.dart의 '/movement-debug' 분기를 함께 삭제할 것.
class MovementDebugScreen extends StatelessWidget {
  const MovementDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('모션 인식 디버그(임시)')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MovementScreen(
                backendWsUri: AppConfig.movementLiveStreamUri,
                cameraFrameSourceFactory: BrowserCameraFrameSource.new,
                transportFactory: BrowserLiveTransport.connect,
              ),
            ),
          ),
          child: const Text('모션 인식 데모 열기'),
        ),
      ),
    );
  }
}
