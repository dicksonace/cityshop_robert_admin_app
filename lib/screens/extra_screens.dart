import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_chat_message.dart';
import '../widgets/common_widgets.dart';

class AdminResourceList extends StatefulWidget {
  const AdminResourceList({
    super.key,
    required this.title,
    required this.path,
    required this.itemBuilder,
    this.query = const {},
    this.filters,
    this.searchHint,
    this.onCreate,
    this.autoRefreshInterval,
    this.filterLabelFor,
    this.listHeader,
  });

  final String title;
  final String path;
  final Widget Function(Map<String, dynamic> item, VoidCallback reload) itemBuilder;
  final Map<String, dynamic> query;
  final List<String>? filters;
  final String? searchHint;
  final Future<void> Function()? onCreate;
  final Duration? autoRefreshInterval;
  final String Function(String option)? filterLabelFor;
  final Widget? Function(Map<String, dynamic>? meta)? listHeader;

  @override
  State<AdminResourceList> createState() => _AdminResourceListState();
}

class _AdminResourceListState extends State<AdminResourceList> {
  bool loading = true;
  bool silentLoading = false;
  String? error;
  String search = '';
  String? filter;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic>? listMeta;
  final _search = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    filter = widget.filters?.first;
    _load();
    _schedulePoll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    final interval = widget.autoRefreshInterval;
    if (interval == null) return;
    _pollTimer = Timer.periodic(interval, (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => silentLoading = true);
    }
    try {
      final data = await context.read<AdminStore>().getJson(widget.path, query: {
        ...widget.query,
        if (search.isNotEmpty) 'search': search,
        if (search.isNotEmpty) 'q': search,
        if (filter != null) 'status': filter,
      });
      if (!mounted) return;
      setState(() {
        items = asMaps(data['data']);
        listMeta = data['dashboard'] is Map ? Map<String, dynamic>.from(data['dashboard'] as Map) : null;
        loading = false;
        silentLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) error = e.message;
        loading = false;
        silentLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.listHeader?.call(listMeta);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/more');
            }
          },
        ),
        title: Text(widget.title),
        actions: [
          if (widget.autoRefreshInterval != null && !loading && error == null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: silentLoading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const SizedBox(
                                width: 10,
                                height: 10,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Auto refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: silentLoading ? null : () => _load(),
          ),
          if (widget.onCreate != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await widget.onCreate!();
                if (mounted) _load();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.searchHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AdminSearchField(
                controller: _search,
                hintText: widget.searchHint!,
                onSearch: () {
                  search = _search.text.trim();
                  _load();
                },
              ),
            ),
          if (widget.filters != null)
            FilterBar(
              options: widget.filters!,
              value: filter ?? widget.filters!.first,
              labelFor: widget.filterLabelFor,
              onChanged: (value) {
                filter = value;
                _load();
              },
            ),
          if (header != null) header,
          Expanded(
            child: loading
                ? const FullPageLoader()
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: () => _load(),
                        child: items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [SizedBox(height: 80), EmptyState('Nothing here yet.')],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) => widget.itemBuilder(items[index], () => _load()),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class BuyersScreen extends StatelessWidget {
  const BuyersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Buyers',
      path: '/admin/buyers',
      searchHint: 'Search name, email, mobile',
      itemBuilder: (item, _) => AdminAccountCard(
        title: str(item['name'], 'Buyer'),
        subtitle: '${str(item['mobile'])} · ${money.format(asDouble(item['available_balance']))}',
        trailing: item['is_blocked'] == true
            ? const StatusChip('blacklisted', color: AppColors.danger)
            : const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: () => context.push('/buyers/${item['id']}'),
      ),
    );
  }
}

class BuyerDetailScreen extends StatefulWidget {
  const BuyerDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<BuyerDetailScreen> createState() => _BuyerDetailScreenState();
}

class _BuyerDetailScreenState extends State<BuyerDetailScreen> {
  bool loading = true;
  bool busy = false;
  String? error;
  Map<String, dynamic> buyer = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson('/admin/buyers/${widget.id}');
      if (!mounted) return;
      setState(() {
        buyer = asMap(data['data']);
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final name = await promptText(context, title: 'Name', label: 'Name', hint: str(buyer['name']));
    if (name == null || !mounted) return;
    final email = await promptText(context, title: 'Email', label: 'Email', hint: str(buyer['email']));
    if (email == null || !mounted) return;
    final mobile = await promptText(context, title: 'Mobile', label: 'Mobile', hint: str(buyer['mobile']));
    if (mobile == null || !mounted) return;
    try {
      final result = await context.read<AdminStore>().patchJson('/admin/buyers/${widget.id}', data: {
        'name': name,
        'email': email,
        'mobile': mobile,
      });
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Updated.'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Done.'));
      if (result.containsKey('data')) {
        setState(() => buyer = asMap(result['data']));
      } else {
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _block() async {
    final reason = await promptText(context, title: 'Blacklist for security', label: 'Reason');
    if (reason == null || !mounted) return;
    await _run(() => context.read<AdminStore>().postJson('/admin/buyers/${widget.id}/block', data: {'reason': reason}));
  }

  Future<void> _unblock() async {
    await _run(() => context.read<AdminStore>().postJson('/admin/buyers/${widget.id}/unblock'));
  }

  Future<void> _delete() async {
    final reason = await promptText(context, title: 'Delete account', label: 'Reason');
    if (reason == null || !mounted) return;
    final confirm = await promptText(context, title: 'Type buyer email', label: 'Email', hint: str(buyer['email']));
    if (confirm == null || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await context.read<AdminStore>().deleteJson(
            '/admin/buyers/${widget.id}',
            data: {'reason': reason, 'confirm_email': confirm},
          );
      if (!mounted) return;
      showSnack(context, str(result['message'], 'Deleted.'));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = buyer['is_blocked'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(str(buyer['name'], 'Buyer')), actions: [
        IconButton(onPressed: loading || busy ? null : _edit, icon: const Icon(Icons.edit_outlined)),
      ]),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (busy) const LinearProgressIndicator(minHeight: 2),
                    if (blocked) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Blacklisted: ${str(buyer['block_reason'], 'Restricted for security')}',
                          style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(str(buyer['email'])),
                    Text(str(buyer['mobile'])),
                    const SizedBox(height: 8),
                    Text('Wallet ${money.format(asDouble(buyer['available_balance']))} · ${buyer['orders_count'] ?? 0} orders'),
                    const SizedBox(height: 20),
                    const Text('Security', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Blacklist locks the account — no login and no re-register with same email/phone. Delete removes the account and lets them sign up again.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (blocked)
                      PrimaryButton(label: 'Remove blacklist', loading: busy, onPressed: busy ? null : _unblock)
                    else
                      OutlinedButton(
                        onPressed: busy ? null : _block,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        child: const Text('Blacklist user'),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: busy ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                      ),
                      child: const Text('Delete account (allow re-register)'),
                    ),
                  ],
                ),
    );
  }
}

class InvitesScreen extends StatelessWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Seller invites',
      path: '/admin/seller-invites',
      onCreate: () async {
        final store = context.read<AdminStore>();
        final email = await promptText(context, title: 'Invite seller', label: 'Email (optional)', action: 'Create');
        if (email == null) return;
        try {
          final result = await store.postJson('/admin/seller-invites', data: {'email': email});
          if (!context.mounted) return;
          final url = str(result['registration_url']);
          if (url.isNotEmpty) {
            await Clipboard.setData(ClipboardData(text: url));
          }
          if (!context.mounted) return;
          showSnack(context, url.isNotEmpty ? 'Invite created. Link copied.' : str(result['message'], 'Invite created.'));
        } on ApiException catch (e) {
          if (!context.mounted) return;
          showSnack(context, e.message, error: true);
        }
      },
      itemBuilder: (item, _) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(str(item['email'], str(item['name'], 'Invite'))),
          subtitle: Text(str(item['status'])),
          trailing: StatusChip(str(item['status'])),
          onTap: () async {
            final url = str(item['registration_url']);
            if (url.isEmpty) return;
            await Clipboard.setData(ClipboardData(text: url));
            if (!context.mounted) return;
            showSnack(context, 'Link copied.');
          },
        ),
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Seller reports',
      path: '/admin/seller-reports',
      filters: const ['open', 'resolved', 'dismissed', 'all'],
      itemBuilder: (item, reload) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(str(asMap(item['seller'])['store'], str(asMap(item['seller'])['name']))),
          subtitle: Text('${str(item['reason'])} · ${str(item['details'])}'),
          trailing: StatusChip(str(item['status'])),
          onTap: () async {
            final status = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(title: const Text('Resolve'), onTap: () => Navigator.pop(ctx, 'resolved')),
                    ListTile(title: const Text('Dismiss'), onTap: () => Navigator.pop(ctx, 'dismissed')),
                    ListTile(title: const Text('Resolve and block seller'), onTap: () => Navigator.pop(ctx, 'block')),
                  ],
                ),
              ),
            );
            if (status == null || !context.mounted) return;
            try {
              await context.read<AdminStore>().patchJson('/admin/seller-reports/${item['id']}', data: {
                'status': status == 'block' ? 'resolved' : status,
                if (status == 'block') 'block_seller': true,
              });
              reload();
            } on ApiException catch (e) {
              if (!context.mounted) return;
              showSnack(context, e.message, error: true);
            }
          },
        ),
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Categories',
      path: '/admin/categories',
      onCreate: () async {
        final name = await promptText(context, title: 'New category', label: 'Name');
        if (name == null || !context.mounted) return;
        try {
          await context.read<AdminStore>().postJson('/admin/categories', data: {'name': name});
        } on ApiException catch (e) {
          if (!context.mounted) return;
          showSnack(context, e.message, error: true);
        }
      },
      itemBuilder: (item, reload) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text('${str(item['icon'])} ${str(item['name'])}'.trim()),
          subtitle: Text('${item['products_count'] ?? 0} products'),
          trailing: StatusChip(item['is_active'] == true ? 'active' : 'hidden'),
          onTap: () async {
            final hide = await confirmAction(context, title: str(item['name']), body: 'Hide or delete this category?', action: 'Hide');
            if (!hide || !context.mounted) return;
            try {
              await context.read<AdminStore>().deleteJson('/admin/categories/${item['id']}');
              reload();
            } on ApiException catch (e) {
              if (!context.mounted) return;
              showSnack(context, e.message, error: true);
            }
          },
        ),
      ),
    );
  }
}

class StoresScreen extends StatelessWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Store oversight',
      path: '/admin/stores',
      searchHint: 'Search stores',
      itemBuilder: (item, _) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(str(item['store_name'])),
          subtitle: Text(str(asMap(item['user'])['name'])),
          trailing: StatusChip(str(item['status'])),
          onTap: () => context.push('/stores/${item['id']}'),
        ),
      ),
    );
  }
}

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  bool loading = true;
  String? error;
  String status = 'approved';
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic> seller = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson('/admin/stores/${widget.id}', query: {'status': status});
      if (!mounted) return;
      setState(() {
        seller = asMap(data['seller']);
        products = asMaps(data['data']);
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _act(int id, String action) async {
    try {
      final result = await context.read<AdminStore>().postJson(
            action == 'restore'
                ? '/admin/stores/${widget.id}/products/$id/restore'
                : '/admin/stores/${widget.id}/products/$id/$action',
          );
      if (!mounted) return;
      showSnack(context, str(result['message']));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(str(seller['store_name'], 'Store'))),
      body: Column(
        children: [
          FilterBar(
            options: const ['approved', 'pending', 'draft', 'rejected', 'deleted'],
            value: status,
            onChanged: (value) {
              status = value;
              _load();
            },
          ),
          Expanded(
            child: loading
                ? const FullPageLoader()
                : error != null
                    ? ErrorRetry(message: error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: products.isEmpty
                            ? ListView(children: const [SizedBox(height: 80), EmptyState('No products.')])
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: products.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final product = products[index];
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      leading: NetworkThumb(product['image'] as String?),
                                      title: Text(str(product['name'])),
                                      subtitle: Text(money.format(asDouble(product['price']))),
                                      trailing: StatusChip(str(product['status'])),
                                      onTap: () async {
                                        final choice = await showModalBottomSheet<String>(
                                          context: context,
                                          builder: (ctx) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(title: const Text('Approve'), onTap: () => Navigator.pop(ctx, 'approve')),
                                                ListTile(title: const Text('Hide'), onTap: () => Navigator.pop(ctx, 'hide')),
                                                ListTile(title: const Text('Trash'), onTap: () => Navigator.pop(ctx, 'delete')),
                                                if (product['trashed'] == true)
                                                  ListTile(title: const Text('Restore'), onTap: () => Navigator.pop(ctx, 'restore')),
                                              ],
                                            ),
                                          ),
                                        );
                                        if (!context.mounted) return;
                                        if (choice == null) return;
                                        final store = context.read<AdminStore>();
                                        if (choice == 'delete') {
                                          try {
                                            await store.deleteJson(
                                                  '/admin/stores/${widget.id}/products/${product['id']}',
                                                );
                                            await _load();
                                          } on ApiException catch (e) {
                                            if (!context.mounted) return;
                                            showSnack(context, e.message, error: true);
                                          }
                                        } else {
                                          await _act(asInt(product['id']), choice);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Chats',
      path: '/admin/chats',
      searchHint: 'Search buyer or seller',
      itemBuilder: (item, _) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text('${str(asMap(item['buyer'])['name'])} ↔ ${str(asMap(item['seller'])['name'])}'),
          subtitle: Text(str(item['latest_message'], 'No messages')),
          onTap: () => context.push('/chats/${item['id']}'),
        ),
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  bool loading = true;
  bool loadingMore = false;
  String? error;
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic> chat = {};
  int page = 1;
  int lastPage = 1;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final nextPage = reset ? 1 : page + 1;
    if (reset) {
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => loadingMore = true);
    }
    try {
      final data = await context.read<AdminStore>().getJson(
            '/admin/chats/${widget.id}',
            query: {'page': nextPage},
          );
      if (!mounted) return;
      final meta = asMap(data['meta']);
      setState(() {
        chat = asMap(data['data']);
        final batch = asMaps(data['messages']);
        messages = reset ? batch : [...messages, ...batch];
        page = asInt(meta['current_page'] ?? nextPage);
        lastPage = asInt(meta['last_page'] ?? 1);
        loading = false;
        loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
        loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyer = asMap(chat['buyer']);
    final seller = asMap(chat['seller']);
    final buyerId = asInt(buyer['id']);
    final blocked = chat['blocked'] == true;

    return Scaffold(
      appBar: AppBar(title: Text('${str(buyer['name'])} ↔ ${str(seller['name'])}')),
      body: loading
          ? const FullPageLoader(label: 'Loading chat…')
          : error != null
              ? ErrorRetry(message: error!, onRetry: () => _load(reset: true))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      if (blocked)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Text(
                            'One of these users has blocked the other — messaging and transfers are disabled.',
                            style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: const Text(
                          'Admin oversight view. Photos, videos, voice notes, files, and transfers are shown here for review.',
                          style: TextStyle(color: Color(0xFF92400E), fontSize: 13, height: 1.35),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _ChatParticipantCard(
                              label: 'Buyer',
                              name: str(buyer['name']),
                              detail: str(buyer['mobile'], str(buyer['email'])),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ChatParticipantCard(
                              label: 'Seller',
                              name: str(seller['name']),
                              detail: str(seller['mobile'], str(seller['email'])),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (messages.isEmpty)
                        const EmptyState('No messages in this conversation.')
                      else ...[
                        for (final message in messages)
                          AdminChatMessageBubble(
                            message: message,
                            buyerId: buyerId > 0 ? buyerId : null,
                          ),
                        if (page < lastPage)
                          Center(
                            child: TextButton(
                              onPressed: loadingMore ? null : _load,
                              child: Text(loadingMore ? 'Loading…' : 'Load more messages'),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _ChatParticipantCard extends StatelessWidget {
  const _ChatParticipantCard({
    required this.label,
    required this.name,
    required this.detail,
  });

  final String label;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          if (detail.isNotEmpty)
            Text(detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Contact messages',
      path: '/admin/contact-messages',
      itemBuilder: (item, reload) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(str(item['subject'], str(item['name']))),
          subtitle: Text(str(item['body'])),
          trailing: item['is_read'] == true ? null : const StatusChip('new'),
          onTap: () async {
            try {
              await context.read<AdminStore>().patchJson('/admin/contact-messages/${item['id']}/read');
              reload();
            } on ApiException catch (e) {
              if (!context.mounted) return;
              showSnack(context, e.message, error: true);
            }
          },
        ),
      ),
    );
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.audience});

  final String audience; // sellers | buyers

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  bool get _sellers => widget.audience == 'sellers';

  String get _path => _sellers ? '/admin/announcements' : '/admin/buyer-announcements';

  String get _title => _sellers ? 'Seller announcements' : 'Buyer announcements';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<AdminStore>().getJson(_path);
      if (!mounted) return;
      setState(() {
        items = asMaps(data['data']);
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _create() async {
    final title = await promptText(context, title: 'Title', label: 'Title');
    if (title == null || !context.mounted) return;
    final body = await promptText(context, title: 'Message', label: 'Body');
    if (body == null || !context.mounted) return;
    try {
      await context.read<AdminStore>().postJson(
            _path,
            data: {'audience': 'all', 'title': title, 'body': body, 'send_email': false},
          );
      if (!context.mounted) return;
      showSnack(context, 'Sent.');
      await _load();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  Future<bool> _confirmDelete(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 30),
        ),
        iconPadding: const EdgeInsets.only(top: 20),
        title: const Text('Delete announcement?'),
        content: Text(
          '“$title” will be removed from this list.\n\n'
          '${_sellers ? 'Sellers' : 'Buyers'} who already received it keep their notification.',
          style: const TextStyle(height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteItem(int id) async {
    await context.read<AdminStore>().deleteJson('$_path/$id');
  }

  void _removeItem(int id) {
    setState(() => items.removeWhere((e) => asInt(e['id']) == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/more');
            }
          },
        ),
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => unawaited(_create()),
          ),
        ],
      ),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            EmptyState('No announcements yet.'),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _AnnouncementTile(
                              key: ValueKey(asInt(item['id'])),
                              item: item,
                              sellers: _sellers,
                              onConfirmDelete: () => _confirmDelete(str(item['title'], 'this announcement')),
                              onDelete: () => _deleteItem(asInt(item['id'])),
                              onRemoved: () {
                                _removeItem(asInt(item['id']));
                                if (mounted) showSnack(context, 'Announcement deleted.');
                              },
                              onError: (message) {
                                if (mounted) showSnack(context, message, error: true);
                              },
                            );
                          },
                        ),
                ),
    );
  }
}

class _AnnouncementTile extends StatefulWidget {
  const _AnnouncementTile({
    super.key,
    required this.item,
    required this.sellers,
    required this.onConfirmDelete,
    required this.onDelete,
    required this.onRemoved,
    required this.onError,
  });

  final Map<String, dynamic> item;
  final bool sellers;
  final Future<bool> Function() onConfirmDelete;
  final Future<void> Function() onDelete;
  final VoidCallback onRemoved;
  final void Function(String message) onError;

  @override
  State<_AnnouncementTile> createState() => _AnnouncementTileState();
}

class _AnnouncementTileState extends State<_AnnouncementTile> with SingleTickerProviderStateMixin {
  late final AnimationController _exit;
  late final Animation<double> _size;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _busy = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    final curve = CurvedAnimation(parent: _exit, curve: Curves.easeInOutCubic);
    _size = Tween<double>(begin: 1, end: 0).animate(curve);
    _fade = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _exit, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: Offset.zero, end: const Offset(0.12, 0)).animate(curve);
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (_busy || _removed) return;
    final ok = await widget.onConfirmDelete();
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete();
      if (!mounted) return;
      await _exit.forward();
      if (!mounted) return;
      setState(() => _removed = true);
      widget.onRemoved();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onError('Could not delete announcement.');
    }
  }

  void _openDetails() {
    if (_busy || _removed) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              str(widget.item['title']),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              str(widget.item['body']),
              style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        unawaited(_handleDelete());
                      },
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                label: const Text('Delete announcement', style: TextStyle(color: AppColors.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();

    final audience = str(widget.item['audience']);
    final sent = widget.item['recipients_count'] ?? 0;

    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.ringOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.sellers ? Icons.storefront_outlined : Icons.shopping_bag_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      str(widget.item['title']),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$audience · $sent sent',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: _busy ? null : () => unawaited(_handleDelete()),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: card,
        ),
      ),
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool loading = true;
  bool loadingMore = false;
  String? error;
  String search = '';
  String typeFilter = 'all';
  List<Map<String, dynamic>> items = [];
  int currentPage = 1;
  int lastPage = 1;
  int total = 0;
  final _search = TextEditingController();

  static const _typeFilters = <(String, String)>[
    ('all', 'All'),
    ('transfer_in', 'Received'),
    ('transfer_out', 'Sent'),
    ('order_payment', 'Orders'),
    ('fund_added', 'Top-ups'),
    ('withdrawal', 'Withdrawals'),
    ('sale_pending', 'Sales'),
  ];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false, bool silent = false}) async {
    if (reset) {
      if (!silent) {
        setState(() {
          loading = true;
          error = null;
        });
      }
      currentPage = 1;
    } else {
      setState(() => loadingMore = true);
    }
    try {
      final page = reset ? 1 : currentPage + 1;
      final data = await context.read<AdminStore>().getJson('/admin/transactions', query: {
        'page': page,
        'per_page': 25,
        if (search.isNotEmpty) 'search': search,
        if (typeFilter != 'all') 'type': typeFilter,
      });
      if (!mounted) return;
      final batch = asMaps(data['data']);
      final meta = asMap(data['meta']);
      setState(() {
        if (reset) {
          items = batch;
        } else {
          items = [...items, ...batch];
        }
        currentPage = asInt(meta['current_page']);
        if (currentPage == 0) currentPage = page;
        lastPage = asInt(meta['last_page']);
        if (lastPage == 0) lastPage = 1;
        total = asInt(meta['total']);
        if (total == 0) total = items.length;
        loading = false;
        loadingMore = false;
        error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) error = e.message;
        loading = false;
        loadingMore = false;
      });
    }
  }

  void _submitSearch() {
    search = _search.text.trim();
    _load(reset: true);
  }

  String _formatAmount(double amount) {
    final formatted = money.format(amount.abs());
    if (amount < 0) return '-$formatted';
    return formatted;
  }

  void _openDetail(Map<String, dynamic> item) {
    final user = asMap(item['user']);
    final amount = asDouble(item['amount']);
    final credit = amount >= 0;
    final createdAt = str(item['created_at']);
    String when = createdAt;
    if (createdAt.isNotEmpty) {
      try {
        when = DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(createdAt).toLocal());
      } catch (_) {}
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  str(item['type_label'], str(item['type'])),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatAmount(amount),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: credit ? const Color(0xFF111827) : AppColors.danger,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(label: 'User', value: str(user['name'], '—')),
                if (str(user['mobile']).isNotEmpty) _DetailRow(label: 'Phone', value: str(user['mobile'])),
                if (str(user['role']).isNotEmpty) _DetailRow(label: 'Role', value: str(user['role'])),
                if (str(item['description']).isNotEmpty) _DetailRow(label: 'Details', value: str(item['description'])),
                if (str(item['reference']).isNotEmpty)
                  _DetailRow(
                    label: 'Reference',
                    value: str(item['reference']),
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: str(item['reference'])));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reference copied')),
                      );
                    },
                  ),
                if (when.isNotEmpty) _DetailRow(label: 'When', value: when),
                const SizedBox(height: 8),
                if (user['id'] != null)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final role = str(user['role']);
                      if (role == 'seller') {
                        context.push('/sellers/${user['id']}');
                      } else {
                        context.push('/buyers/${user['id']}');
                      }
                    },
                    child: const Text('Open user profile'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/more');
            }
          },
        ),
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: loading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search name or reference',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  onPressed: _submitSearch,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: (_) => _submitSearch(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _typeFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (value, label) = _typeFilters[i];
                final selected = typeFilter == value;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.accent,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: selected ? AppColors.accent : const Color(0xFFE5E7EB)),
                  onSelected: (_) {
                    setState(() => typeFilter = value);
                    _load(reset: true);
                  },
                );
              },
            ),
          ),
          if (!loading && error == null && total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                '$total transaction${total == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              ),
            ),
          Expanded(
            child: loading
                ? const FullPageLoader()
                : error != null
                    ? ErrorRetry(message: error!, onRetry: () => _load(reset: true))
                    : RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: items.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState('No transactions found.'),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                                itemCount: items.length + (currentPage < lastPage ? 1 : 0),
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index >= items.length) {
                                    return TextButton(
                                      onPressed: loadingMore ? null : () => _load(),
                                      child: Text(loadingMore ? 'Loading…' : 'Load more'),
                                    );
                                  }
                                  return _AdminTransactionCard(
                                    item: items[index],
                                    formatAmount: _formatAmount,
                                    onTap: () => _openDetail(items[index]),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35)),
          ),
          if (onCopy != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}

class _AdminTransactionCard extends StatelessWidget {
  const _AdminTransactionCard({
    required this.item,
    required this.formatAmount,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final String Function(double amount) formatAmount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = asMap(item['user']);
    final userName = str(user['name']);
    final description = str(item['description']);
    final reference = str(item['reference']);
    final typeLabel = str(item['type_label'], str(item['type']));
    final amount = asDouble(item['amount']);
    final credit = amount >= 0;

    final detailParts = <String>[
      if (userName.isNotEmpty) userName,
      if (description.isNotEmpty) description,
      if (reference.isNotEmpty) reference,
    ];
    final detailLine = detailParts.join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.25),
                    ),
                    if (detailLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        detailLine,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatAmount(amount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: credit ? const Color(0xFF111827) : AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
