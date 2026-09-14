import 'package:flutter/material.dart';

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
