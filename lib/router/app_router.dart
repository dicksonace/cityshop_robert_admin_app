import 'package:go_router/go_router.dart';

import '../screens/auth_screens.dart';
import '../screens/china_screens.dart';
import '../screens/extra_screens.dart';
import '../screens/home_screen.dart';
import '../screens/kyc_screens.dart';
import '../screens/money_screens.dart';
import '../screens/more_screens.dart';
import '../screens/orders_screens.dart';
import '../screens/sellers_screens.dart';
import '../screens/settings_screens.dart';
import '../screens/shell_screen.dart';
import '../store/admin_store.dart';

GoRouter createRouter(AdminStore store) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: store,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (store.booting) {
        return loc == '/splash' ? null : '/splash';
      }
      if (loc == '/splash') {
        return store.isLoggedIn ? '/home' : '/login';
      }
      final public = loc == '/login';
      if (!store.isLoggedIn && !public) return '/login';
      if (store.isLoggedIn && public) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShellScreen(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/sellers', builder: (_, _) => const SellersScreen()),
          GoRoute(
            path: '/orders',
            builder: (_, state) => OrdersScreen(
              initialTab: state.uri.queryParameters['tab'] ?? 'all',
            ),
          ),
          GoRoute(
            path: '/money',
            builder: (_, state) => MoneyScreen(
              initialTab: state.uri.queryParameters['tab'] ?? 'withdrawals',
            ),
          ),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
        ],
      ),
      GoRoute(
        path: '/sellers/:id',
        builder: (_, state) => SellerDetailScreen(
          id: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => OrderDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/products', builder: (_, _) => const ProductsScreen()),
      GoRoute(path: '/disputes', builder: (_, _) => const DisputesScreen()),
      GoRoute(path: '/pending-funds', builder: (_, _) => const PendingFundsScreen()),
      GoRoute(path: '/wallet-funding', builder: (_, _) => const WalletFundingScreen()),
      GoRoute(path: '/buyers', builder: (_, _) => const BuyersScreen()),
      GoRoute(
        path: '/buyers/:id',
        builder: (_, state) => BuyerDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/kyc', builder: (_, _) => const KycQueueScreen()),
      GoRoute(
        path: '/kyc/:id',
        builder: (_, state) => KycDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/invites', builder: (_, _) => const InvitesScreen()),
      GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
      GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
      GoRoute(path: '/stores', builder: (_, _) => const StoresScreen()),
      GoRoute(
        path: '/stores/:id',
        builder: (_, state) => StoreDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
      GoRoute(
        path: '/chats/:id',
        builder: (_, state) => ChatDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/contact', builder: (_, _) => const ContactScreen()),
      GoRoute(path: '/announcements', builder: (_, _) => const AnnouncementsScreen(audience: 'sellers')),
      GoRoute(path: '/buyer-announcements', builder: (_, _) => const AnnouncementsScreen(audience: 'buyers')),
      GoRoute(path: '/transactions', builder: (_, _) => const TransactionsScreen()),
      GoRoute(path: '/china-transfers', builder: (_, _) => const ChinaTransfersScreen()),
      GoRoute(
        path: '/china-transfers/:id',
        builder: (_, state) => ChinaTransferDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/sell-rmb', builder: (_, _) => const SellRmbScreen()),
      GoRoute(
        path: '/sell-rmb/:id',
        builder: (_, state) => SellRmbDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/china-settings', builder: (_, _) => const ChinaSettingsScreen()),
      GoRoute(path: '/sell-rmb-settings', builder: (_, _) => const SellRmbSettingsScreen()),
      GoRoute(path: '/settings/sms', builder: (_, _) => const SmsSettingsScreen()),
      GoRoute(path: '/settings/paystack', builder: (_, _) => const PaystackSettingsScreen()),
      GoRoute(path: '/settings/withdrawal', builder: (_, _) => const WithdrawalSettingsScreen()),
      GoRoute(path: '/settings/manual-funding', builder: (_, _) => const ManualFundingSettingsScreen()),
    ],
  );
}
