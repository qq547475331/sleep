import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;
import '../services/database_helper.dart';
import '../services/background_service.dart';
import '../services/recording_service.dart';
import '../models/sleep_record.dart';
import 'sleep_recording_screen.dart';
import 'sleep_history_screen.dart';
import 'sleep_analysis_screen.dart';
import 'sleep_statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  DateTime? _startTime;
  bool _isRecording = false;
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadSleepState();
  }

  // 加载保存的睡眠状态
  Future<void> _loadSleepState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRecording = prefs.getBool('is_recording') ?? false;
      final startTimeStr = prefs.getString('start_time');
      
      setState(() {
        _isRecording = isRecording;
        _startTime = startTimeStr != null ? DateTime.parse(startTimeStr) : null;
        _isInitialized = true;
      });
      
      if (_isRecording && _startTime != null) {
        print('恢复之前的睡眠记录会话：开始于 $_startTime');
        
        // 延迟执行以确保界面完全加载
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isRecording && _startTime != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SleepRecordingScreen(
                  onStopRecording: _stopSleepSession,
                  startTime: _startTime!,
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('加载睡眠状态出错: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }
  
  // 保存睡眠状态
  Future<void> _saveSleepState(bool isRecording, DateTime? startTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_recording', isRecording);
      
      if (startTime != null) {
        await prefs.setString('start_time', startTime.toIso8601String());
      } else {
        await prefs.remove('start_time');
      }
      
      print('已保存睡眠状态: isRecording=$isRecording, startTime=$startTime');
    } catch (e) {
      print('保存睡眠状态出错: $e');
    }
  }

  void _startSleepSession() async {
    try {
      final now = DateTime.now();
      setState(() {
        _startTime = now;
        _isRecording = true;
        _errorMessage = null;
      });
      
      // 保存状态到持久存储
      await _saveSleepState(true, now);
      
      // 启动后台保活服务 (仅在移动平台)
      if (Platform.isIOS || Platform.isAndroid) {
        await SleepBackgroundService.startService();
      }
      
      // 确保后台保活启动（用于iOS后台保活）
      await RecordingService.instance.startBackgroundRecording();
      
      print('睡眠记录已开始，后台保活服务已启动');

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => SleepRecordingScreen(
            onStopRecording: _stopSleepSession,
            startTime: now,
          ),
        ),
      );

      if (result == null || !result) {
        print('睡眠记录界面返回，但没有成功完成记录，保持记录状态');
      } else {
        print('睡眠记录界面返回，成功完成记录');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '启动睡眠记录失败: $e';
      });
      
      // 出错时恢复状态
      await _saveSleepState(false, null);
      setState(() {
        _startTime = null;
        _isRecording = false;
      });
      
      // 停止保活服务
      await RecordingService.instance.stopBackgroundRecording();
      
      print('启动睡眠记录失败: $e');
    }
  }

  Future<void> _stopSleepSession(DateTime startTime, DateTime endTime) async {
    try {
      final duration = endTime.difference(startTime);
      
      // 停止后台服务 (仅在移动平台)
      if (Platform.isIOS || Platform.isAndroid) {
        await SleepBackgroundService.stopService();
      }
      
      print('正在结束睡眠记录，关闭后台保活服务');
      
      // 评估睡眠质量 (基于睡眠时长)
      String quality = '良好';
      if (duration.inHours < 5) {
        quality = '较差';
      } else if (duration.inHours < 7) {
        quality = '一般';
      } else if (duration.inHours >= 9) {
        quality = '优秀';
      }
      
      // 创建睡眠记录
      final record = SleepRecord(
        startTime: startTime,
        endTime: endTime,
        duration: duration,
        quality: quality,
        notes: '睡眠记录',
      );

      await _dbHelper.insertSleepRecord(record);
      
      // 清除持久化状态
      await _saveSleepState(false, null);

      if (mounted) {
        setState(() {
          _startTime = null;
          _isRecording = false;
          _errorMessage = null;
        });
      }
      
      print('睡眠记录已完成并保存');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '保存睡眠记录失败: $e';
        });
      }
      print('结束睡眠记录时发生错误: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡梦时光'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1E1E),
              Color(0xFF121212),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSleepSessionCard(),
                      const SizedBox(height: 24),
                      _buildAnalysisButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepSessionCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade800.withOpacity(0.8),
            Colors.blue.shade600.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bedtime,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording ? '正在记录睡眠...' : '开始记录睡眠',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_startTime != null) ...[
              const SizedBox(height: 12),
              Text(
                '开始时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_startTime!)}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              if (_isRecording) ...[
                Text(
                  '已记录: ${DateTime.now().difference(_startTime!).inHours}小时${DateTime.now().difference(_startTime!).inMinutes.remainder(60)}分钟',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            const SizedBox(height: 16),
            const Text(
              '记录您的睡眠时长和质量，帮助更好地了解睡眠模式',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isRecording) ...[
              // 记录中状态显示两个按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // 导航到睡眠记录页面继续记录
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SleepRecordingScreen(
                              onStopRecording: _stopSleepSession,
                              startTime: _startTime!,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '继续记录',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // 直接结束睡眠记录
                        _stopSleepSession(_startTime!, DateTime.now());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '结束记录',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 未记录状态显示单个按钮
              ElevatedButton(
                onPressed: _startSleepSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '开始记录',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 16.0),
            child: Text(
              '数据分析',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildAnalysisButton(
                  icon: Icons.history,
                  label: '睡眠历史',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SleepHistoryScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalysisButton(
                  icon: Icons.analytics,
                  label: '睡眠分析',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SleepAnalysisScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalysisButton(
                  icon: Icons.bar_chart,
                  label: '睡眠统计',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SleepStatisticsScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 