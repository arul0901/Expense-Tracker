import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/services/secure_token_storage.dart';
import '../core/models/category_model.dart';
import '../core/models/event_model.dart';
import '../core/models/expense_split_model.dart';
import '../core/models/member_financial_summary.dart';
import '../core/models/room_activity_model.dart';
import '../core/models/room_expense_model.dart';
import '../core/models/room_invite_model.dart';
import '../core/models/room_member_model.dart';
import '../core/models/room_model.dart';
import '../core/models/settlement_model.dart';
import '../core/utils/invite_token_service.dart';
import '../core/utils/safe_stream.dart';
import '../core/utils/settlement_engine.dart';
import '../core/utils/split_engine.dart';
import '../services/notification_service.dart';

class RoomWithDetails {
  final RoomModel room;
  final List<RoomMemberModel> members;
  final int totalRoomExpensesPaise;
  final MemberNetBalance currentUserBalance;
  final int unpaidMembersCount;
  final EventModel? linkedEvent;
  final RoomActivityModel? lastActivity;

  RoomWithDetails({
    required this.room,
    required this.members,
    required this.totalRoomExpensesPaise,
    required this.currentUserBalance,
    required this.unpaidMembersCount,
    this.linkedEvent,
    this.lastActivity,
  });
}

class ExpenseWithPayerAndSplits {
  final RoomExpenseModel expense;
  final RoomMemberModel payer;
  final List<ExpenseSplitModel> splits;
  final CategoryModel? category;

  ExpenseWithPayerAndSplits({
    required this.expense,
    required this.payer,
    required this.splits,
    this.category,
  });
}

class RoomRepository {
  final SupabaseClient _client;

  RoomRepository(this._client);

  Future<List<RoomWithDetails>> getAllRooms() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client.from('rooms').select().timeout(const Duration(seconds: 4));
      final roomIds = (rows as List)
          .map((r) => (r as Map<String, dynamic>)['id']?.toString())
          .whereType<String>()
          .toList();

      if (roomIds.isEmpty) return [];

      // Fetch all room details in PARALLEL!
      final detailsList = await Future.wait(
        roomIds.map((id) => getRoomWithDetails(id)),
      );

      final result = <RoomWithDetails>[];
      for (final details in detailsList) {
        if (details != null) {
          if (details.room.createdBy == userId || details.members.any((m) => m.userId == userId || m.isCurrentUser)) {
            result.add(details);
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('RoomRepository: REST fetch for all rooms failed: $e');
      return [];
    }
  }

  Stream<List<RoomWithDetails>> watchAllRooms() {
    return safeSupabaseStream<List<RoomWithDetails>>(
      fetchRest: () => getAllRooms(),
      streamRealtime: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          return Stream.value([]);
        }

        return _client
            .from('room_members')
            .stream(primaryKey: ['id'])
            .asyncMap((_) => getAllRooms());
      },
    );
  }

  Future<RoomWithDetails?> getRoomWithDetails(String roomId) async {
    final activeUserId = _client.auth.currentUser?.id;
    try {
      // Execute all subqueries in PARALLEL simultaneously
      final results = await Future.wait<dynamic>([
        _client.from('rooms').select().eq('id', roomId).maybeSingle(),
        getRoomMembers(roomId),
        _client.from('room_expenses').select('amount_paise').eq('room_id', roomId),
        calculateRoomBalances(roomId),
        _client.from('events').select().eq('id', roomId).maybeSingle(),
        _client.from('room_activities').select().eq('room_id', roomId).order('created_at', ascending: false).limit(1),
      ]);

      final roomRow = results[0] as Map<String, dynamic>?;
      if (roomRow == null) return null;
      final room = RoomModel.fromMap(roomRow);

      final members = results[1] as List<RoomMemberModel>;
      final expensesRows = results[2] as List<dynamic>;
      final total = expensesRows.fold<int>(0, (sum, e) => sum + ((e as Map<String, dynamic>)['amount_paise'] as num? ?? 0).toInt());

      final balances = results[3] as List<MemberNetBalance>;
      final suggestions = SettlementEngine.calculateMinimumSettlements(balances);
      final unpaidCount = suggestions.map((s) => s.fromMemberName).toSet().length;

      final currentUser = members.firstWhere(
        (m) => m.isCurrentUser || m.userId == activeUserId,
        orElse: () => members.isNotEmpty
            ? members.first
            : RoomMemberModel(id: 'temp', roomId: roomId, name: 'You', isCurrentUser: true, role: 'Owner', avatarColor: 0xFF3B82F6),
      );

      final currentUserBalance = balances.firstWhere(
        (b) => b.memberName == currentUser.name,
        orElse: () => MemberNetBalance(
          memberName: currentUser.name,
          totalPaidPaise: 0,
          totalSharePaise: 0,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
      );

      EventModel? linkedEvent;
      final eventRow = results[4] as Map<String, dynamic>?;
      if (eventRow != null) {
        linkedEvent = EventModel.fromMap(eventRow);
      }

      RoomActivityModel? lastActivity;
      final actRows = (results[5] as List<dynamic>?);
      if (actRows != null && actRows.isNotEmpty) {
        lastActivity = RoomActivityModel.fromMap(actRows.first as Map<String, dynamic>);
      }

      return RoomWithDetails(
        room: room,
        members: members,
        totalRoomExpensesPaise: total,
        currentUserBalance: currentUserBalance,
        unpaidMembersCount: unpaidCount,
        linkedEvent: linkedEvent,
        lastActivity: lastActivity,
      );
    } catch (e) {
      debugPrint('Error getting room with details: $e');
      return null;
    }
  }

  Future<String> createRoom({
    required String name,
    String? description,
    String type = 'Trip',
    int colorAccent = 0xFF0D9488,
    String currency = '₹ INR',
    bool paymentRemindersEnabled = true,
    bool taskRemindersEnabled = true,
    int reminderAfterDays = 3,
    String? eventId,
    List<String> memberNames = const [],
  }) async {
    User? currentUser = _client.auth.currentUser;
    String currentUserId = currentUser?.id ?? '';
    String currentUserEmail = currentUser?.email ?? '';

    if (currentUserId.isEmpty) {
      try {
        final storageUser = await SecureTokenStorage().getUser();
        if (storageUser != null && storageUser.id.isNotEmpty) {
          currentUserId = storageUser.id;
          currentUserEmail = storageUser.email;
        }
      } catch (_) {}
    }

    if (currentUserId.isEmpty) {
      throw Exception('Please sign in first to create room workspaces.');
    }

    final ownerDisplayName = (currentUser?.userMetadata?['display_name'] ??
            currentUser?.userMetadata?['full_name'] ??
            (currentUserEmail.contains('@') ? currentUserEmail.split('@').first : 'Owner'))
        .toString();

    // 0. Ensure user profile exists
    try {
      await _client.from('profiles').upsert({
        'id': currentUserId,
        'email': currentUserEmail.isNotEmpty ? currentUserEmail : '$currentUserId@app.com',
        'display_name': ownerDisplayName,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Profile upsert warning: $e');
    }

    final token = InviteTokenService.generateSecureToken();

    // 1. Insert Room
    Map<String, dynamic> roomRow = {};
    try {
      roomRow = await _client.from('rooms').insert({
        'created_by': currentUserId,
        'name': name,
        'description': description,
        'type': type,
        'color_accent': colorAccent,
        'currency': currency,
        'payment_reminders_enabled': paymentRemindersEnabled,
        'task_reminders_enabled': taskRemindersEnabled,
        'reminder_after_days': reminderAfterDays,
        'event_id': eventId,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        final fallback = await _client
            .from('rooms')
            .select()
            .eq('created_by', currentUserId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (fallback != null) {
          roomRow = fallback;
        } else {
          throw Exception('Unable to create room workspace: ${e.message}');
        }
      } else {
        rethrow;
      }
    }

    final roomId = roomRow['id'].toString();

    // 2. Insert Owner Member (upsert to handle trigger execution)
    try {
      await _client.from('room_members').upsert({
        'room_id': roomId,
        'user_id': currentUserId,
        'member_name': ownerDisplayName,
        'role': 'Owner',
        'avatar_color': colorAccent,
        'is_active': true,
        'joined_at': DateTime.now().toIso8601String(),
      }, onConflict: 'room_id, user_id');
    } catch (e) {
      debugPrint('Owner member upsert warning: $e');
    }

    // 3. Insert Initial Member Names
    final avatarColors = [0xFF3B82F6, 0xFFEC4899, 0xFF8B5CF6, 0xFFF59E0B, 0xFF10B981];
    int cIdx = 0;
    for (final mName in memberNames) {
      if (mName.trim().isNotEmpty) {
        try {
          await _client.from('room_members').insert({
            'room_id': roomId,
            'member_name': mName.trim(),
            'role': 'Member',
            'avatar_color': avatarColors[cIdx % avatarColors.length],
            'is_active': true,
            'joined_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Member insertion warning ($mName): $e');
        }
        cIdx++;
      }
    }

    // 4. Insert Default Invite Token
    try {
      await _client.from('room_invites').insert({
        'room_id': roomId,
        'token_hash': token,
        'created_by': currentUserId,
        'role': 'Member',
        'state': 'Active',
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // 5. Insert Creation Activity
    try {
      await _client.from('room_activities').insert({
        'room_id': roomId,
        'user_id': currentUserId,
        'member_name': ownerDisplayName,
        'action_type': 'room_created',
        'details': 'Created room "$name"',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    return roomId;
  }

  static String? splitNameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return null;
    return email.split('@').first;
  }


  Future<RoomInviteModel> getOrCreateActiveInvite(String roomId) async {
    final currentUser = _client.auth.currentUser;
    try {
      final existingRows = await _client
          .from('room_invites')
          .select()
          .eq('room_id', roomId)
          .eq('state', 'Active')
          .gte('expires_at', DateTime.now().toIso8601String())
          .limit(1);

      if (existingRows.isNotEmpty) {
        return RoomInviteModel.fromMap(existingRows.first);
      }
    } catch (_) {}

    final token = InviteTokenService.generateSecureToken();
    try {
      final newRow = await _client.from('room_invites').insert({
        'room_id': roomId,
        'token_hash': token,
        'created_by': currentUser?.id,
        'role': 'Member',
        'state': 'Active',
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return RoomInviteModel.fromMap(newRow);
    } catch (e) {
      debugPrint('Warning: Could not save room_invite to Supabase: $e');
      return RoomInviteModel(
        id: 'invite_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        token: token,
        createdBy: currentUser?.id,
        role: 'Member',
        state: 'Active',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
      );
    }
  }

  Future<RoomModel?> findRoomByInviteToken(String rawToken) async {
    final cleanToken = InviteTokenService.extractTokenFromQr(rawToken) ?? rawToken.trim();

    // 1. Try SECURITY DEFINER RPC first (bypasses RLS for non-members joining new rooms)
    try {
      final rpcResult = await _client.rpc('get_room_by_invite_token', params: {'p_token': cleanToken});
      if (rpcResult != null && (rpcResult as List).isNotEmpty) {
        return RoomModel.fromMap(rpcResult.first as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('RPC get_room_by_invite_token error: $e');
    }

    // 2. Direct query fallback
    try {
      final inviteRow = await _client.from('room_invites').select().eq('token_hash', cleanToken.toUpperCase()).maybeSingle();
      if (inviteRow != null) {
        final roomIdStr = inviteRow['room_id']?.toString();
        if (roomIdStr != null) {
          final roomRow = await _client.from('rooms').select().eq('id', roomIdStr).maybeSingle();
          if (roomRow != null) {
            return RoomModel.fromMap(roomRow);
          }
        }
      }
    } catch (e) {
      debugPrint('Cloud invite token lookup error: $e');
    }

    return null;
  }

  Future<bool> joinRoomWithToken(String token, String memberName) async {
    final cleanToken = InviteTokenService.extractTokenFromQr(token) ?? token.trim().toUpperCase();
    final room = await findRoomByInviteToken(cleanToken);

    final currentUser = _client.auth.currentUser;
    final cleanName = memberName.trim();

    if (room != null) {
      // 1. Check if a member row (linked or placeholder) already exists in this room
      try {
        final existingRows = await _client.from('room_members').select().eq('room_id', room.id);
        Map<String, dynamic>? matchRow;
        for (final row in (existingRows as List)) {
          final uId = row['user_id']?.toString();
          final mName = (row['member_name'] ?? row['name'])?.toString() ?? '';
          final isUserMatch = (currentUser?.id != null && uId == currentUser!.id);
          final isUnlinkedNameMatch = (uId == null && mName.trim().toLowerCase() == cleanName.toLowerCase());
          if (isUserMatch || isUnlinkedNameMatch) {
            matchRow = row as Map<String, dynamic>;
            break;
          }
        }

        if (matchRow != null) {
          final matchId = matchRow['id'].toString();
          try {
            await _client.from('room_members').update({
              'user_id': currentUser?.id ?? matchRow['user_id'],
              'member_name': cleanName,
              'is_active': true,
            }).eq('id', matchId);
          } on PostgrestException catch (_) {
            await _client.from('room_members').update({
              'user_id': currentUser?.id ?? matchRow['user_id'],
              'name': cleanName,
              'is_active': true,
            }).eq('id', matchId);
          }

          try {
            await _client.from('room_activities').insert({
              'room_id': room.id,
              'user_id': currentUser?.id,
              'member_name': cleanName,
              'action_type': 'member_joined',
              'details': '$cleanName joined the room workspace',
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}

          return true;
        }

        // 2. Insert new room member if no existing row matched
        try {
          await _client.from('room_members').insert({
            'room_id': room.id,
            'user_id': currentUser?.id,
            'member_name': cleanName,
            'role': 'Member',
            'avatar_color': 0xFF8B5CF6,
            'is_active': true,
            'joined_at': DateTime.now().toIso8601String(),
          });
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST204' || e.message.contains('member_name')) {
            await _client.from('room_members').insert({
              'room_id': room.id,
              'user_id': currentUser?.id,
              'name': cleanName,
              'role': 'Member',
              'avatar_color': 0xFF8B5CF6,
              'is_active': true,
              'joined_at': DateTime.now().toIso8601String(),
            });
          } else {
            rethrow;
          }
        }

        try {
          await _client.from('room_activities').insert({
            'room_id': room.id,
            'user_id': currentUser?.id,
            'member_name': cleanName,
            'action_type': 'member_joined',
            'details': '$cleanName joined the room workspace',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        return true;
      } catch (e) {
        debugPrint('Direct join operation failed: $e');
      }
    }

    // 3. Fallback: Use SECURITY DEFINER RPC to redeem invite token
    try {
      final res = await _client.rpc('redeem_room_invite', params: {
        'p_token': cleanToken,
        'p_member_name': cleanName,
      });
      return res != null;
    } catch (e) {
      debugPrint('Error redeeming invite token via RPC: $e');
      return false;
    }
  }

  Future<bool> removeRoomMember(String roomId, String memberId) async {
    final currentUser = _client.auth.currentUser;
    try {
      final memberRow = await _client.from('room_members').select().eq('id', memberId).maybeSingle();
      if (memberRow == null) return false;
      if (memberRow['role'] == 'Owner') return false;

      await _client.from('room_members').update({'is_active': false}).eq('id', memberId);

      final mName = memberRow['member_name'] ?? 'Member';
      await _client.from('room_activities').insert({
        'room_id': roomId,
        'user_id': currentUser?.id,
        'member_name': mName,
        'action_type': 'member_removed',
        'details': '$mName was removed from the room',
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error removing room member in Supabase: $e');
      return false;
    }
  }

  Future<bool> leaveRoom(String roomId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('You are offline or unauthenticated.');
    }

    final rows = await _client.from('room_members').select().eq('room_id', roomId).eq('user_id', currentUser.id);
    if (rows.isEmpty) {
      throw Exception('You are not a member of this room.');
    }

    final memberRow = rows.first;
    if (memberRow['role'] == 'Owner') {
      throw Exception('Room owners cannot leave directly. You can delete the room workspace from settings if you wish to remove it.');
    }

    final memberId = memberRow['id'].toString();
    final memberName = (memberRow['member_name'] ?? memberRow['name'])?.toString() ?? 'Member';

    await _client.from('room_members').update({'is_active': false}).eq('id', memberId);

    try {
      await _client.from('room_activities').insert({
        'room_id': roomId,
        'user_id': currentUser.id,
        'member_name': memberName,
        'action_type': 'member_left',
        'details': '$memberName left the room workspace',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    return true;
  }

  /// Uploads bill receipt image to Supabase Storage bucket 'receipts'.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadReceiptImage({
    required String roomId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final path = 'room_$roomId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      // Upload to Supabase bucket 'receipts'
      await _client.storage.from('receipts').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = _client.storage.from('receipts').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('RoomRepository: Storage bucket upload warning ($e). Fallback to base64 encoding.');
      final b64 = base64Encode(bytes);
      return 'data:image/jpeg;base64,$b64';
    }
  }

  Future<void> addRoomExpense({
    required String roomId,
    required String paidByMemberName,
    required int amountPaise,
    required String description,
    required String splitType,
    required List<CalculatedSplit> splits,
    String? categoryId,
    String? notes,
    String? receiptUrl,
    String? linkedTransactionId,
    DateTime? date,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    final expenseDate = date ?? DateTime.now();

    // Fetch members to map member ids & names accurately to user_ids
    final membersRows = await _client
        .from('room_members')
        .select()
        .eq('room_id', roomId)
        .order('joined_at', ascending: true);

    final membersMap = <int, Map<String, dynamic>>{};
    int idx = 1;
    String? payerUserId;

    for (final m in (membersRows as List)) {
      final map = Map<String, dynamic>.from(m as Map);
      membersMap[idx] = map;
      final mName = (map['member_name'] ?? map['name'])?.toString().trim();
      final uId = map['user_id']?.toString();
      if (mName != null && mName.toLowerCase() == paidByMemberName.trim().toLowerCase()) {
        payerUserId = uId;
      }
      idx++;
    }

    final expRow = await _client.from('room_expenses').insert({
      'room_id': roomId,
      'paid_by_user_id': payerUserId,
      'paid_by_member_name': paidByMemberName,
      'amount_paise': amountPaise,
      'description': description,
      'date': expenseDate.toIso8601String(),
      'split_type': splitType,
      'category_id': categoryId,
      'notes': notes,
      'receipt_url': receiptUrl,
      'linked_transaction_id': linkedTransactionId,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    final expId = expRow['id'].toString();

    for (final split in splits) {
      final memberData = membersMap[split.memberId];
      final memberName = (memberData?['member_name'] ?? memberData?['name'])?.toString() ?? 'Member';
      final memberUserId = memberData?['user_id']?.toString();

      await _client.from('expense_splits').insert({
        'room_expense_id': expId,
        'user_id': memberUserId,
        'member_name': memberName,
        'amount_paise': split.amountPaise,
        'percentage': split.percentage,
        'shares': split.shares,
        'is_paid': false,
      });
    }

    final rupees = (amountPaise / 100.0).toStringAsFixed(0);
    try {
      await _client.from('room_activities').insert({
        'room_id': roomId,
        'user_id': currentUser.id,
        'member_name': paidByMemberName,
        'action_type': 'expense_added',
        'details': '$paidByMemberName added $description (₹$rupees)',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    try {
      final roomRow = await _client.from('rooms').select('name').eq('id', roomId).maybeSingle();
      final roomName = roomRow?['name'] ?? 'Shared Room';
      NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '💸 New Shared Expense in $roomName',
        body: '$paidByMemberName added "$description" (₹$rupees). Split recorded for ${splits.length} members.',
      );
    } catch (_) {}
  }

  Future<void> deleteRoomExpense(String expenseId) async {
    final currentUser = _client.auth.currentUser;
    // Fetch expense row first to get linked transaction ID & info for activity log
    Map<String, dynamic>? expRow;
    try {
      expRow = await _client.from('room_expenses').select('room_id, description, paid_by_member_name, amount_paise, linked_transaction_id').eq('id', expenseId).maybeSingle();
    } catch (_) {}

    await _client.from('expense_splits').delete().eq('room_expense_id', expenseId);
    await _client.from('room_expenses').delete().eq('id', expenseId);

    if (expRow != null) {
      final linkedTxId = expRow['linked_transaction_id']?.toString();
      if (linkedTxId != null && linkedTxId.isNotEmpty) {
        try {
          await _client.from('transactions').delete().eq('id', linkedTxId);
        } catch (_) {}
      }

      final roomId = expRow['room_id']?.toString();
      final desc = expRow['description']?.toString() ?? 'expense';
      final payer = expRow['paid_by_member_name']?.toString() ?? 'Member';
      final paise = (expRow['amount_paise'] as num?)?.toInt() ?? 0;
      final rupees = (paise / 100.0).toStringAsFixed(0);

      if (roomId != null && currentUser != null) {
        try {
          await _client.from('room_activities').insert({
            'room_id': roomId,
            'user_id': currentUser.id,
            'member_name': payer,
            'action_type': 'expense_deleted',
            'details': 'Deleted expense "$desc" (₹$rupees)',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    }
  }

  /// Updates member split allocation for an expense. Only the initiator/payer or owner can call this.
  Future<void> updateRoomExpenseSplits({
    required String expenseId,
    required List<String> selectedMemberNames,
  }) async {
    if (selectedMemberNames.isEmpty) return;

    // Fetch existing expense to get total amount
    final expRow = await _client.from('room_expenses').select('amount_paise').eq('id', expenseId).single();
    final totalPaise = (expRow['amount_paise'] as num).toInt();

    // Equal split calculation
    final memberCount = selectedMemberNames.length;
    final baseSharePaise = totalPaise ~/ memberCount;
    final remainderPaise = totalPaise % memberCount;

    // Delete old splits
    await _client.from('expense_splits').delete().eq('room_expense_id', expenseId);

    // Insert new splits
    final newSplits = <Map<String, dynamic>>[];
    for (int i = 0; i < selectedMemberNames.length; i++) {
      final mName = selectedMemberNames[i];
      final sharePaise = baseSharePaise + (i < remainderPaise ? 1 : 0);
      newSplits.add({
        'room_expense_id': expenseId,
        'member_name': mName,
        'amount_paise': sharePaise,
        'is_paid': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await _client.from('expense_splits').insert(newSplits);
  }

  Future<List<ExpenseWithPayerAndSplits>> getRoomExpenses(String roomId) async {
    try {
      final results = await Future.wait<dynamic>([
        getRoomMembers(roomId),
        _client.from('room_expenses').select('*, expense_splits(*)').eq('room_id', roomId).order('date', ascending: false),
      ]);

      final members = results[0] as List<RoomMemberModel>;
      final currentMemberName = members.firstWhere((m) => m.isCurrentUser, orElse: () => RoomMemberModel(id: '', roomId: roomId, name: '', isCurrentUser: false, role: 'Member', avatarColor: 0)).name.trim().toLowerCase();
      final rows = results[1] as List<dynamic>;

      final list = <ExpenseWithPayerAndSplits>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final exp = RoomExpenseModel.fromMap(map);
        final payerNameClean = exp.paidByMemberName.trim().toLowerCase();
        final isPayerCurrent = currentMemberName.isNotEmpty && payerNameClean == currentMemberName;

        final payer = RoomMemberModel(
          id: 'payer',
          roomId: roomId,
          name: exp.paidByMemberName,
          isCurrentUser: isPayerCurrent,
        );

        final rawSplits = (map['expense_splits'] as List?) ?? [];
        final splits = rawSplits.map((s) => ExpenseSplitModel.fromMap(s as Map<String, dynamic>)).toList();

        list.add(ExpenseWithPayerAndSplits(
          expense: exp,
          payer: payer,
          splits: splits,
        ));
      }
      return list;
    } catch (e) {
      debugPrint('RoomRepository: REST fetch for room expenses failed: $e');
      return [];
    }
  }

  Stream<List<ExpenseWithPayerAndSplits>> watchRoomExpenses(String roomId) {
    return safeSupabaseStream<List<ExpenseWithPayerAndSplits>>(
      fetchRest: () => getRoomExpenses(roomId),
      streamRealtime: () {
        return _client
            .from('room_expenses')
            .stream(primaryKey: ['id'])
            .eq('room_id', roomId)
            .order('date', ascending: false)
            .asyncMap((_) => getRoomExpenses(roomId));
      },
    );
  }

  Future<List<MemberNetBalance>> calculateRoomBalances(
    String roomId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = await Future.wait<dynamic>([
      getRoomMembers(roomId),
      _client.from('room_expenses').select().eq('room_id', roomId),
      _client.from('settlements').select().eq('room_id', roomId),
    ]);

    final members = results[0] as List<RoomMemberModel>;
    if (members.isEmpty) return [];

    final rawExpenses = results[1] as List<dynamic>;
    final rawSettlements = results[2] as List<dynamic>;
    List<dynamic> expensesRows = rawExpenses;
    List<dynamic> settlementsRows = rawSettlements;

    // Self-repair any historical room_expenses where paid_by_user_id was wrongly set to submitter's user_id instead of the actual payer
    for (final e in rawExpenses) {
      final pName = (e['paid_by_member_name'] ?? e['paid_by_name'])?.toString().trim();
      final pUid = e['paid_by_user_id']?.toString();
      if (pName != null && pName.isNotEmpty) {
        final match = members.firstWhere(
          (m) => m.name.trim().toLowerCase() == pName.toLowerCase(),
          orElse: () => RoomMemberModel(id: '', roomId: roomId, name: '', isCurrentUser: false, role: 'Member', avatarColor: 0),
        );
        if (match.name.isNotEmpty) {
          if (match.userId != null && match.userId != pUid) {
            _client.from('room_expenses').update({'paid_by_user_id': match.userId}).eq('id', e['id']).then((_) {}).catchError((_) {});
            e['paid_by_user_id'] = match.userId;
          } else if (match.userId == null && pUid != null) {
            _client.from('room_expenses').update({'paid_by_user_id': null}).eq('id', e['id']).then((_) {}).catchError((_) {});
            e['paid_by_user_id'] = null;
          }
        }
      }
    }

    if (startDate != null) {
      expensesRows = rawExpenses.where((e) {
        final dateStr = e['date']?.toString() ?? e['created_at']?.toString();
        if (dateStr == null) return true;
        final d = DateTime.tryParse(dateStr);
        if (d == null) return true;
        if (d.isBefore(startDate)) return false;
        if (endDate != null && d.isAfter(endDate)) return false;
        return true;
      }).toList();

      settlementsRows = rawSettlements.where((s) {
        final dateStr = s['created_at']?.toString();
        if (dateStr == null) return true;
        final d = DateTime.tryParse(dateStr);
        if (d == null) return true;
        if (d.isBefore(startDate)) return false;
        if (endDate != null && d.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    final expenseIds = expensesRows.map((e) => e['id'].toString()).toList();
    final splitsRows = expenseIds.isNotEmpty
        ? await _client.from('expense_splits').select().inFilter('room_expense_id', expenseIds)
        : [];

    final settlements = settlementsRows.map((s) => SettlementModel.fromMap(s as Map<String, dynamic>)).toList();

    final balances = <MemberNetBalance>[];

    for (final m in members) {
      int totalPaid = 0;
      int totalShare = 0;
      int settledPaid = 0;
      int settledReceived = 0;

      final mNameClean = m.name.trim().toLowerCase();
      final mUid = m.userId?.trim();

      for (final e in expensesRows) {
        final paidName = (e['paid_by_member_name'] ?? e['paid_by_name'] ?? e['member_name'])?.toString().trim().toLowerCase();
        final paidUid = (e['paid_by_user_id'] ?? e['user_id'])?.toString().trim();

        bool isPayer = false;
        if (paidName != null && paidName.isNotEmpty) {
          isPayer = (paidName == mNameClean);
        } else if (paidUid != null && mUid != null && mUid.isNotEmpty) {
          isPayer = (paidUid == mUid);
        }

        if (isPayer) {
          totalPaid += (e['amount_paise'] as num?)?.toInt() ?? 0;
        }
      }

      for (final s in splitsRows) {
        final splitName = s['member_name']?.toString().trim().toLowerCase();
        final splitUid = s['user_id']?.toString().trim();
        final isPaid = s['is_paid'] as bool? ?? false;

        bool isMemberSplit = false;
        if (splitName != null && splitName.isNotEmpty) {
          isMemberSplit = (splitName == mNameClean);
        } else if (splitUid != null && mUid != null && mUid.isNotEmpty) {
          isMemberSplit = (splitUid == mUid);
        }

        if (isMemberSplit && !isPaid) {
          totalShare += (s['amount_paise'] as num?)?.toInt() ?? 0;
        }
      }

      for (final s in settlements) {
        if (s.undoneAt == null) {
          final fromName = s.fromMemberName.trim().toLowerCase();
          final toName = s.toMemberName.trim().toLowerCase();

          if (fromName == mNameClean || (s.fromUserId != null && mUid != null && s.fromUserId == mUid)) {
            settledPaid += s.amountPaise;
          }
          if (toName == mNameClean || (s.toUserId != null && mUid != null && s.toUserId == mUid)) {
            settledReceived += s.amountPaise;
          }
        }
      }

      balances.add(MemberNetBalance(
        memberName: m.name,
        totalPaidPaise: totalPaid,
        totalSharePaise: totalShare,
        totalSettledPaidPaise: settledPaid,
        totalSettledReceivedPaise: settledReceived,
      ));
    }

    return balances;
  }

  Future<void> toggleSplitPaymentStatus({
    required String splitId,
    required bool isPaid,
  }) async {
    final currentUser = _client.auth.currentUser;
    await _client.from('expense_splits').update({
      'is_paid': isPaid,
      'paid_at': isPaid ? DateTime.now().toIso8601String() : null,
    }).eq('id', splitId);

    try {
      final splitRow = await _client.from('expense_splits').select('room_expense_id, member_name, amount_paise').eq('id', splitId).maybeSingle();
      if (splitRow != null) {
        final expId = splitRow['room_expense_id']?.toString();
        final memberName = splitRow['member_name']?.toString() ?? 'Member';
        final paise = (splitRow['amount_paise'] as num?)?.toInt() ?? 0;
        final rupees = (paise / 100.0).toStringAsFixed(0);

        if (expId != null) {
          final expRow = await _client.from('room_expenses').select('room_id, description').eq('id', expId).maybeSingle();
          final roomId = expRow?['room_id']?.toString();
          final desc = expRow?['description']?.toString() ?? 'expense';
          if (roomId != null && currentUser != null) {
            final statusText = isPaid ? 'PAID' : 'UNPAID';
            await _client.from('room_activities').insert({
              'room_id': roomId,
              'user_id': currentUser.id,
              'member_name': memberName,
              'action_type': 'split_payment_toggled',
              'details': '$memberName\'s share of ₹$rupees for "$desc" was marked as $statusText',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }
    } catch (_) {}
  }

  /// Mark settlement with a 30-minute undo window
  Future<List<SettlementModel>> getRoomSettlements(String roomId) async {
    try {
      final rows = await _client.from('settlements').select().eq('room_id', roomId);
      return (rows as List).map((s) => SettlementModel.fromMap(s as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordSettlement({
    required String roomId,
    required String fromMemberName,
    required String toMemberName,
    required int amountPaise,
    String? note,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    final now = DateTime.now();
    final undoExpiresAt = now.add(const Duration(minutes: 30));

    await _client.from('settlements').insert({
      'room_id': roomId,
      'from_user_id': currentUser.id,
      'from_member_name': fromMemberName,
      'to_member_name': toMemberName,
      'amount_paise': amountPaise,
      'settled_at': now.toIso8601String(),
      'note': note,
      'undo_expires_at': undoExpiresAt.toIso8601String(),
    });

    final rupees = (amountPaise / 100.0).toStringAsFixed(0);
    await _client.from('room_activities').insert({
      'room_id': roomId,
      'user_id': currentUser.id,
      'member_name': fromMemberName,
      'action_type': 'settlement_recorded',
      'details': '$fromMemberName paid ₹$rupees to $toMemberName (30m undo window active)',
      'created_at': now.toIso8601String(),
    });
  }

  /// 30-Minute Undo Settlement Option
  Future<bool> undoSettlement(String settlementId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return false;

    final sRow = await _client.from('settlements').select().eq('id', settlementId).maybeSingle();
    if (sRow == null) return false;

    final model = SettlementModel.fromMap(sRow);
    if (!model.canUndo) {
      throw Exception('The 30-minute undo window for this settlement has expired.');
    }

    await _client.from('settlements').update({
      'undone_at': DateTime.now().toIso8601String(),
      'undone_by': currentUser.id,
    }).eq('id', settlementId);

    await _client.from('room_activities').insert({
      'room_id': model.roomId,
      'user_id': currentUser.id,
      'member_name': model.fromMemberName,
      'action_type': 'settlement_undone',
      'details': 'Undid settlement of ₹${model.amountRupees.toStringAsFixed(0)} between ${model.fromMemberName} and ${model.toMemberName}',
      'created_at': DateTime.now().toIso8601String(),
    });

    return true;
  }

  Future<List<RoomActivityModel>> getRoomActivities(String roomId) async {
    try {
      final rows = await _client
          .from('room_activities')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false);
      return (rows as List).map((r) => RoomActivityModel.fromMap(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('RoomRepository: REST fetch for room activities failed: $e');
      return [];
    }
  }

  Stream<List<RoomActivityModel>> watchRoomActivities(String roomId) {
    return safeSupabaseStream<List<RoomActivityModel>>(
      fetchRest: () => getRoomActivities(roomId),
      streamRealtime: () {
        return _client
            .from('room_activities')
            .stream(primaryKey: ['id'])
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .map((rows) => rows.map((r) => RoomActivityModel.fromMap(r)).toList());
      },
    );
  }

  /// Fetch room members with deduplication
  Future<List<RoomMemberModel>> getRoomMembers(String roomId) async {
    final activeUserId = _client.auth.currentUser?.id;
    try {
      final membersRows = await _client.from('room_members').select().eq('room_id', roomId);
      final roomRow = await _client.from('rooms').select('created_by').eq('id', roomId).maybeSingle();
      final ownerUserId = roomRow?['created_by']?.toString();

      final list = (membersRows as List)
          .where((m) {
            final isOwnerRow = (m['role'] == 'Owner') || (ownerUserId != null && m['user_id']?.toString() == ownerUserId);
            return isOwnerRow || m['is_active'] != false;
          })
          .map((m) {
            final map = Map<String, dynamic>.from(m as Map);
            final isOwnerRow = (map['role'] == 'Owner') || (ownerUserId != null && map['user_id']?.toString() == ownerUserId);
            if (isOwnerRow) {
              map['role'] = 'Owner';
              map['is_active'] = true;
            }
            return RoomMemberModel.fromMap(map, activeUserId: activeUserId);
          })
          .toList();

      final memberMap = <String, RoomMemberModel>{};
      for (final member in list) {
        final nameKey = member.name.trim().toLowerCase();
        final userKey = member.userId != null && member.userId!.isNotEmpty ? 'uid_${member.userId}' : null;

        if (userKey != null && memberMap.containsKey(userKey)) {
          final existing = memberMap[userKey]!;
          if (existing.role != 'Owner' && member.role == 'Owner') {
            memberMap[userKey] = member;
          }
        } else if (memberMap.containsKey(nameKey)) {
          final existing = memberMap[nameKey]!;
          if (existing.userId == null && member.userId != null) {
            memberMap[nameKey] = member;
          }
        } else {
          final key = userKey ?? nameKey;
          memberMap[key] = member;
        }
      }
      return memberMap.values.toList();
    } catch (e) {
      debugPrint('RoomRepository: Fetch room members failed: $e');
      return [];
    }
  }

  /// Watch room members in real time via Supabase Realtime subscription
  Stream<List<RoomMemberModel>> watchRoomMembers(String roomId) {
    return safeSupabaseStream<List<RoomMemberModel>>(
      fetchRest: () => getRoomMembers(roomId),
      streamRealtime: () {
        return _client
            .from('room_members')
            .stream(primaryKey: ['id'])
            .eq('room_id', roomId)
            .asyncMap((_) => getRoomMembers(roomId));
      },
    );
  }

  /// Fetch calculated Member Financial Summaries (Dues, Paid, Owe, Net Balance, Status)
  Future<List<MemberFinancialSummary>> getMemberFinancialSummaries(String roomId) async {
    final members = await getRoomMembers(roomId);
    final balances = await calculateRoomBalances(roomId);

    final result = <MemberFinancialSummary>[];
    for (final member in members) {
      final bal = balances.firstWhere(
        (b) => b.memberName == member.name,
        orElse: () => MemberNetBalance(
          memberName: member.name,
          totalPaidPaise: 0,
          totalSharePaise: 0,
          totalSettledPaidPaise: 0,
          totalSettledReceivedPaise: 0,
        ),
      );

      result.add(MemberFinancialSummary(
        member: member,
        totalDuesPaise: bal.totalSharePaise,
        totalPaidPaise: bal.totalPaidPaise,
        netBalancePaise: bal.netBalancePaise,
      ));
    }
    return result;
  }

  /// Watch Member Financial Summaries in real time
  Stream<List<MemberFinancialSummary>> watchRoomMemberFinancials(String roomId) {
    return safeSupabaseStream<List<MemberFinancialSummary>>(
      fetchRest: () => getMemberFinancialSummaries(roomId),
      streamRealtime: () {
        return _client
            .from('room_members')
            .stream(primaryKey: ['id'])
            .eq('room_id', roomId)
            .asyncMap((_) => getMemberFinancialSummaries(roomId));
      },
    );
  }

  /// Delete room (Owner Only)
  Future<bool> deleteRoom(String roomId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('You\'re offline or unauthenticated. Reconnect to continue.');
    }

    final roomRow = await _client.from('rooms').select().eq('id', roomId).maybeSingle();
    if (roomRow == null) return false;

    if (roomRow['created_by'] != currentUser.id) {
      throw Exception('Only the room owner can delete this room.');
    }

    await _client.from('rooms').delete().eq('id', roomId).eq('created_by', currentUser.id);
    return true;
  }
}
