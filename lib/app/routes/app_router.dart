import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/models/auth_state.dart';
import '../../core/auth/providers/auth_provider.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/events/presentation/events_screen.dart';
import '../../features/main_shell/presentation/main_shell_screen.dart';
import '../../features/more/presentation/more_hub_screen.dart';
import '../../features/reminders/presentation/reminders_screen.dart';
import '../../features/rooms/presentation/join_room_by_token_screen.dart';
import '../../features/rooms/presentation/room_workspace_screen.dart';
import '../../features/rooms/presentation/rooms_landing_screen.dart';
import '../../features/auth/presentation/biometric_lock_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/to_do/presentation/global_to_do_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/search/presentation/global_search_screen.dart';


final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final status = authState.status;
      final loc = state.matchedLocation;

      // Allow splash to run startup sequence
      if (loc == '/splash') return null;

      final isPublicAuthRoute = loc == '/welcome' ||
          loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password';

      if (status == AuthStatus.unknown || status == AuthStatus.authenticating) {
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        return isPublicAuthRoute ? null : '/welcome';
      }

      if (status == AuthStatus.verifyingEmail) {
        return loc == '/verify-email' ? null : '/verify-email';
      }

      if (status == AuthStatus.biometricLocked) {
        return loc == '/biometric-lock' ? null : '/biometric-lock';
      }

      if (status == AuthStatus.authenticated) {
        if (isPublicAuthRoute || loc == '/verify-email' || loc == '/biometric-lock') {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify_email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot_password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/biometric-lock',
        name: 'biometric_lock',
        builder: (context, state) => const BiometricLockScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rooms',
                name: 'rooms',
                builder: (context, state) => const RoomsLandingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                name: 'analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (context, state) => const MoreHubScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/room/join/:token',
        name: 'join_room_by_token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return JoinRoomByTokenScreen(token: token);
        },
      ),
      GoRoute(
        path: '/rooms/:id',
        name: 'room_workspace',
        builder: (context, state) {
          final roomId = state.pathParameters['id'] ?? '';
          return RoomWorkspaceScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/reminders',
        name: 'reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/to-do',
        name: 'to-do',
        builder: (context, state) => const GlobalToDoScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

// Legacy export for backwards compatibility
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
  ],
);

