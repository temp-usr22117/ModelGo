class WebSearchResult {
  const WebSearchResult({
    required this.title,
    required this.url,
    required this.extract,
  });

  final String title;
  final Uri url;
  final String extract;
}
