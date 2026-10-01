import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/home/home_screen.dart';
import '../features/shared/module_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeHubNavigation(navigationShell: navigationShell),
        branches: [
          _branch('/home', const HomeScreen()),
          _branch('/tasks', const ModuleScreen(title: 'Tasks')),
          _branch('/meals', const ModuleScreen(title: 'Meals & Recipes')),
          _branch('/calendar', const ModuleScreen(title: 'Calendar')),
          _branch('/shopping', const ModuleScreen(title: 'Shopping')),
        ],
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ModuleScreen(title: 'Expenses'),
      ),
    ],
  );
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
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
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
    );
  }
}
