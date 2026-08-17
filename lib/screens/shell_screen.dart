import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AdminShellScreen extends StatelessWidget {
  const AdminShellScreen({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    ('/home', Icons.dashboard_outlined, 'Home'),
    ('/sellers', Icons.storefront_outlined, 'Sellers'),
    ('/orders', Icons.receipt_long_outlined, 'Orders'),
    ('/money', Icons.account_balance_wallet_outlined, 'Money'),
    ('/more', Icons.more_horiz, 'More'),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].$1 || location.startsWith('${_tabs[i].$1}/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        indicatorColor: AppColors.ringOrange,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.$2), label: tab.$3),
        ],
      ),
    );
  }
}
