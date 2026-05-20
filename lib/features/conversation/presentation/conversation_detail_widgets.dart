/// Barrel file re-exporting all widget files extracted from
/// `conversation_detail_page.dart` (#639 page split).
///
/// External callers should import this barrel (or the page itself)
/// rather than reaching into the internal `widgets/` paths directly.
library;

export 'widgets/conversation_attachment_renderers.dart';
export 'widgets/conversation_composer.dart';
export 'widgets/conversation_message_card.dart';
export 'widgets/conversation_message_list.dart';
export 'widgets/conversation_reactions.dart';
export 'widgets/conversation_search_overlay.dart';
export 'widgets/conversation_selection_bar.dart';
