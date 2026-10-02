import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/household_membership.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(Supabase.instance.client),
);

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((state) => state.session);
});

final householdMembershipProvider =
    FutureProvider.autoDispose<HouseholdMembership?>((ref) async {
      final authState = ref.watch(authSessionProvider);
      if (!authState.hasValue) return null;

      final session = authState.value;
      if (session == null) return null;

      return ref.watch(authRepositoryProvider).getMembership(session.user.id);
    });

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<HouseholdMembership?> getMembership(String userId) async {
    final row = await _client
        .from('profiles')
        .select(
          'id, household_id, display_name, initials, '
          'households!profiles_household_id_fkey(name)',
        )
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return HouseholdMembership.fromJson(row);
  }
}
