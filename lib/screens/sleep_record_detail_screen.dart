import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sleep_record.dart';
import '../services/database_helper.dart';

class SleepRecordDetailScreen extends StatefulWidget {
  final SleepRecord record;

  const SleepRecordDetailScreen({
    super.key,
    required this.record,
  });

  @override
  State<SleepRecordDetailScreen> createState() => _SleepRecordDetailScreenState();
}

class _SleepRecordDetailScreenState extends State<SleepRecordDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠记录详情'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInfoCard(),
              const SizedBox(height: 20),
              _buildAnalysisCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300),
                const SizedBox(width: 8),
                const Text(
                  '基本信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '开始时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.record.startTime)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '结束时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.record.endTime)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '持续时间: ${widget.record.duration.inHours}小时${widget.record.duration.inMinutes % 60}分钟${widget.record.duration.inSeconds % 60}秒',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Card(
      color: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple.shade300),
                const SizedBox(width: 8),
                const Text(
                  '睡眠分析',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAnalysisItem('睡眠质量', widget.record.quality),
            if (widget.record.notes != null && widget.record.notes!.isNotEmpty)
              _buildAnalysisItem('备注', widget.record.notes!),
            _buildDeleteButton(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _confirmDelete,
          icon: const Icon(Icons.delete),
          label: const Text('删除此记录'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
  
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('您确定要删除这条睡眠记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.deleteSleepRecord(widget.record.id!);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录已删除')),
        );
        
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除记录失败: $e')),
        );
      }
    }
  }
  
  Widget _buildAnalysisItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 