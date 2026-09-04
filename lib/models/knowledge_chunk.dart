class KnowledgeChunk {
  const KnowledgeChunk({
    required this.id,
    required this.documentId,
    required this.index,
    required this.content,
  });

  final String id;
  final String documentId;
  final int index;
  final String content;

  factory KnowledgeChunk.fromJson(Map<String, dynamic> json) {
    return KnowledgeChunk(
      id: json['id'] as String,
      documentId: json['documentId'] as String,
      index: json['index'] as int,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'index': index,
      'content': content,
    };
  }
}
