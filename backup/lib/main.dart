import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/database_helper.dart';
import 'services/background_service.dart';
import 'services/recording_service.dart';
import 'models/sleep_record.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/sleep_slogans.dart';  // 导入睡眠slogan数据
import 'dart:io' show Platform;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 锁定竖屏方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 初始化录音服务（用于后台保活）
  await RecordingService.instance.init();
  
  // 只在移动平台(iOS/Android)初始化后台服务
  if (Platform.isIOS || Platform.isAndroid) {
    // 初始化后台服务
    await SleepBackgroundService.initializeService();
  }
  
  // 预加载一个slogan以确保数据已加载
  final _ = SleepSlogans.getRandomSlogan();
  
  // 检查是否有未完成的睡眠记录
  final prefs = await SharedPreferences.getInstance();
  final isRecording = prefs.getBool('is_recording') ?? false;
  final startTimeStr = prefs.getString('start_time');
  
  print('应用启动检查: 睡眠记录状态=$isRecording');
  
  // 如果有未完成的记录，重启后台服务和保活 (仅在移动平台)
  if (isRecording && startTimeStr != null && (Platform.isIOS || Platform.isAndroid)) {
    print('检测到未完成的睡眠记录，恢复后台服务...');
    // 启动后台服务
    await SleepBackgroundService.startService();
    // 确保后台保活
    await RecordingService.instance.startBackgroundRecording();
    print('已恢复睡眠记录，开始于 $startTimeStr');
  } else if (isRecording && startTimeStr == null) {
    // 状态不一致，清理
    print('检测到状态不一致，清理状态数据');
    await prefs.setBool('is_recording', false);
    await prefs.remove('start_time');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '睡眠助手',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade300,
          secondary: Colors.blue.shade200,
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF2D2D2D),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade300,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
