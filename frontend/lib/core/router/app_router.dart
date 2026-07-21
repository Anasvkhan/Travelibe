import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Shell components/placeholders for features
import '../../features/auth/auth_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/plans/plans_screen.dart';
import '../../features/chat/inbox_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/explore/flight_results_screen.dart';
import '../../features/explore/flight_checkout_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/navigation/shell_layout.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),
      // ShellRoute for screens showing the bottom navigation bar (including Chat Detail)
      ShellRoute(
        builder: (context, state, child) => ShellLayout(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/plans',
            builder: (context, state) => const PlansScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const InboxScreen(),
          ),
          GoRoute(
            path: '/chat/detail',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/flights/results',
            builder: (context, state) {
              final searchParams = state.extra as Map<String, dynamic>? ?? {};
              return FlightResultsScreen(searchParams: searchParams);
            },
          ),
          GoRoute(
            path: '/flights/checkout',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final offer = extra['offer'] as Map<String, dynamic>? ?? {};
              return FlightCheckoutScreen(offer: offer);
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
