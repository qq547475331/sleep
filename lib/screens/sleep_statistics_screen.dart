import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../models/sleep_record.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SleepStatisticsScreen extends StatefulWidget {
  const SleepStatisticsScreen({super.key});

  @override
  State<SleepStatisticsScreen> createState() => _SleepStatisticsScreenState();
}

class _SleepStatisticsScreenState extends State<SleepStatisticsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<SleepRecord> _sleepRecords = [];
  bool _isLoading = true;
  String _selectedPeriod = '周'; // 周、月、年
  Map<String, double> _durationStats = {};

  @override
  void initState() {
    super.initState();
    _loadSleepRecords();
  }

  Future<void> _loadSleepRecords() async {
    try {
      final records = await _dbHelper.getAllSleepRecords();
      setState(() {
        _sleepRecords = records;
        _isLoading = false;
        _updateDurationStats();
      });
    } catch (e) {
      print('Error loading sleep records: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateDurationStats() {
    final now = DateTime.now();
    Map<String, double> stats = {};

    switch (_selectedPeriod) {
      case '周':
        // 计算最近7天的平均睡眠时长
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          final dayRecords = _sleepRecords.where((record) =>
              record.startTime.year == date.year &&
              record.startTime.month == date.month &&
              record.startTime.day == date.day).toList();
          
          if (dayRecords.isNotEmpty) {
            final totalDuration = dayRecords.fold(
              Duration.zero,
              (sum, record) => sum + record.duration,
            );
            stats[DateFormat('MM-dd').format(date)] = 
                totalDuration.inMinutes / dayRecords.length;
          }
        }
        break;

      case '月':
        // 计算最近30天的平均睡眠时长
        for (int i = 0; i < 30; i++) {
          final date = now.subtract(Duration(days: i));
          final dayRecords = _sleepRecords.where((record) =>
              record.startTime.year == date.year &&
              record.startTime.month == date.month &&
              record.startTime.day == date.day).toList();
          
          if (dayRecords.isNotEmpty) {
            final totalDuration = dayRecords.fold(
              Duration.zero,
              (sum, record) => sum + record.duration,
            );
            stats[DateFormat('MM-dd').format(date)] = 
                totalDuration.inMinutes / dayRecords.length;
          }
        }
        break;

      case '年':
        // 计算最近12个月的平均睡眠时长
        for (int i = 0; i < 12; i++) {
          final date = DateTime(now.year, now.month - i, 1);
          final monthRecords = _sleepRecords.where((record) =>
              record.startTime.year == date.year &&
              record.startTime.month == date.month).toList();
          
          if (monthRecords.isNotEmpty) {
            final totalDuration = monthRecords.fold(
              Duration.zero,
              (sum, record) => sum + record.duration,
            );
            stats[DateFormat('yyyy-MM').format(date)] = 
                totalDuration.inMinutes / monthRecords.length;
          }
        }
        break;
    }

    setState(() {
      _durationStats = stats;
    });
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['周', '月', '年'].map((period) {
        final isSelected = _selectedPeriod == period;
        return ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedPeriod = period;
              _updateDurationStats();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue.shade300 : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(period),
        );
      }).toList(),
    );
  }

  Widget _buildDurationChart() {
    if (_durationStats.isEmpty) {
      return const Center(
        child: Text(
          '暂无睡眠数据',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final List<FlSpot> spots = [];
    final List<String> labels = [];
    int index = 0;

    _durationStats.forEach((date, duration) {
      spots.add(FlSpot(index.toDouble(), duration / 60)); // 转换为小时
      labels.add(date);
      index++;
    });

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1, // 1小时间隔
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.3),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.3),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        labels[value.toInt()],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}h',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          minX: 0,
          maxX: spots.length - 1,
          minY: 0,
          maxY: spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue.shade300,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageDurationCard() {
    if (_durationStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalMinutes = _durationStats.values.reduce((a, b) => a + b);
    final averageMinutes = totalMinutes / _durationStats.length;
    final averageHours = (averageMinutes / 60).floor();
    final averageRemainingMinutes = (averageMinutes % 60).round();

    return Container(
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
          const Text(
            '平均睡眠时长',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$averageHours小时$averageRemainingMinutes分钟',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠统计'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),
                    _buildAverageDurationCard(),
                    const SizedBox(height: 24),
                    const Text(
                      '睡眠时长趋势',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDurationChart(),
                  ],
                ),
              ),
      ),
    );
  }
} 