class KnowledgeDocument {
  const KnowledgeDocument({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.importedAt,
    this.chunkCount = 0,
  });

  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime importedAt;
  final int chunkCount;

  String get extension {
    final separatorIndex = name.lastIndexOf('.');
    if (separatorIndex == -1 || separatorIndex == name.length - 1) {
      return '';
    }
    return name.substring(separatorIndex + 1).toLowerCase();
  }

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) {
    return KnowledgeDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      sizeBytes: json['sizeBytes'] as int,
      importedAt: DateTime.parse(json['importedAt'] as String),
      chunkCount: json['chunkCount'] as int? ?? 0,
    );
  }

  KnowledgeDocument copyWith({int? chunkCount}) {
    return KnowledgeDocument(
      id: id,
      name: name,
      path: path,
      sizeBytes: sizeBytes,
      importedAt: importedAt,
      chunkCount: chunkCount ?? this.chunkCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'sizeBytes': sizeBytes,
      'importedAt': importedAt.toIso8601String(),
      'chunkCount': chunkCount,
    };
  }
}
