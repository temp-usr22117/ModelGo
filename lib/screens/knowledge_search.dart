import 'package:flutter/material.dart';

import '../models/knowledge_search_result.dart';
import '../services/knowledge_search_service.dart';

class KnowledgeSearchScreen extends StatefulWidget {
  const KnowledgeSearchScreen({super.key, this.searchService});

  final KnowledgeSearchService? searchService;

  @override
  State<KnowledgeSearchScreen> createState() => _KnowledgeSearchScreenState();
}

class _KnowledgeSearchScreenState extends State<KnowledgeSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  late final KnowledgeSearchService _searchService;

  List<KnowledgeSearchResult> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ?? KnowledgeSearchService();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _isSearching) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final results = await _searchService.search(cleanQuery);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = [];
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Knowledge Base')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _queryController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'What do you want to find?',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _isSearching
                        ? null
                        : () => _search(_queryController.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text('Search failed: $_error', textAlign: TextAlign.center),
      );
    }

    if (!_hasSearched) {
      return const _SearchMessage(
        icon: Icons.manage_search_rounded,
        title: 'Search your documents',
        message: 'ModelGo will find the most relevant stored passages.',
      );
    }

    if (_results.isEmpty) {
      return const _SearchMessage(
        icon: Icons.search_off_rounded,
        title: 'No relevant passages found',
        message: 'Try different or more specific keywords.',
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = _results[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.document.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text('Passage ${result.chunk.index + 1}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  result.chunk.content,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  'Matched: ${result.matchedTerms.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
