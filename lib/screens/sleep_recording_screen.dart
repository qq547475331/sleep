import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/recording_service.dart';
import '../data/sleep_slogans.dart';

class SleepRecordingScreen extends StatefulWidget {
  final Function(DateTime, DateTime) onStopRecording;
  final DateTime startTime;

  const SleepRecordingScreen({
    super.key,
    required this.onStopRecording,
    required this.startTime,
  });

  @override
  State<SleepRecordingScreen> createState() => _SleepRecordingScreenState();
}

class _SleepRecordingScreenState extends State<SleepRecordingScreen> with WidgetsBindingObserver {
  late DateTime _startTime;
  Timer? _elapsedTimeTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isLongPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;
  String _currentSlogan = "";
  Timer? _sloganChangeTimer;
  String _currentCategory = 'random'; // 当前slogan类别

  @override
  void initState() {
    super.initState();
    _startTime = widget.startTime;
    _startElapsedTimeTimer();
    WidgetsBinding.instance.addObserver(this);
    
    // 确保后台保活服务正在运行
    _ensureBackgroundServiceRunning();
    
    // 初始化显示一条slogan
    _updateSlogan();
    
    // 每30秒更新一次slogan
    _sloganChangeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateSlogan();
    });
  }
  
  void _updateSlogan() {
    setState(() {
      if (_currentCategory == 'random') {
        _currentSlogan = SleepSlogans.getRandomSlogan();
      } else {
        _currentSlogan = SleepSlogans.getRandomSloganByCategory(_currentCategory);
      }
    });
  }
  
  void _changeCategory(String category) {
    setState(() {
      _currentCategory = category;
      _updateSlogan();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimeTimer?.cancel();
    _longPressTimer?.cancel();
    _sloganChangeTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _ensureBackgroundServiceRunning() async {
    if (!RecordingService.instance.isRecording) {
      await RecordingService.instance.startBackgroundRecording();
      print('已启动后台保活服务');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('应用生命周期状态变化: $state');
    
    if (state == AppLifecycleState.resumed) {
      // 应用回到前台，重新计算_elapsedTime
      _elapsedTime = DateTime.now().difference(_startTime);
      _startElapsedTimeTimer();
      
      // 确保后台保活正在运行
      _ensureBackgroundServiceRunning();
      
      // 更新slogan
      _updateSlogan();
      
    } else if (state == AppLifecycleState.paused) {
      // 应用进入后台，停止计时器但保持记录
      _elapsedTimeTimer?.cancel();
      
      // 应用进入后台时，确保后台保活正在运行
      _ensureBackgroundServiceRunning();
    }
  }

  void _startElapsedTimeTimer() {
    _elapsedTimeTimer?.cancel();
    
    // 立即更新一次已经过的时间
    setState(() {
      _elapsedTime = DateTime.now().difference(_startTime);
    });

    _elapsedTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = DateTime.now().difference(_startTime);
      });
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _stopRecording() {
    _elapsedTimeTimer?.cancel();
    final endTime = DateTime.now();
    widget.onStopRecording(_startTime, endTime);
    Navigator.pop(context, true);
  }
  
  void _startLongPress() {
    _isLongPressing = true;
    _longPressProgress = 0.0;
    
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _longPressProgress += 0.02; // 50秒后完成
        
        if (_longPressProgress >= 1.0) {
          _longPressTimer?.cancel();
          _isLongPressing = false;
          _stopRecording();
        }
      });
    });
  }
  
  void _endLongPress() {
    _longPressTimer?.cancel();
    setState(() {
      _isLongPressing = false;
      _longPressProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false; // 防止用户使用返回按钮
      },
      child: Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildBody(),
                  ),
                  _buildControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        SizedBox(width: 48), // 平衡布局
        Expanded(
          child: Text(
            '睡眠记录中',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 48), // 平衡布局
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Slogan部分，占据较大空间
        Expanded(
          flex: 6, // 占据60%空间
          child: Center(
            child: _buildSloganCard(),
          ),
        ),
        
        // 时间显示部分，占据较小空间
        Expanded(
          flex: 4, // 占据40%空间
          child: _buildTimeDisplay(),
        ),
      ],
    );
  }

  Widget _buildSloganCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 类别选择器
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCategoryChip('random', '随机'),
              _buildCategoryChip('base', '基础'),
              _buildCategoryChip('tips', '小技巧'),
              _buildCategoryChip('science', '科学'),
              _buildCategoryChip('facts', '趣闻'),
              _buildCategoryChip('quotes', '名言'),
              _buildCategoryChip('psychology', '心理'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Slogan卡片
        GestureDetector(
          onTap: _updateSlogan,  // 点击时更新slogan
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.blue.withOpacity(0.5),
                width: 1,
              ),
            ),
            color: Colors.black.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lightbulb_outline, 
                    color: Colors.amber,
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _currentSlogan,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击可切换',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _currentCategory == category;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            _changeCategory(category);
          }
        },
        backgroundColor: Colors.black.withOpacity(0.3),
        selectedColor: Colors.blue.shade800,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 时间显示
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.7),
                  width: 2,
                ),
              ),
            ),
            
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(_elapsedTime),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    const Text(
                      '开始时间:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MM-dd HH:mm').format(_startTime),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        const Text(
          '请保持手机充电以确保记录完整',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        if (_isLongPressing)
          Column(
            children: [
              Text(
                '请继续按住按钮 ${(_longPressProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _longPressProgress,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        
        const Text(
          '睡醒后长按下方按钮结束记录',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        GestureDetector(
          onLongPressStart: (_) => _startLongPress(),
          onLongPressEnd: (_) => _endLongPress(),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade900.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop_circle, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '长按结束睡眠',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 