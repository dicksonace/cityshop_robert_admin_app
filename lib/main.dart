import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'router/app_router.dart';
import 'store/admin_store.dart';
import 'theme/app_theme.dart';

/// Bump with pubspec version so phones show which build is installed.
const adminAppVersion = '1.0.55';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release builds otherwise draw a blank grey ErrorWidget — show the real error.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    return Material(
      color: const Color(0xFFFFF1F2),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'Admin screen error (v$adminAppVersion)\n\n$message',
              style: const TextStyle(
                color: Color(0xFF9F1239),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Admin FlutterError: ${details.exceptionAsString()}');
  };

  final store = AdminStore(ApiClient());
  runApp(CityShopAdminApp(store: store));
}

class CityShopAdminApp extends StatefulWidget {
  const CityShopAdminApp({super.key, required this.store});

  final AdminStore store;

  @override
  State<CityShopAdminApp> createState() => _CityShopAdminAppState();
}

class _CityShopAdminAppState extends State<CityShopAdminApp> {
  late final router = createRouter(widget.store);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.store,
      child: MaterialApp.router(
        title: 'CityShop Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
