import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/sleep_record.dart';
import 'sleep_record_detail_screen.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<SleepRecord> _records = [];
  // 按年月分组的记录
  Map<String, List<SleepRecord>> _groupedRecords = {};
  // 记录每个分组的展开状态
  Map<String, bool> _expandedState = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await _dbHelper.getSleepRecords();
    
    // 按年月分组记录
    final groupedMap = <String, List<SleepRecord>>{};
    final expandedMap = <String, bool>{};
    
    for (var record in records) {
      // 创建年月分组标识，如"2025年4月"
      final key = DateFormat('yyyy年M月').format(record.startTime);
      
      // 如果分组不存在，创建新分组并默认展开
      if (!groupedMap.containsKey(key)) {
        groupedMap[key] = [];
        expandedMap[key] = true; // 默认展开
      }
      
      groupedMap[key]!.add(record);
    }
    
    // 对每个分组内记录按时间倒序排序（最新的在最前）
    groupedMap.forEach((key, records) {
      records.sort((a, b) => b.startTime.compareTo(a.startTime));
    });
    
    // 对分组键按时间倒序排序
    final sortedKeys = groupedMap.keys.toList()
      ..sort((a, b) {
        // 从格式化的年月字符串中提取年月并比较
        final aDate = _getDateFromKey(a);
        final bDate = _getDateFromKey(b);
        return bDate.compareTo(aDate); // 倒序排列
      });
    
    // 创建有序的分组Map
    final sortedGroupedMap = <String, List<SleepRecord>>{};
    for (var key in sortedKeys) {
      sortedGroupedMap[key] = groupedMap[key]!;
    }
    
    setState(() {
      _records = records;
      _groupedRecords = sortedGroupedMap;
      _expandedState = expandedMap;
    });
  }
  
  // 从"2025年4月"格式的键中提取日期
  DateTime _getDateFromKey(String key) {
    // 提取年和月
    final pattern = RegExp(r'(\d+)年(\d+)月');
    final match = pattern.firstMatch(key);
    
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      return DateTime(year, month);
    }
    
    // 无法解析则返回当前时间
    return DateTime.now();
  }

  Future<void> _deleteRecord(int id) async {
    await _dbHelper.deleteSleepRecord(id);
    await _loadRecords();
  }
  
  // 切换分组的展开/折叠状态
  void _toggleGroupExpanded(String groupKey) {
    setState(() {
      _expandedState[groupKey] = !(_expandedState[groupKey] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠历史'),
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
        child: _records.isEmpty
            ? const Center(
                child: Text(
                  '暂无睡眠记录',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : ListView.builder(
                itemCount: _groupedRecords.length,
                itemBuilder: (context, index) {
                  final groupKey = _groupedRecords.keys.elementAt(index);
                  final groupRecords = _groupedRecords[groupKey]!;
                  final isExpanded = _expandedState[groupKey] ?? false;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      children: [
                        // 月份标题，可点击折叠/展开
                        InkWell(
                          onTap: () => _toggleGroupExpanded(groupKey),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_right,
                                  color: Colors.blue.shade300,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  groupKey,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${groupRecords.length}条记录)',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // 该月的记录列表，根据展开状态显示或隐藏
                        if (isExpanded)
                          ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: groupRecords.length,
                            itemBuilder: (context, recordIndex) {
                              final record = groupRecords[recordIndex];
                              
                              return Dismissible(
                                key: Key(record.id.toString()),
                                background: Container(
                                  color: Colors.red.withOpacity(0.7),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) => _deleteRecord(record.id!),
                                child: ListTile(
                                  title: Text(
                                    DateFormat('yyyy-MM-dd HH:mm').format(record.startTime),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '持续时间: ${record.duration.inHours}小时${record.duration.inMinutes % 60}分钟${record.duration.inSeconds % 60}秒',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SleepRecordDetailScreen(
                                          record: record,
                                        ),
                                      ),
                                    ).then((_) => _loadRecords()); // 返回时刷新记录
                                  },
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
} 