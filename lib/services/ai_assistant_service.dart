import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiAssistantResponse {
  final String answer;
  final String sourceType; // 'database', 'rag', 'hybrid'
  final dynamic factData;
  final List<dynamic>? ragData;
  final DateTime timestamp;
  final bool isError;

  AiAssistantResponse({
    required this.answer,
    required this.sourceType,
    this.factData,
    this.ragData,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiAssistantService {
  final SupabaseClient _client;

  AiAssistantService(this._client);

  Future<AiAssistantResponse> askAssistant(String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      return AiAssistantResponse(
        answer: 'Please enter a valid question.',
        sourceType: 'database',
        isError: true,
      );
    }

    try {
      // 1. Attempt to invoke Supabase Edge Function
      final response = await _client.functions.invoke(
        'financial-ai',
        body: {'prompt': cleanPrompt},
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return AiAssistantResponse(
          answer: data['answer']?.toString() ?? 'No response generated.',
          sourceType: data['source_type']?.toString() ?? 'hybrid',
          factData: data['fact_data'],
          ragData: data['rag_data'] as List<dynamic>?,
        );
      }
    } catch (e) {
      debugPrint(
        'AiAssistantService: Edge function call unavailable, using local RPC fallback: $e',
      );
    }

    // 2. Direct RPC Fallback (Guarantees zero-downtime offline & dev support)
    return await _processLocalRpcFallback(cleanPrompt);
  }

  Future<AiAssistantResponse> _processLocalRpcFallback(String prompt) async {
    final lower = prompt.toLowerCase();
    final now = DateTime.now();
    int targetMonth = now.month;
    int targetYear = now.year;

    final Map<String, int> months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
      'jan ': 1,
      'feb ': 2,
      'mar ': 3,
      'apr ': 4,
      'aug ': 8,
      'sep ': 9,
      'oct ': 10,
      'nov ': 11,
      'dec ': 12,
    };

    for (final entry in months.entries) {
      if (lower.contains(entry.key)) {
        targetMonth = entry.value;
        if (targetMonth > now.month && targetYear == now.year) {
          targetYear = now.year - 1;
        }
        break;
      }
    }

    try {
      if (lower.contains('who owes me') ||
          lower.contains('people owe me') ||
          lower.contains('receivable')) {
        final List<dynamic> res = await _client.rpc('get_people_who_owe_me');
        if (res.isEmpty) {
          return AiAssistantResponse(
            answer:
                'No one currently owes you money. Your receivables balance is ₹0.00.',
            sourceType: 'database',
            factData: res,
          );
        }
        double total = 0;
        final buffer = StringBuffer(
          'Here are the people who owe you money:\n\n',
        );
        for (final item in res) {
          final amt =
              (item['net_receivable_rupees'] as num?)?.toDouble() ?? 0.0;
          total += amt;
          buffer.writeln(
            '• ${item['person_name']} owes you ₹${amt.toStringAsFixed(2)} (${item['room_name'] ?? 'Room'})',
          );
        }
        buffer.writeln('\nTotal Receivable: ₹${total.toStringAsFixed(2)}');
        return AiAssistantResponse(
          answer: buffer.toString().trim(),
          sourceType: 'database',
          factData: res,
        );
      } else if (lower.contains('who do i owe') ||
          lower.contains('i owe') ||
          lower.contains('payable')) {
        final List<dynamic> res = await _client.rpc('get_people_i_owe');
        if (res.isEmpty) {
          return AiAssistantResponse(
            answer:
                'You don\'t owe money to anyone! All your shared dues are clear.',
            sourceType: 'database',
            factData: res,
          );
        }
        double total = 0;
        final buffer = StringBuffer('Here are the dues you currently owe:\n\n');
        for (final item in res) {
          final amt = (item['net_payable_rupees'] as num?)?.toDouble() ?? 0.0;
          total += amt;
          buffer.writeln(
            '• You owe ${item['person_name']} ₹${amt.toStringAsFixed(2)} (${item['room_name'] ?? 'Room'})',
          );
        }
        buffer.writeln('\nTotal Payable: ₹${total.toStringAsFixed(2)}');
        return AiAssistantResponse(
          answer: buffer.toString().trim(),
          sourceType: 'database',
          factData: res,
        );
      } else if (lower.contains('how much did i spend') ||
          lower.contains('this month') ||
          lower.contains('monthly spending') ||
          lower.contains('spend') ||
          lower.contains('spent')) {
        if (lower.contains('room')) {
          // Room expenses
          final start = DateTime(targetYear, targetMonth, 1);
          final end = targetMonth == 12
              ? DateTime(targetYear + 1, 1, 1)
              : DateTime(targetYear, targetMonth + 1, 1);

          final res = await _client
              .from('room_expenses')
              .select('amount_paise, description, date')
              .gte('date', start.toIso8601String())
              .lt('date', end.toIso8601String());

          if ((res as List).isEmpty) {
            return AiAssistantResponse(
              answer:
                  'According to your financial records, there are no recorded group/room expenses for this month.',
              sourceType: 'database',
              factData: res,
            );
          }

          double total = 0;
          for (final item in res) {
            total += ((item['amount_paise'] as num?)?.toDouble() ?? 0) / 100.0;
          }

          return AiAssistantResponse(
            answer:
                'This month you have recorded ₹${total.toStringAsFixed(2)} in room/group expenses.',
            sourceType: 'database',
            factData: res,
          );
        }

        final Map<String, dynamic> data = await _client.rpc(
          'get_monthly_spending',
          params: {'p_month': targetMonth, 'p_year': targetYear},
        );
        final expense =
            (data['total_expense_rupees'] as num?)?.toDouble() ?? 0.0;
        final income = (data['total_income_rupees'] as num?)?.toDouble() ?? 0.0;
        final savings = (data['net_savings_rupees'] as num?)?.toDouble() ?? 0.0;

        return AiAssistantResponse(
          answer:
              'This month you spent ₹${expense.toStringAsFixed(2)} and earned ₹${income.toStringAsFixed(2)}.\nNet Savings: ₹${savings.toStringAsFixed(2)}.',
          sourceType: 'database',
          factData: data,
        );
      } else if (lower.contains('budget') || lower.contains('over budget')) {
        final List<dynamic> res = await _client.rpc('get_budget_status');
        if (res.isEmpty) {
          return AiAssistantResponse(
            answer:
                'No monthly budgets are currently set up. You can create a budget from the Budgets screen.',
            sourceType: 'database',
            factData: res,
          );
        }
        final over = res.where((b) => b['is_over_budget'] == true).toList();
        if (over.isNotEmpty) {
          final names = over
              .map((b) => b['category_name'].toString())
              .join(', ');
          return AiAssistantResponse(
            answer:
                '⚠️ Warning: You have exceeded your set budget limits in: $names.',
            sourceType: 'database',
            factData: res,
          );
        }
        return AiAssistantResponse(
          answer:
              '✅ Great job! You are within budget limits across all set categories.',
          sourceType: 'database',
          factData: res,
        );
      } else if (lower.contains('biggest expense') ||
          lower.contains('largest expense')) {
        final List<dynamic> res = await _client.rpc(
          'get_largest_expenses',
          params: {'p_limit': 5},
        );
        if (res.isEmpty) {
          return AiAssistantResponse(
            answer: 'No expense transactions recorded yet.',
            sourceType: 'database',
            factData: res,
          );
        }
        final buffer = StringBuffer(
          'Here are your largest recorded expenses:\n\n',
        );
        for (final item in res) {
          final amt = (item['amount_rupees'] as num?)?.toDouble() ?? 0.0;
          buffer.writeln(
            '• ₹${amt.toStringAsFixed(2)} - ${item['note'] ?? 'Expense'} (${item['category'] ?? 'General'})',
          );
        }
        return AiAssistantResponse(
          answer: buffer.toString().trim(),
          sourceType: 'database',
          factData: res,
        );
      } else {
        final Map<String, dynamic> data = await _client.rpc(
          'get_monthly_spending',
          params: {'p_month': targetMonth, 'p_year': targetYear},
        );
        final expense =
            (data['total_expense_rupees'] as num?)?.toDouble() ?? 0.0;
        return AiAssistantResponse(
          answer:
              'Based on your verified financial records, you have spent ₹${expense.toStringAsFixed(2)} this month.\n\nTry asking specific questions such as "Who owes me?", "Who do I owe?", "Am I over budget?", or "What is my biggest expense?".',
          sourceType: 'database',
          factData: data,
        );
      }
    } catch (e) {
      return AiAssistantResponse(
        answer:
            'I\'m currently unable to retrieve your financial data ($e). Please check your internet connection and try again.',
        sourceType: 'database',
        isError: true,
      );
    }
  }
}
