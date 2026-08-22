import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/room_member_model.dart';
import '../core/models/room_model.dart';
import '../core/models/room_task_model.dart';
import '../core/utils/safe_stream.dart';

class TaskWithMemberAndRoom {
  final RoomTaskModel task;
  final RoomMemberModel? assignedMember;
  final RoomModel? room;

  TaskWithMemberAndRoom({
    required this.task,
    this.assignedMember,
    this.room,
  });
}

class TaskRepository {
  final SupabaseClient _client;

  TaskRepository(this._client);

  Future<List<TaskWithMemberAndRoom>> getTasksForRoom(String roomId) async {
    try {
      final rows = await _client
          .from('room_tasks')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false);

      final list = <TaskWithMemberAndRoom>[];
      for (final row in (rows as List)) {
        final map = row as Map<String, dynamic>;
        final task = RoomTaskModel.fromMap(map);
        RoomMemberModel? member;
        if (task.assignedToUserId != null) {
          try {
            final memberRow = await _client
                .from('room_members')
                .select()
                .eq('room_id', roomId)
                .eq('user_id', task.assignedToUserId!)
                .maybeSingle();
            if (memberRow != null) {
              member = RoomMemberModel.fromMap(memberRow);
            }
          } catch (_) {}
        }
        list.add(TaskWithMemberAndRoom(task: task, assignedMember: member));
      }
      return list;
    } catch (e) {
      debugPrint('TaskRepository: REST fetch for room tasks failed: $e');
      return [];
    }
  }

  Future<List<TaskWithMemberAndRoom>> getGlobalTasks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('room_tasks')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      final list = <TaskWithMemberAndRoom>[];
      for (final row in (rows as List)) {
        final map = row as Map<String, dynamic>;
        final task = RoomTaskModel.fromMap(map);
        RoomModel? room;
        if (task.roomId != null) {
          try {
            final roomRow = await _client.from('rooms').select().eq('id', task.roomId!).maybeSingle();
            if (roomRow != null) {
              room = RoomModel.fromMap(roomRow);
            }
          } catch (_) {}
        }
        list.add(TaskWithMemberAndRoom(task: task, room: room));
      }
      return list;
    } catch (e) {
      debugPrint('TaskRepository: REST fetch for global tasks failed: $e');
      return [];
    }
  }

  Stream<List<TaskWithMemberAndRoom>> watchTasksForRoom(String roomId) {
    return safeSupabaseStream<List<TaskWithMemberAndRoom>>(
      fetchRest: () => getTasksForRoom(roomId),
      streamRealtime: () {
        return _client
            .from('room_tasks')
            .stream(primaryKey: ['id'])
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .asyncMap((rows) async {
              final list = <TaskWithMemberAndRoom>[];
              for (final row in rows) {
                final task = RoomTaskModel.fromMap(row);
                RoomMemberModel? member;
                if (task.assignedToUserId != null) {
                  try {
                    final memberRow = await _client
                        .from('room_members')
                        .select()
                        .eq('room_id', roomId)
                        .eq('user_id', task.assignedToUserId!)
                        .maybeSingle();
                    if (memberRow != null) {
                      member = RoomMemberModel.fromMap(memberRow);
                    }
                  } catch (_) {}
                }
                list.add(TaskWithMemberAndRoom(task: task, assignedMember: member));
              }
              return list;
            });
      },
    );
  }

  Stream<List<TaskWithMemberAndRoom>> watchGlobalTasks() {
    return safeSupabaseStream<List<TaskWithMemberAndRoom>>(
      fetchRest: () => getGlobalTasks(),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          return Stream.value([]);
        }

        return _client
            .from('room_tasks')
            .stream(primaryKey: ['id'])
            .eq('created_by', userId)
            .order('created_at', ascending: false)
            .asyncMap((rows) async {
              final list = <TaskWithMemberAndRoom>[];
              for (final row in rows) {
                final task = RoomTaskModel.fromMap(row);
                RoomModel? room;
                if (task.roomId != null) {
                  try {
                    final roomRow = await _client.from('rooms').select().eq('id', task.roomId!).maybeSingle();
                    if (roomRow != null) {
                      room = RoomModel.fromMap(roomRow);
                    }
                  } catch (_) {}
                }
                list.add(TaskWithMemberAndRoom(task: task, room: room));
              }
              return list;
            });
      },
    );
  }

  Future<RoomTaskModel> createTask({
    String? roomId,
    required String title,
    String? notes,
    String? assignedToUserId,
    DateTime? dueDate,
    String priority = 'Medium',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    final response = await _client.from('room_tasks').insert({
      'room_id': roomId,
      'title': title,
      'description': notes,
      'assigned_to_user_id': assignedToUserId,
      'due_date': dueDate?.toIso8601String(),
      'priority': priority,
      'is_completed': false,
      'created_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return RoomTaskModel.fromMap(response);
  }

  Future<void> toggleTaskCompleted(String taskId) async {
    final taskRow = await _client.from('room_tasks').select().eq('id', taskId).maybeSingle();
    if (taskRow == null) return;

    final currentStatus = taskRow['is_completed'] as bool? ?? false;
    await _client.from('room_tasks').update({
      'is_completed': !currentStatus,
    }).eq('id', taskId);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('room_tasks').delete().eq('id', taskId);
  }
}
