import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/search/search_screen.dart';
import '../features/search/search_repository.dart';
import '../features/search/entity_details_screen.dart';
import '../features/activity/activity_screen.dart';
import '../core/theme/flower_navigation_frame.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/expenses/presentation/expenses_screen.dart';
import '../features/home/home_screen.dart';
import '../features/meals/presentation/meals_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shopping/presentation/shopping_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      const accessRoutes = {
        '/sign-in',
        '/loading',
        '/household-required',
        '/account-unavailable',
      };
      final location = state.matchedLocation;
      final authState = ref.read(authSessionProvider);

      if (authState.hasError) {
        return location == '/account-unavailable'
            ? null
            : '/account-unavailable';
      }
      if (!authState.hasValue) {
        return location == '/loading' ? null : '/loading';
      }
      if (authState.value == null) {
        return location == '/sign-in' ? null : '/sign-in';
      }

      final membership = ref.read(householdMembershipProvider);
      if (membership.hasError) {
        return location == '/account-unavailable'
            ? null
            : '/account-unavailable';
      }
      if (membership.isLoading) {
        return location == '/loading' ? null : '/loading';
      }
      if (membership.value == null) {
        return location == '/household-required' ? null : '/household-required';
      }
      return accessRoutes.contains(location) ? '/home' : null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _AuthLoadingScreen(),
      ),
      GoRoute(
        path: '/household-required',
        builder: (context, state) => const HouseholdRequiredScreen(),
      ),
      GoRoute(
        path: '/account-unavailable',
        builder: (context, state) => const AccountUnavailableScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeHubNavigation(navigationShell: navigationShell),
        branches: [
          _branch('/home', const HomeScreen()),
          _branch('/tasks', const TasksScreen()),
          _branch('/meals', const MealsScreen()),
          _branch('/calendar', const CalendarScreen()),
          _branch('/shopping', const ShoppingScreen()),
        ],
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/archive',
        builder: (_, _) => const SearchScreen(archive: true),
      ),
      GoRoute(path: '/activity', builder: (_, _) => const ActivityScreen()),
      GoRoute(
        path: '/entity/:type/:id',
        builder: (_, state) => EntityDetailsScreen(
          type: EntityType.values.byName(state.pathParameters['type']!),
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/settings-options',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.listen(authSessionProvider, (_, _) => router.refresh());
  ref.listen(householdMembershipProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}

class HomeHubNavigation extends ConsumerWidget {
  const HomeHubNavigation({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeHub'),
        actions: [
          IconButton(
            tooltip: theme == HomeHubTheme.dark
                ? 'Switch to Flower Mode'
                : 'Switch to Dark Mode',
            onPressed: ref.read(themeControllerProvider.notifier).toggle,
            icon: Icon(
              theme == HomeHubTheme.dark
                  ? Icons.local_florist_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Settings and options',
            onPressed: () => context.push('/settings-options'),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: FlowerNavigationFrame(
        enabled: theme == HomeHubTheme.flower,
        selectedIndex: navigationShell.currentIndex,
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              label: 'Meals',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              label: 'Shopping',
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
