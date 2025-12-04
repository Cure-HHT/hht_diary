// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework
//   REQ-d00029: Portal UI Design System

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';

// import 'config/database_config.dart';
// import 'router/app_router.dart';
//import 'services/auth_service.dart';
import 'theme/portal_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URLs
  setPathUrlStrategy();

  // Note: Database initialization happens in DatabaseConfig
  // Set DatabaseConfig.useLocalDatabase = true for local testing

  runApp(const CarinaPortalApp());
}

class CarinaPortalApp extends StatelessWidget {
  const CarinaPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp.router(
        title: 'Carina Clinical Trial Portal',
        theme: portalTheme,
        // routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
