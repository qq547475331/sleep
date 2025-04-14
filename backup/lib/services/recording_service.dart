import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audio_session/audio_session.dart';

class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  static RecordingService get instance => _instance;
  
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _dummyTimer;
  String? _currentRecordingPath;
  bool _isRecorderInitialized = false;
  
  RecordingService._internal();
  
  /// 初始化录音服务
  Future<void> init() async {
    try {
      // 配置音频会话
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.measurement,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      ));
      
      print('录音服务初始化成功（仅用于后台保活）');
    } catch (e) {
      print('录音服务初始化失败: $e');
    }
  }
  
  /// 开始后台录音 (用于保持应用活跃，但不实际保存录音)
  Future<bool> startBackgroundRecording() async {
    if (_isRecording) return true;
    
    try {
      // 检查麦克风权限
      if (!await _audioRecorder.hasPermission()) {
        print('没有麦克风权限，无法使用后台保活');
        return false;
      }
      
      // 获取临时目录用于创建临时文件
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/dummy_recording_$timestamp.m4a';
      
      // 配置录音参数 - 使用最低质量设置减少资源占用
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // AAC格式
          bitRate: 8000,    // 最低比特率
          sampleRate: 8000, // 最低采样率
        ),
        path: _currentRecordingPath!,
      );
      
      _isRecording = true;
      
      // 启动定时器，每隔一段时间重启录音以确保最小化存储使用
      _startDummyTimer();
      
      print('后台保活服务已启动');
      return true;
    } catch (e) {
      print('启动后台保活失败: $e');
      return false;
    }
  }
  
  /// 停止后台录音
  Future<void> stopBackgroundRecording() async {
    if (!_isRecording) return;
    
    try {
      _dummyTimer?.cancel();
      _dummyTimer = null;
      
      await _audioRecorder.stop();
      _isRecording = false;
      
      // 清理临时录音文件
      await _deleteAllRecordings();
      
      print('后台保活服务已停止');
    } catch (e) {
      print('停止后台保活失败: $e');
    }
  }
  
  /// 定期重启录音，确保文件最小化
  void _startDummyTimer() {
    _dummyTimer?.cancel();
    
    // 每2分钟重启一次录音，保持文件最小
    _dummyTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      await _restartRecording();
    });
  }
  
  /// 重启录音以最小化文件大小
  Future<void> _restartRecording() async {
    if (!_isRecording) return;
    
    try {
      // 停止当前录音
      await _audioRecorder.stop();
      
      // 删除旧文件
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // 开始新的录音
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/dummy_recording_$timestamp.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 8000,
          sampleRate: 8000,
        ),
        path: _currentRecordingPath!,
      );
      
      print('后台保活服务已重启');
    } catch (e) {
      print('重启后台保活失败: $e');
      _isRecording = false;
    }
  }
  
  /// 删除所有临时录音文件
  Future<void> _deleteAllRecordings() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      final files = await dir.list().toList();
      
      for (var file in files) {
        if (file is File && file.path.contains('dummy_recording_')) {
          await file.delete();
        }
      }
      
      print('已清理所有临时文件');
    } catch (e) {
      print('清理临时文件失败: $e');
    }
  }
  
  Future<void> _initRecorder() async {
    _isRecorderInitialized = true;
  }
  
  bool get isRecording => _isRecording;
} 