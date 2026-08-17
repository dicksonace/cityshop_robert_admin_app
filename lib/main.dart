import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'router/app_router.dart';
import 'store/admin_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
