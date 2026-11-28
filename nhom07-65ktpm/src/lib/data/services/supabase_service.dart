import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_message_model.dart';
import '../models/nap_record_model.dart';
import '../models/sleep_goal_model.dart';
import '../models/sleep_record_model.dart';
import '../models/user_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  bool _initialized = false;
  String? _currentUserEmail;

  void markInitialized() {
    _initialized = true;
  }

  void setCurrentUserEmail(String? email) {
    final normalized = email?.trim().toLowerCase();
    _currentUserEmail = (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  String? get currentUserEmail => _currentUserEmail;

  SupabaseClient? get _client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // --- Users ---
  Future<UserModel?> fetchUserByEmail(String email) async {
    final client = _client;
    if (client == null) return null;
    try {
      final normalized = email.trim().toLowerCase();
      final data = await client
          .from('users')
          .select()
          .eq('email', normalized)
          .maybeSingle();
      if (data == null) return null;
      return UserModel(
        name: data['name'] ?? '',
        email: data['email'] ?? normalized,
        studentId: data['student_id'] ?? '',
        className: data['class_name'] ?? '',
        createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SupabaseService] fetchUserByEmail error: $e');
      return null;
    }
  }

  Future<String?> fetchUserPassword(String email) async {
    final client = _client;
    if (client == null) return null;
    try {
      final data = await client
          .from('users')
          .select('password')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();
      return data?['password'] as String?;
    } catch (e) {
      debugPrint('[SupabaseService] fetchUserPassword error: $e');
      return null;
    }
  }

  Future<void> upsertUser(UserModel user, {String? password}) async {
    final client = _client;
    if (client == null) return;
    try {
      final payload = <String, dynamic>{
        'name': user.name,
        'email': user.email.trim().toLowerCase(),
        'student_id': user.studentId,
        'class_name': user.className,
        'created_at': user.createdAt.toIso8601String(),
      };
      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
      }
      await client.from('users').upsert(payload, onConflict: 'email');
    } catch (e) {
      debugPrint('[SupabaseService] upsertUser error: $e');
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('users').update({
        'name': user.name,
        'student_id': user.studentId,
        'class_name': user.className,
      }).eq('email', user.email.trim().toLowerCase());
    } catch (e) {
      debugPrint('[SupabaseService] updateUserProfile error: $e');
    }
  }

  // --- Sleep Goals ---
  Future<void> syncSleepGoal(SleepGoalModel goal) async {
    final client = _client;
    final userEmail = _currentUserEmail;
    if (client == null || userEmail == null) return;
    try {
      await client.from('sleep_goals').insert({
        'user_email': userEmail,
        'bedtime_hour': goal.bedtimeHour,
        'bedtime_minute': goal.bedtimeMinute,
        'wake_hour': goal.wakeHour,
        'wake_minute': goal.wakeMinute,
        'target_duration_hours': goal.targetDurationHours,
        'active_days': goal.activeDays,
        'is_reminder_enabled': goal.isReminderEnabled,
      });
    } catch (e) {
      debugPrint('[SupabaseService] syncSleepGoal error: $e');
    }
  }

  Future<SleepGoalModel?> fetchSleepGoal(String email) async {
    final client = _client;
    if (client == null) return null;
    try {
      final data = await client
          .from('sleep_goals')
          .select()
          .eq('user_email', email.trim().toLowerCase())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return SleepGoalModel(
        bedtimeHour: data['bedtime_hour'] as int,
        bedtimeMinute: data['bedtime_minute'] as int,
        wakeHour: data['wake_hour'] as int,
        wakeMinute: data['wake_minute'] as int,
        targetDurationHours: (data['target_duration_hours'] as num).toDouble(),
        activeDays: data['active_days'] as String? ?? '1,2,3,4,5,6,7',
        isReminderEnabled: data['is_reminder_enabled'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('[SupabaseService] fetchSleepGoal error: $e');
      return null;
    }
  }

  // --- Sleep Records ---
  Future<void> syncSleepRecord(SleepRecordModel record) async {
    final client = _client;
    final userEmail = _currentUserEmail;
    if (client == null || userEmail == null) return;
    try {
      await client.from('sleep_records').insert({
        'user_email': userEmail,
        'sleep_time': record.sleepTime.toIso8601String(),
        'wake_time': record.wakeTime.toIso8601String(),
        'duration_hours': record.durationHours,
        'wake_up_count': record.wakeUpCount,
        'feeling_rating': record.feelingRating,
        'note': record.note,
        'is_goal_met': record.isGoalMet,
        'created_at': record.createdAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabaseService] syncSleepRecord error: $e');
    }
  }

  Future<List<SleepRecordModel>?> fetchSleepRecords(String email) async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from('sleep_records')
          .select()
          .eq('user_email', email.trim().toLowerCase())
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List<dynamic>).map((row) {
        final data = row as Map<String, dynamic>;
        return SleepRecordModel(
          sleepTime: DateTime.parse(data['sleep_time'] as String).toLocal(),
          wakeTime: DateTime.parse(data['wake_time'] as String).toLocal(),
          durationHours: (data['duration_hours'] as num).toDouble(),
          wakeUpCount: data['wake_up_count'] as int? ?? 0,
          feelingRating: data['feeling_rating'] as int? ?? 3,
          note: data['note'] as String? ?? '',
          isGoalMet: data['is_goal_met'] as bool? ?? false,
          createdAt: DateTime.parse(data['created_at'] as String).toLocal(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchSleepRecords error: $e');
      return null;
    }
  }

  // --- Nap Records ---
  Future<void> syncNapRecord(NapRecordModel nap) async {
    final client = _client;
    final userEmail = _currentUserEmail;
    if (client == null || userEmail == null) return;
    try {
      await client.from('nap_records').insert({
        'user_email': userEmail,
        'start_time': nap.startTime.toIso8601String(),
        'duration_minutes': nap.durationMinutes,
        'note': nap.note,
        'created_at': nap.createdAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabaseService] syncNapRecord error: $e');
    }
  }

  Future<List<NapRecordModel>?> fetchNapRecords(String email) async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from('nap_records')
          .select()
          .eq('user_email', email.trim().toLowerCase())
          .order('created_at', ascending: false)
          .limit(20);
      return (rows as List<dynamic>).map((row) {
        final data = row as Map<String, dynamic>;
        return NapRecordModel(
          startTime: DateTime.parse(data['start_time'] as String).toLocal(),
          durationMinutes: data['duration_minutes'] as int,
          note: data['note'] as String? ?? '',
          createdAt: DateTime.parse(data['created_at'] as String).toLocal(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchNapRecords error: $e');
      return null;
    }
  }

  // --- AI Messages ---
  Future<void> syncAIMessage(AIMessageModel message) async {
    final client = _client;
    final userEmail = _currentUserEmail;
    if (client == null || userEmail == null) return;
    try {
      await client.from('ai_messages').insert({
        'user_email': userEmail,
        'text': message.text,
        'is_user': message.isUser,
        'is_offline': message.isOffline,
        'timestamp': message.timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabaseService] syncAIMessage error: $e');
    }
  }

  Future<List<AIMessageModel>?> fetchAIMessages(String email) async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from('ai_messages')
          .select()
          .eq('user_email', email.trim().toLowerCase())
          .order('timestamp', ascending: true);
      return (rows as List<dynamic>).map((row) {
        final data = row as Map<String, dynamic>;
        return AIMessageModel(
          text: data['text'] as String,
          isUser: data['is_user'] as bool,
          isOffline: data['is_offline'] as bool? ?? false,
          timestamp: DateTime.parse(data['timestamp'] as String).toLocal(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchAIMessages error: $e');
      return null;
    }
  }

  Future<void> clearAIMessages() async {
    final client = _client;
    final userEmail = _currentUserEmail;
    if (client == null || userEmail == null) return;
    try {
      await client.from('ai_messages').delete().eq('user_email', userEmail);
    } catch (e) {
      debugPrint('[SupabaseService] clearAIMessages error: $e');
    }
  }
}
