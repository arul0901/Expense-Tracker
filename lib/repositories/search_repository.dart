import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/theme/app_colors.dart';
import '../core/models/search_result_model.dart';

class SearchRepository {
  final SupabaseClient _client;

  SearchRepository(this._client);

  String? get _activeUserId => _client.auth.currentUser?.id;

  /// Main Global Search Engine
  Future<List<SearchResultModel>> searchEverything({
    required String query,
    SearchCategory categoryFilter = SearchCategory.all,
  }) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];

    final results = <SearchResultModel>[];
    final activeUserId = _activeUserId;
    if (activeUserId == null) return [];

    // Parse potential numeric amount from query (e.g. "500", "₹500", "500.00")
    final cleanNumericStr = trimmed.replaceAll('₹', '').replaceAll(',', '').trim();
    final parsedAmount = double.tryParse(cleanNumericStr);
    final parsedPaise = parsedAmount != null ? (parsedAmount * 100).round() : null;

    // Parse potential date/month keywords
    final monthNumber = _parseMonthFromQuery(trimmed);

    final futures = <Future<List<SearchResultModel>>>[];

    // 1. Search Transactions
    if (categoryFilter == SearchCategory.all || categoryFilter == SearchCategory.transaction) {
      futures.add(_searchTransactions(trimmed, parsedPaise, monthNumber, activeUserId));
    }

    // 2. Search Rooms
    if (categoryFilter == SearchCategory.all || categoryFilter == SearchCategory.room) {
      futures.add(_searchRooms(trimmed, activeUserId));
    }

    // 3. Search Events
    if (categoryFilter == SearchCategory.all || categoryFilter == SearchCategory.event) {
      futures.add(_searchEvents(trimmed, activeUserId));
    }

    // 4. Search Reminders
    if (categoryFilter == SearchCategory.all || categoryFilter == SearchCategory.reminder) {
      futures.add(_searchReminders(trimmed, parsedPaise, activeUserId));
    }

    // 5. Search Tasks
    if (categoryFilter == SearchCategory.all || categoryFilter == SearchCategory.task) {
      futures.add(_searchTasks(trimmed, activeUserId));
    }

    final queryResultsList = await Future.wait(futures);
    for (final list in queryResultsList) {
      results.addAll(list);
    }

    // Relevance Ranking Algorithm:
    // 1. Exact title match
    // 2. Title starts with query
    // 3. Substring in title
    // 4. Match in category/note/context
    // 5. Date order (newest first)
    results.sort((a, b) {
      final scoreA = _calculateRelevanceScore(a, trimmed);
      final scoreB = _calculateRelevanceScore(b, trimmed);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Higher score first
      }
      final dateA = a.date ?? DateTime(2000);
      final dateB = b.date ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return results;
  }

  int _calculateRelevanceScore(SearchResultModel item, String query) {
    final titleLower = item.title.toLowerCase();
    final subtitleLower = item.subtitle.toLowerCase();
    final contextLower = (item.contextInfo ?? '').toLowerCase();

    if (titleLower == query) return 100;
    if (titleLower.startsWith(query)) return 80;
    if (titleLower.contains(query)) return 60;
    if (subtitleLower.contains(query)) return 40;
    if (contextLower.contains(query)) return 20;
    return 10;
  }

  int? _parseMonthFromQuery(String query) {
    const monthMap = {
      'january': 1, 'jan': 1,
      'february': 2, 'feb': 2,
      'march': 3, 'mar': 3,
      'april': 4, 'apr': 4,
      'may': 5,
      'june': 6, 'jun': 6,
      'july': 7, 'jul': 7,
      'august': 8, 'aug': 8,
      'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10,
      'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };
    for (final entry in monthMap.entries) {
      if (query.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  // 1. Transactions Search Engine
  Future<List<SearchResultModel>> _searchTransactions(
    String query,
    int? parsedPaise,
    int? monthNumber,
    String activeUserId,
  ) async {
    final list = <SearchResultModel>[];
    try {
      var dbQuery = _client
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', activeUserId);

      final rows = await dbQuery;
      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final note = (map['note'] as String?) ?? '';
        final catMap = map['categories'] as Map<String, dynamic>?;
        final catName = catMap?['name']?.toString() ?? 'Uncategorized';
        final amountPaise = (map['amount_paise'] as num?)?.toInt() ?? 0;
        final amountRupees = amountPaise / 100.0;
        final type = map['type']?.toString() ?? 'expense';
        final paymentMethod = map['payment_method']?.toString() ?? 'UPI';
        final dateStr = map['date']?.toString();
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

        bool isMatch = false;

        if (note.toLowerCase().contains(query) ||
            catName.toLowerCase().contains(query) ||
            paymentMethod.toLowerCase().contains(query) ||
            type.toLowerCase().contains(query)) {
          isMatch = true;
        }

        if (parsedPaise != null && (amountPaise == parsedPaise || amountRupees.toStringAsFixed(0) == parsedPaise.toString())) {
          isMatch = true;
        }

        if (monthNumber != null && date != null && date.month == monthNumber) {
          isMatch = true;
        }

        if (isMatch) {
          list.add(SearchResultModel(
            id: map['id']?.toString() ?? '',
            category: SearchCategory.transaction,
            title: catName,
            subtitle: note.isNotEmpty ? note : '${dateFormatterShort(date)} • ${paymentMethod.toUpperCase()}',
            amountRupees: amountRupees,
            amountType: type,
            date: date,
            contextInfo: '${dateFormatterShort(date)} • ${paymentMethod.toUpperCase()}',
            deepLinkRoute: '/transactions',
            icon: type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
            iconColor: type == 'income' ? AppColors.income : AppColors.expense,
            metadata: map,
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  // 2. Rooms Search Engine
  Future<List<SearchResultModel>> _searchRooms(String query, String activeUserId) async {
    final list = <SearchResultModel>[];
    try {
      final rows = await _client.from('rooms').select('*, room_members(*)');
      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final name = (map['name'] as String?) ?? '';
        final description = (map['description'] as String?) ?? '';
        final type = (map['type'] as String?) ?? 'Trip';
        final colorHex = (map['color_accent'] as num?)?.toInt() ?? 0xFF0D9488;
        final membersList = (map['room_members'] as List?) ?? [];

        final memberNames = membersList.map((m) => (m as Map<String, dynamic>)['name']?.toString() ?? '').toList();
        final isMemberOfRoom = membersList.any((m) {
          final memberUserId = (m as Map<String, dynamic>)['user_id']?.toString();
          return memberUserId == activeUserId;
        });

        // Enforce RLS authorization check
        if (!isMemberOfRoom && map['created_by'] != activeUserId) {
          continue;
        }

        bool isMatch = name.toLowerCase().contains(query) ||
            description.toLowerCase().contains(query) ||
            type.toLowerCase().contains(query) ||
            memberNames.any((m) => m.toLowerCase().contains(query));

        if (isMatch) {
          list.add(SearchResultModel(
            id: map['id']?.toString() ?? '',
            category: SearchCategory.room,
            title: name,
            subtitle: '${memberNames.length} members • $type',
            contextInfo: memberNames.isNotEmpty ? 'Members: ${memberNames.join(', ')}' : null,
            deepLinkRoute: '/rooms/${map['id']}',
            icon: Icons.groups_outlined,
            iconColor: Color(colorHex),
            metadata: map,
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  // 3. Events Search Engine
  Future<List<SearchResultModel>> _searchEvents(String query, String activeUserId) async {
    final list = <SearchResultModel>[];
    try {
      final rows = await _client.from('events').select().eq('user_id', activeUserId);
      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final title = (map['title'] as String?) ?? '';
        final description = (map['description'] as String?) ?? '';
        final category = (map['category'] as String?) ?? 'Event';
        final dateStr = map['start_date']?.toString();
        final startDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        if (title.toLowerCase().contains(query) ||
            description.toLowerCase().contains(query) ||
            category.toLowerCase().contains(query)) {
          list.add(SearchResultModel(
            id: map['id']?.toString() ?? '',
            category: SearchCategory.event,
            title: title,
            subtitle: description.isNotEmpty ? description : category,
            date: startDate,
            contextInfo: startDate != null ? DateFormat('MMM d, yyyy').format(startDate) : null,
            deepLinkRoute: '/events',
            icon: Icons.event_outlined,
            iconColor: AppColors.income,
            metadata: map,
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  // 4. Reminders Search Engine
  Future<List<SearchResultModel>> _searchReminders(String query, int? parsedPaise, String activeUserId) async {
    final list = <SearchResultModel>[];
    try {
      final rows = await _client.from('reminders').select('*, categories(*)').eq('user_id', activeUserId);
      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final title = (map['title'] as String?) ?? '';
        final note = (map['note'] as String?) ?? '';
        final catMap = map['categories'] as Map<String, dynamic>?;
        final catName = catMap?['name']?.toString() ?? 'Reminder';
        final amountPaise = (map['amount_paise'] as num?)?.toInt() ?? 0;
        final amountRupees = amountPaise / 100.0;
        final dateStr = map['due_date']?.toString();
        final dueDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
        final isCompleted = map['is_completed'] == true;

        bool isMatch = title.toLowerCase().contains(query) ||
            note.toLowerCase().contains(query) ||
            catName.toLowerCase().contains(query);

        if (parsedPaise != null && (amountPaise == parsedPaise || amountRupees.toStringAsFixed(0) == parsedPaise.toString())) {
          isMatch = true;
        }

        if (isMatch) {
          list.add(SearchResultModel(
            id: map['id']?.toString() ?? '',
            category: SearchCategory.reminder,
            title: title,
            subtitle: isCompleted ? 'Completed' : (dueDate != null ? 'Due: ${DateFormat('dd MMM yyyy').format(dueDate)}' : catName),
            amountRupees: amountRupees > 0 ? amountRupees : null,
            amountType: 'expense',
            date: dueDate,
            contextInfo: isCompleted ? 'Completed ✓' : 'Pending',
            deepLinkRoute: '/reminders',
            icon: Icons.notifications_active_outlined,
            iconColor: Colors.orange,
            metadata: map,
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  // 5. Tasks Search Engine
  Future<List<SearchResultModel>> _searchTasks(String query, String activeUserId) async {
    final list = <SearchResultModel>[];
    try {
      final rows = await _client.from('room_tasks').select('*, rooms(*)');
      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final title = (map['title'] as String?) ?? '';
        final notes = (map['notes'] as String?) ?? '';
        final priority = (map['priority'] as String?) ?? 'Normal';
        final status = (map['status'] as String?) ?? 'Pending';
        final roomMap = map['rooms'] as Map<String, dynamic>?;
        final roomName = roomMap?['name']?.toString();
        final roomId = map['room_id']?.toString();

        bool isMatch = title.toLowerCase().contains(query) ||
            notes.toLowerCase().contains(query) ||
            priority.toLowerCase().contains(query) ||
            status.toLowerCase().contains(query) ||
            (roomName != null && roomName.toLowerCase().contains(query));

        if (isMatch) {
          list.add(SearchResultModel(
            id: map['id']?.toString() ?? '',
            category: SearchCategory.task,
            title: title,
            subtitle: roomName != null ? 'Room: $roomName • Priority: $priority' : 'Personal Task • Priority: $priority',
            contextInfo: status == 'Completed' ? 'Completed ✓' : 'Pending Task',
            deepLinkRoute: roomId != null ? '/rooms/$roomId' : '/to-do',
            icon: Icons.task_alt_outlined,
            iconColor: priority == 'Urgent' ? AppColors.expense : AppColors.primary,
            metadata: map,
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  // --- Recent Searches Storage in Supabase ---
  Future<List<String>> getRecentSearches() async {
    final activeUserId = _activeUserId;
    if (activeUserId == null) return [];
    try {
      final rows = await _client
          .from('user_search_history')
          .select('query')
          .eq('user_id', activeUserId)
          .order('created_at', ascending: false)
          .limit(10);
      return (rows as List).map((r) => r['query'].toString()).toSet().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    final activeUserId = _activeUserId;
    if (trimmed.isEmpty || activeUserId == null) return;
    try {
      await _client.from('user_search_history').insert({
        'user_id': activeUserId,
        'query': trimmed,
      });
    } catch (_) {}
  }

  Future<void> clearRecentSearches() async {
    final activeUserId = _activeUserId;
    if (activeUserId == null) return;
    try {
      await _client.from('user_search_history').delete().eq('user_id', activeUserId);
    } catch (_) {}
  }
}

String dateFormatterShort(DateTime? date) {
  if (date == null) return '';
  return DateFormat('dd MMM yyyy').format(date);
}
