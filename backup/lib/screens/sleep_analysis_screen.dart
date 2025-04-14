import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';
import 'dart:math' as math;

class SleepAnalysisScreen extends StatefulWidget {
  const SleepAnalysisScreen({super.key});

  @override
  State<SleepAnalysisScreen> createState() => _SleepAnalysisScreenState();
}

class _SleepAnalysisScreenState extends State<SleepAnalysisScreen> {
  List<SleepRecord> _records = [];
  bool _isLoading = true;
  String _timeFilter = '全部';
  final List<String> _timeFilters = ['全部', '本周', '本月', '本年'];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper.instance;
      final allRecords = await dbHelper.getAllSleepRecords();
      
      // 根据过滤条件筛选记录
      final filteredRecords = _filterRecords(allRecords);
      
      setState(() {
        _records = filteredRecords;
        _isLoading = false;
      });
    } catch (e) {
      print('加载睡眠记录失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<SleepRecord> _filterRecords(List<SleepRecord> records) {
    final now = DateTime.now();
    
    switch (_timeFilter) {
      case '本周':
        // 计算本周的开始（周一）
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return records.where((record) => record.startTime.isAfter(startOfWeekDate) || 
                                       record.startTime.isAtSameMomentAs(startOfWeekDate)).toList();
        
      case '本月':
        // 本月的开始（1号）
        final startOfMonth = DateTime(now.year, now.month, 1);
        return records.where((record) => record.startTime.isAfter(startOfMonth) || 
                                       record.startTime.isAtSameMomentAs(startOfMonth)).toList();
        
      case '本年':
        // 本年的开始（1月1日）
        final startOfYear = DateTime(now.year, 1, 1);
        return records.where((record) => record.startTime.isAfter(startOfYear) || 
                                       record.startTime.isAtSameMomentAs(startOfYear)).toList();
        
      case '全部':
      default:
        return List.from(records);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠分析'),
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
            : _records.isEmpty
                ? const Center(
                    child: Text(
                      '暂无睡眠记录',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : _buildAnalysisContent(),
      ),
    );
  }

  Widget _buildAnalysisContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeFilterChips(),
          const SizedBox(height: 24),
          _buildSleepSummary(),
          const SizedBox(height: 24),
          _buildSleepDurationChart(),
          const SizedBox(height: 24),
          _buildSleepQualityChart(),
          const SizedBox(height: 24),
          _buildSleepTimeDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChips() {
    return Wrap(
      spacing: 8,
      children: _timeFilters.map((filter) {
        return ChoiceChip(
          label: Text(filter),
          selected: _timeFilter == filter,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _timeFilter = filter;
              });
              _loadRecords();
            }
          },
          backgroundColor: Colors.grey.shade800,
          selectedColor: Colors.blue.shade700,
          labelStyle: TextStyle(
            color: _timeFilter == filter ? Colors.white : Colors.white70,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSleepSummary() {
    // 计算平均睡眠时长
    final totalDuration = _records.fold<Duration>(
      Duration.zero,
      (total, record) => total + record.duration,
    );
    final avgDurationMinutes = _records.isNotEmpty
        ? totalDuration.inMinutes / _records.length
        : 0;
    final avgHours = (avgDurationMinutes / 60).floor();
    final avgMinutes = (avgDurationMinutes % 60).floor();
    
    // 计算最长和最短睡眠时长
    SleepRecord? longestRecord;
    SleepRecord? shortestRecord;
    
    for (final record in _records) {
      if (longestRecord == null || record.duration > longestRecord.duration) {
        longestRecord = record;
      }
      if (shortestRecord == null || record.duration < shortestRecord.duration) {
        shortestRecord = record;
      }
    }
    
    // 计算平均睡眠质量评分
    final qualityMap = {
      '优秀': 90.0,
      '良好': 80.0,
      '一般': 70.0,
      '较差': 60.0,
    };
    
    double avgQuality = 0;
    for (final record in _records) {
      avgQuality += qualityMap[record.quality] ?? 75.0;
    }
    if (_records.isNotEmpty) {
      avgQuality /= _records.length;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '睡眠摘要',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.access_time,
                  title: '平均睡眠时长',
                  value: '$avgHours小时$avgMinutes分钟',
                  color: Colors.blue.shade300,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.star,
                  title: '平均睡眠质量',
                  value: '${avgQuality.toStringAsFixed(1)}分',
                  color: Colors.amber.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.arrow_upward,
                  title: '最长睡眠',
                  value: longestRecord != null
                      ? '${longestRecord.duration.inHours}小时${longestRecord.duration.inMinutes % 60}分钟'
                      : '暂无数据',
                  color: Colors.green.shade300,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.arrow_downward,
                  title: '最短睡眠',
                  value: shortestRecord != null
                      ? '${shortestRecord.duration.inHours}小时${shortestRecord.duration.inMinutes % 60}分钟'
                      : '暂无数据',
                  color: Colors.red.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepDurationChart() {
    // 按日期分组
    final Map<String, Duration> durationsByDate = {};

    for (final record in _records) {
      final dateStr = '${record.startTime.month}/${record.startTime.day}';
      durationsByDate[dateStr] = (durationsByDate[dateStr] ?? Duration.zero) + record.duration;
    }

    final entries = durationsByDate.entries.toList();
    // 限制显示最近10天的数据，避免图表过于拥挤
    final displayEntries = entries.length > 10 ? entries.sublist(entries.length - 10) : entries;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '睡眠时长趋势',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '最近记录的每日睡眠时长',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: displayEntries.isEmpty
                    ? 10
                    : displayEntries
                          .map((e) => e.value.inHours.toDouble() + e.value.inMinutes.remainder(60) / 60)
                          .reduce(math.max) *
                        1.2,
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value % 2 == 0 && value > 0) {
                          return Text(
                            '${value.toInt()}h',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < displayEntries.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              displayEntries[value.toInt()].key,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                barGroups: List.generate(
                  displayEntries.length,
                  (index) {
                    final entry = displayEntries[index];
                    final hours = entry.value.inHours.toDouble();
                    final minutes = entry.value.inMinutes.remainder(60) / 60;
                    final value = hours + minutes;
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: _getSleepDurationColor(value),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipMargin: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final entry = displayEntries[group.x.toInt()];
                      final hours = entry.value.inHours;
                      final minutes = entry.value.inMinutes.remainder(60);
                      final dateStr = entry.key;
                      return BarTooltipItem(
                        '日期: $dateStr\n时长: $hours小时$minutes分钟',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                    getTooltipColor: (_) => Colors.blueGrey.shade800.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 颜色图例
          Wrap(
            spacing: 16,
            children: [
              _buildColorLegend('较短(<6h)', Colors.red.shade400),
              _buildColorLegend('一般(6-7h)', Colors.orange.shade400),
              _buildColorLegend('良好(7-9h)', Colors.green.shade400),
              _buildColorLegend('过长(>9h)', Colors.blue.shade400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSleepQualityChart() {
    // 按质量分组
    final Map<String, int> qualityCounts = {
      '优秀': 0,
      '良好': 0,
      '一般': 0,
      '较差': 0,
    };

    for (final record in _records) {
      qualityCounts[record.quality] = (qualityCounts[record.quality] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '睡眠质量分布',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '不同睡眠质量的分布比例',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _records.isEmpty 
            ? const Center(
                child: Text(
                  '暂无数据',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: qualityCounts.entries.map((entry) {
                  final percentage = _records.isNotEmpty
                    ? (entry.value / _records.length * 100).toStringAsFixed(1)
                    : "0.0";
                    
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    title: '${entry.key}\n${percentage}%',
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    color: _getQualityColor(entry.key),
                    badgeWidget: entry.value > 0
                        ? Text(
                            '${entry.value}次',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                    badgePositionPercentageOffset: 1.1,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 质量图例
          Wrap(
            spacing: 16,
            children: [
              _buildColorLegend('较差', Colors.red.shade400),
              _buildColorLegend('一般', Colors.orange.shade400),
              _buildColorLegend('良好', Colors.blue.shade400),
              _buildColorLegend('优秀', Colors.green.shade400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTimeDistributionChart() {
    // 统计每个小时开始睡眠的次数
    final Map<int, int> startTimeHours = {};
    for (int i = 0; i < 24; i++) {
      startTimeHours[i] = 0;
    }

    for (final record in _records) {
      final hour = record.startTime.hour;
      startTimeHours[hour] = (startTimeHours[hour] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '睡眠时间分布',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '按小时统计入睡时间分布',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: startTimeHours.values.isEmpty
                    ? 10
                    : startTimeHours.values.reduce(math.max).toDouble() * 1.2,
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        // 只显示偶数小时，减少视觉混乱
                        final hour = value.toInt();
                        if (hour % 4 == 0 || hour == 22 || hour == 6 || hour == 18) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '$hour:00',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                barGroups: List.generate(
                  24,
                  (hour) {
                    final count = startTimeHours[hour] ?? 0;
                    
                    // 设置颜色：深夜用蓝色，白天用黄色
                    final isNight = hour >= 18 || hour < 6;
                    
                    return BarChartGroupData(
                      x: hour,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: isNight
                              ? Colors.blue.shade400
                              : Colors.amber.shade400,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipMargin: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final hour = group.x.toInt();
                      final count = startTimeHours[hour] ?? 0;
                      final percentage = _records.isNotEmpty 
                        ? (count / _records.length * 100).toStringAsFixed(1)
                        : "0.0";
                      return BarTooltipItem(
                        '$hour:00 - ${(hour+1) % 24}:00\n$count次 ($percentage%)',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                    getTooltipColor: (_) => Colors.blueGrey.shade800.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSleepDurationColor(double hours) {
    if (hours < 6) {
      return Colors.red.shade400;
    } else if (hours < 7) {
      return Colors.orange.shade400;
    } else if (hours < 9) {
      return Colors.green.shade400;
    } else {
      return Colors.blue.shade400;
    }
  }

  Color _getQualityColor(String quality) {
    switch (quality) {
      case '优秀':
        return Colors.green.shade400;
      case '良好':
        return Colors.blue.shade400;
      case '一般':
        return Colors.orange.shade400;
      case '较差':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }
} 