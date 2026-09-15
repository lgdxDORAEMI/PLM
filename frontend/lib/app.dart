import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'features/movement/movement_screen.dart';

class PLMApp extends StatelessWidget {
  const PLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PLM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('PLM 실행 확인')),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Flutter가 정상적으로 실행되었습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('PLM 앱 초기화 완료'),
                  const SizedBox(height: 20),
                  // TODO(B-4): 실제 앱 네비게이션이 생기면 이 임시 버튼은 그 안으로
                  // 옮기고 여기서는 제거한다. 지금은 다른 화면이 하나도 없어서
                  // (features/* 전부 미구현) 모션 데모에 접근할 다른 경로가 없다.
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MovementScreen(backendWsUri: AppConfig.movementLiveStreamUri),
                        ),
                      );
                    },
                    child: const Text('모션 인식 데모 보기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
