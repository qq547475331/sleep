import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recording_service.dart';

class SleepBackgroundService {
  static Future<void> initializeService() async {
    // 初始化录音服务
    await RecordingService.instance.init();

    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sleep_app_channel',
      'Sleep App Background Service',
      description: '睡眠记录正在进行中',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'sleep_app_channel',
        initialNotificationTitle: '睡眠助手',
        initialNotificationContent: '正在记录睡眠...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    print('后台服务初始化完成');
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // 确保后台保活继续进行
    final recordingService = RecordingService.instance;
    if (!recordingService.isRecording) {
      await recordingService.startBackgroundRecording();
    }

    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // 获取SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // 启动后台保活
    final recordingService = RecordingService.instance;
    await recordingService.startBackgroundRecording();

    service.on('stopService').listen((event) async {
      // 停止保活
      await recordingService.stopBackgroundRecording();
      service.stopSelf();
    });

    // 定期检查状态，间隔时间较长以节省资源
    Timer.periodic(const Duration(minutes: 3), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // 更新通知
          service.setForegroundNotificationInfo(
            title: '睡眠助手',
            content: '正在记录睡眠...',
          );
        }
      }

      // 检查录音状态，如果没在录音就重新开始（额外保障）
      if (!recordingService.isRecording) {
        await recordingService.startBackgroundRecording();
        print('检测到保活服务已停止，重新启动保活');
      }

      // 发送记录状态到主应用
      service.invoke('update', {
        'isRunning': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    print('后台服务已启动');
  }

  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
      print('后台服务开始运行');
    } else {
      print('后台服务已在运行中');
    }
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');

    // 确保保活停止
    await RecordingService.instance.stopBackgroundRecording();

    print('后台服务已停止');
  }
}
