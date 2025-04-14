import 'package:intl/intl.dart';

class SleepRecord {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String quality;
  final String? notes;

  SleepRecord({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.quality,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'duration': duration.inMilliseconds,
      'quality': quality,
      'notes': notes,
    };
  }

  factory SleepRecord.fromMap(Map<String, dynamic> map) {
    return SleepRecord(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      duration: Duration(milliseconds: map['duration'] as int),
      quality: map['quality'] as String,
      notes: map['notes'] as String?,
    );
  }

  String get formattedStartTime => DateFormat('yyyy/MM/dd HH:mm').format(startTime);
  String get formattedEndTime => DateFormat('yyyy/MM/dd HH:mm').format(endTime);
  Duration get sleepDuration => endTime.difference(startTime);
  String get formattedSleepDuration {
    final hours = sleepDuration.inHours;
    final minutes = sleepDuration.inMinutes.remainder(60);
    final seconds = sleepDuration.inSeconds.remainder(60);
    return '$hours小时$minutes分钟$seconds秒';
  }
} 