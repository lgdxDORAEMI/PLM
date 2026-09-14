import 'package:flutter/material.dart';

class PLMApp extends StatelessWidget {
  const PLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PLM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('PLM'))),
    );
  }
}
