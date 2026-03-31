class ChatSearchResult {
  final String conversationId;
  final bool isGroup;
  final String title;
  final String snippet;
  final DateTime time;

  ChatSearchResult({
    required this.conversationId,
    required this.isGroup,
    required this.title,
    required this.snippet,
    required this.time,
  });
}

