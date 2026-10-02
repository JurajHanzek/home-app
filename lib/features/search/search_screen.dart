import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'search_repository.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.archive = false, super.key});
  final bool archive;
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  List<EntityResult> _results = [];
  bool _loading = false, _failed = false, _hasMore = false, _searched = false;
  int _generation = 0;
  String _submitted = '';
  @override
  void initState() {
    super.initState();
    if (widget.archive) _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    if (!more) _submitted = _query.text.trim();
    setState(() {
      _loading = true;
      _failed = false;
      _searched = widget.archive || _submitted.isNotEmpty;
      if (!more) _results = [];
    });
    try {
      final rows = await ref
          .read(searchRepositoryProvider)
          .find(
            query: _submitted,
            archive: widget.archive,
            offset: more ? _results.length : 0,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = [..._results, ...rows];
        _hasMore = rows.length == SearchRepository.pageSize;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.archive ? 'Archive' : 'Search'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (!widget.archive)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search your household',
                  hintText: 'Tasks, recipes, meals, events, expenses',
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: () => _load(),
                  ),
                ),
                onSubmitted: (_) => _load(),
                onChanged: (text) {
                  if (text.trim().isEmpty) _load();
                },
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_failed) ...[
                    const Text(
                      'Could not load records. Check your connection and Phase 7 setup.',
                    ),
                    TextButton(
                      onPressed: () => _load(more: _results.isNotEmpty),
                      child: const Text('Retry'),
                    ),
                  ] else if (!_loading && _results.isEmpty)
                    Text(
                      !_searched
                          ? 'Search active and archived household records.'
                          : widget.archive
                          ? 'Nothing archived yet.'
                          : 'No results found.',
                    ),
                  for (final type in EntityType.values)
                    if (_results.any((item) => item.type == type)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          type.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      for (final item in _results.where(
                        (item) => item.type == type,
                      ))
                        Card(
                          child: ListTile(
                            title: Text(item.title),
                            subtitle: item.archived
                                ? const Text('Archived · Open to restore')
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await context.push(item.route);
                              if (mounted) _load();
                            },
                          ),
                        ),
                    ],
                  if (_hasMore && !_loading && !_failed)
                    TextButton(
                      onPressed: () => _load(more: true),
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
