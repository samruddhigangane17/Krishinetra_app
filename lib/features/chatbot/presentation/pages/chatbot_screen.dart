import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/auth/domain/models/language_model.dart';
import 'package:krishinetra/features/recommendation/data/gemini_service.dart';

/// Standalone farming assistant chat — unlike the "Ask Agronomist" panel
/// on a soil report (which only answers questions about that one
/// assessment), this is open-ended: crop choice, sowing timing, pest
/// identification, scheme questions, anything farming-related, with no
/// report required first.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({required this.language, super.key});

  final LanguageOption language;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatTurn> _turns = [];
  bool _isSending = false;

  static const List<String> _suggestions = [
    'Which crop suits sandy soil?',
    'Best time to sow wheat?',
    'How do I control aphids organically?',
    'What is PM-KISAN?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    final List<ChatTurn> historyForPrompt = List.of(_turns);

    setState(() {
      _turns.add(ChatTurn(text: trimmed, isUser: true));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final String answer = await geminiAgriService.chat(
      message: trimmed,
      history: historyForPrompt,
      language: widget.language,
    );

    if (!mounted) return;
    setState(() {
      _turns.add(ChatTurn(text: answer, isUser: false));
      _isSending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Farming Assistant', style: textTheme.titleLarge),
                    Text(
                      'Ask anything about crops, soil, or schemes',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _turns.isEmpty
              ? _EmptyState(
                  suggestions: _suggestions,
                  onSuggestionTap: _send,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: _turns.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _turns.length) {
                      return const _TypingBubble();
                    }
                    return _ChatBubble(turn: _turns[index]);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isSending,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type your question…',
                  ),
                  onSubmitted: _send,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: _isSending ? null : () => _send(_controller.text),
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.suggestions, required this.onSuggestionTap});

  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.14),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppColors.secondary,
                size: 34,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ask me anything about farming',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: suggestions
                  .map(
                    (s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.surfaceVariant,
                      onPressed: () => onSuggestionTap(s),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.turn});

  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isUser = turn.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadii.chip),
            topRight: const Radius.circular(AppRadii.chip),
            bottomLeft: Radius.circular(isUser ? AppRadii.chip : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppRadii.chip),
          ),
          border: isUser
              ? null
              : Border.all(color: AppColors.outline.withOpacity(0.6)),
        ),
        child: Text(
          turn.text,
          style: textTheme.bodyMedium?.copyWith(
            color: isUser ? Colors.white : AppColors.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: AppColors.outline.withOpacity(0.6)),
        ),
        child: const SizedBox(
          width: 24,
          height: 12,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
