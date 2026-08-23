import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../store/admin_store.dart';
import '../theme/app_theme.dart';
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
  });

  final String title;
  final String path;
  final Widget Function(Map<String, dynamic> item, VoidCallback reload) itemBuilder;
  final Map<String, dynamic> query;
  final List<String>? filters;
  final String? searchHint;
  final Future<void> Function()? onCreate;

  @override
  State<AdminResourceList> createState() => _AdminResourceListState();
}

class _AdminResourceListState extends State<AdminResourceList> {
  bool loading = true;
  String? error;
  String search = '';
  String? filter;
  List<Map<String, dynamic>> items = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    filter = widget.filters?.first;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
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
        title: Text(widget.title),
        actions: [
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
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(onPressed: () { search = _search.text.trim(); _load(); }, icon: const Icon(Icons.arrow_forward)),
                ),
                onSubmitted: (value) {
                  search = value.trim();
                  _load();
                },
              ),
            ),
          if (widget.filters != null)
            FilterBar(
              options: widget.filters!,
              value: filter ?? widget.filters!.first,
              onChanged: (value) {
                filter = value;
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
                        child: items.isEmpty
                            ? ListView(children: const [SizedBox(height: 80), EmptyState('Nothing here yet.')])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) => widget.itemBuilder(items[index], _load),
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
      itemBuilder: (item, _) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(str(item['name'])),
          subtitle: Text('${str(item['mobile'])} · ${money.format(asDouble(item['available_balance']))}'),
          trailing: item['is_blocked'] == true ? const StatusChip('blocked') : const Icon(Icons.chevron_right),
          onTap: () => context.push('/buyers/${item['id']}'),
        ),
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
    final reason = await promptText(context, title: 'Block buyer', label: 'Reason');
    if (reason == null || !mounted) return;
    await _run(() => context.read<AdminStore>().postJson('/admin/buyers/${widget.id}/block', data: {'reason': reason}));
  }

  Future<void> _unblock() async {
    await _run(() => context.read<AdminStore>().postJson('/admin/buyers/${widget.id}/unblock'));
  }

  Future<void> _delete() async {
    final reason = await promptText(context, title: 'Delete buyer', label: 'Reason');
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
                          'Blocked: ${str(buyer['block_reason'], 'Account blocked by admin')}',
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
                    const Text('Account', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Block stops sign-in. Delete removes the account and frees email/phone for a new registration.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (blocked)
                      PrimaryButton(label: 'Unblock buyer', loading: busy, onPressed: busy ? null : _unblock)
                    else
                      OutlinedButton(
                        onPressed: busy ? null : _block,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        child: const Text('Block buyer'),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: busy ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                      ),
                      child: const Text('Delete buyer account'),
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
  String? error;
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic> chat = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AdminStore>().getJson('/admin/chats/${widget.id}');
      if (!mounted) return;
      setState(() {
        chat = asMap(data['data']);
        messages = asMaps(data['messages']);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${str(asMap(chat['buyer'])['name'])} ↔ ${str(asMap(chat['seller'])['name'])}')),
      body: loading
          ? const FullPageLoader()
          : error != null
              ? ErrorRetry(message: error!, onRetry: _load)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return ListTile(
                      title: Text(str(asMap(message['sender'])['name'], 'User')),
                      subtitle: Text(str(message['body'], str(message['type']))),
                    );
                  },
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

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key, required this.audience});

  final String audience; // sellers | buyers

  @override
  Widget build(BuildContext context) {
    final sellers = audience == 'sellers';
    return AdminResourceList(
      title: sellers ? 'Seller announcements' : 'Buyer announcements',
      path: sellers ? '/admin/announcements' : '/admin/buyer-announcements',
      onCreate: () async {
        final title = await promptText(context, title: 'Title', label: 'Title');
        if (title == null || !context.mounted) return;
        final body = await promptText(context, title: 'Message', label: 'Body');
        if (body == null || !context.mounted) return;
        try {
          await context.read<AdminStore>().postJson(
                sellers ? '/admin/announcements' : '/admin/buyer-announcements',
                data: {'audience': 'all', 'title': title, 'body': body, 'send_email': false},
              );
          if (!context.mounted) return;
          showSnack(context, 'Sent.');
        } on ApiException catch (e) {
          if (!context.mounted) return;
          showSnack(context, e.message, error: true);
        }
      },
      itemBuilder: (item, _) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(str(item['title'])),
          subtitle: Text('${str(item['audience'])} · ${item['recipients_count'] ?? 0} sent'),
        ),
      ),
    );
  }
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminResourceList(
      title: 'Transactions',
      path: '/admin/transactions',
      searchHint: 'Search name or reference',
      itemBuilder: (item, _) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(str(item['type_label'], str(item['type']))),
          subtitle: Text('${str(asMap(item['user'])['name'])} · ${str(item['description'])}'),
          trailing: Text(money.format(asDouble(item['amount']))),
        ),
      ),
    );
  }
}
