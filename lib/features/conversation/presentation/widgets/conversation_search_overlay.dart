import 'package:flutter/material.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/l10n/l10n.dart';

class ConversationSearchBar extends StatefulWidget {
  const ConversationSearchBar({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  final ConversationDetailState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  @override
  State<ConversationSearchBar> createState() => ConversationSearchBarState();
}

class ConversationSearchBarState extends State<ConversationSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchCount = widget.state.searchMatchIds.length;
    final currentMatch = widget.state.currentSearchMatchIndex;

    return Container(
      key: const ValueKey('conversation-search-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('conversation-search-input'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.conversationSearchHint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (matchCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${currentMatch + 1}/$matchCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (matchCount > 1) ...[
            IconButton(
              key: const ValueKey('search-previous'),
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              tooltip: context.l10n.conversationSearchPrevious,
              onPressed: widget.onPrevious,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              key: const ValueKey('search-next'),
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              tooltip: context.l10n.conversationSearchNext,
              onPressed: widget.onNext,
              visualDensity: VisualDensity.compact,
            ),
          ],
          IconButton(
            key: const ValueKey('search-close'),
            icon: const Icon(Icons.close, size: 20),
            tooltip: context.l10n.conversationSearchClose,
            onPressed: widget.onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
