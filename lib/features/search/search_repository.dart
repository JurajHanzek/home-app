import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EntityType {
  task('Tasks'),
  recipe('Recipes'),
  meal('Meals'),
  event('Calendar Events'),
  expense('Expenses');

  const EntityType(this.label);
  final String label;
}

class EntityResult {
  const EntityResult({
    required this.id,
    required this.type,
    required this.title,
    required this.archived,
  });
  final String id, title;
  final EntityType type;
  final bool archived;
  String get route => '/entity/${type.name}/${Uri.encodeComponent(id)}';
  factory EntityResult.fromJson(Map<String, dynamic> json) => EntityResult(
    id: json['entity_id'] as String,
    type: EntityType.values.byName(json['entity_type'] as String),
    title: json['title'] as String,
    archived: json['archived'] as bool,
  );
}

final searchRepositoryProvider = Provider(
  (ref) => SearchRepository(Supabase.instance.client),
);

class SearchRepository {
  const SearchRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 100;
  Future<List<EntityResult>> find({
    String query = '',
    bool archive = false,
    int offset = 0,
  }) async {
    if (!archive && query.trim().isEmpty) return [];
    final rows = await client
        .rpc(
          'search_household_entities',
          params: {
            'query_text': query.trim(),
            'archived_only': archive,
            'page_offset': offset,
          },
        )
        .timeout(const Duration(seconds: 20));
    return (rows as List)
        .map((row) => EntityResult.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
