import 'dart:async';
import 'package:flutter/material.dart';
import 'core/theme/theme_tokens.dart';
import 'core/router/app_router.dart';
import 'core/api/api_client.dart';

import 'core/notifier/profile_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProfileNotifier.init();
  runApp(const TravelibeApp());
}

class TravelibeApp extends StatefulWidget {
  const TravelibeApp({super.key});

  @override
  State<TravelibeApp> createState() => _TravelibeAppState();
}

class _TravelibeAppState extends State<TravelibeApp> {
  Timer? _inactivityTimer;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(hours: 1), _handleInactivityTimeout);
  }

  void _handleInactivityTimeout() async {
    // Clear user token and log out due to 1 hour inactivity
    await _apiClient.clearToken();
    AppRouter.router.go('/login');
    debugPrint('[TravelibeApp] Auto-logged out due to 1 hour inactivity.');
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: MaterialApp.router(
        title: 'Travelibe',
        theme: ThemeTokens.lightTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
