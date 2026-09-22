import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_assistant_service.dart';
import 'app_providers.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String? sourceType;
  final dynamic factData;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.sourceType,
    this.factData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiAssistantState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final int questionsAskedCount;
  final int maxHourlyQuestions;

  AiAssistantState({
    required this.messages,
    this.isLoading = false,
    this.error,
    this.questionsAskedCount = 0,
    this.maxHourlyQuestions = 10,
  });

  AiAssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    int? questionsAskedCount,
    int? maxHourlyQuestions,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      questionsAskedCount: questionsAskedCount ?? this.questionsAskedCount,
      maxHourlyQuestions: maxHourlyQuestions ?? this.maxHourlyQuestions,
    );
  }
}

class AiAssistantNotifier extends StateNotifier<AiAssistantState> {
  final AiAssistantService _service;

  AiAssistantNotifier(this._service)
      : super(AiAssistantState(
          messages: [
            ChatMessage(
              id: 'welcome',
              text: '👋 Hello! I am your AI Financial Assistant.\n\nAsk me anything about your spending, who owes you, budget status, or personal finance breakdown!',
              isUser: false,
              sourceType: 'database',
            ),
          ],
        ));

  Future<void> sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty) return;

    // Rate limiting check
    if (state.questionsAskedCount >= state.maxHourlyQuestions) {
      state = state.copyWith(
        error: 'Hourly rate limit reached (${state.maxHourlyQuestions} questions/hour). Please try again later.',
      );
      return;
    }

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: prompt,
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
      questionsAskedCount: state.questionsAskedCount + 1,
    );

    final response = await _service.askAssistant(prompt);

    final aiMsg = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      text: response.answer,
      isUser: false,
      sourceType: response.sourceType,
      factData: response.factData,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMsg],
      isLoading: false,
      error: response.isError ? response.answer : null,
    );
  }

  void clearChat() {
    state = AiAssistantState(
      messages: [
        ChatMessage(
          id: 'welcome',
          text: '👋 Hello! I am your AI Financial Assistant.\n\nAsk me anything about your spending, who owes you, budget status, or personal finance breakdown!',
          isUser: false,
          sourceType: 'database',
        ),
      ],
      questionsAskedCount: state.questionsAskedCount,
    );
  }
}

final aiAssistantNotifierProvider = StateNotifierProvider<AiAssistantNotifier, AiAssistantState>((ref) {
  return AiAssistantNotifier(ref.watch(aiAssistantServiceProvider));
});
