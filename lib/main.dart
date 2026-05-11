import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/main_layout.dart'; // 👈 방금 만든 전체 틀

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DHM ERP',
      debugShowCheckedModeBanner: false, // 우측 상단 DEBUG 띠 제거
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF001F3F)),
        useMaterial3: true,
      ),
      home: const MainLayout(), // 시작 화면을 사이드바 레이아웃으로!
    );
  }
}