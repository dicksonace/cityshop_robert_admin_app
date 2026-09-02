import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/api_config.dart';
import '../theme/app_theme.dart';

final money = NumberFormat.currency(symbol: 'GH₵', decimalDigits: 2);

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> asMaps(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String str(dynamic value, [dynamic fallback = '']) {
  if (value == null) return fallback?.toString() ?? '';
  final text = value.toString().trim();
  return text.isEmpty ? (fallback?.toString() ?? '') : text;
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 40, this.light = false, this.rounded = false});

  final double height;
  final bool light;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: light ? Colors.white24 : AppColors.ringOrange,
        borderRadius: BorderRadius.circular(rounded ? height * 0.22 : 12),
      ),
      child: Text(
        'CS',
        style: TextStyle(
          fontSize: height * 0.32,
          fontWeight: FontWeight.w900,
          color: light ? Colors.white : AppColors.accent,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.label, this.color = AppColors.accent});

  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 14),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class FullPageLoader extends StatelessWidget {
  const FullPageLoader({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: AppLoader(label: label));
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          color: tint,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class NetworkThumb extends StatelessWidget {
  const NetworkThumb(this.url, {super.key, this.size = 52});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveMediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: AppColors.ringOrange,
        child: resolved.isEmpty
            ? const Icon(Icons.image_outlined, color: AppColors.accent)
            : CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    const Icon(Icons.image_outlined, color: AppColors.accent),
              ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelFor,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String Function(String option)? labelFor;

  String _label(String option) => labelFor?.call(option) ?? option.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final option in options) ...[
            FilterChip(
              label: Text(
                _label(option),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: value == option ? AppColors.primaryDark : AppColors.textSecondary,
                ),
              ),
              selected: value == option,
              showCheckmark: true,
              checkmarkColor: AppColors.primaryDark,
              selectedColor: AppColors.ringOrange,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: value == option ? AppColors.accent : const Color(0xFFE5E7EB),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              onSelected: (_) => onChanged(option),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        suffixIcon: IconButton(
          onPressed: onSearch,
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
      onSubmitted: (_) => onSearch(),
    );
  }
}

class AdminAccountCard extends StatelessWidget {
  const AdminAccountCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.photoUrl,
    this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String? photoUrl;
  final Widget? trailing;
  final VoidCallback onTap;

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveMediaUrl(photoUrl);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              if (resolved.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: resolved,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _avatarFallback(title),
                  ),
                )
              else
                _avatarFallback(title),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String value) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ringOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _initials(value),
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }
}

class AdminAwaitingOrderCard extends StatelessWidget {
  const AdminAwaitingOrderCard({
    super.key,
    required this.productName,
    required this.orderNumber,
    required this.statusLabel,
    this.subtitle,
    this.onTap,
    required this.onConfirm,
  });

  final String productName;
  final String orderNumber;
  final String statusLabel;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.25),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(statusLabel, color: AppColors.accent),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                orderNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onConfirm,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Confirm delivery', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String transferStatusFilterLabel(String option) {
  switch (option) {
    case 'open':
      return 'Needs action';
    case 'payment_submitted':
      return 'Payment in';
    case 'paid':
      return 'Payout sent';
    case 'all':
      return 'All';
    default:
      return option.replaceAll('_', ' ');
  }
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String label = 'Reason',
  String action = 'Submit',
  String? hint,
  String? initial,
  TextInputType keyboardType = TextInputType.text,
}) async {
  final ctrl = TextEditingController(text: initial ?? '');
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: keyboardType,
              maxLines: keyboardType == TextInputType.number ? 1 : 4,
              decoration: InputDecoration(labelText: label, hintText: hint),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text(action),
            ),
          ],
        ),
      );
    },
  );
  final value = ctrl.text.trim();
  ctrl.dispose();
  return ok == true ? value : null;
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  String action = 'Confirm',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : null,
    ),
  );
}

Future<void> copyText(BuildContext context, String value, {String label = 'Copied'}) async {
  final text = value.trim();
  if (text.isEmpty) {
    showSnack(context, 'Nothing to copy.', error: true);
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showSnack(context, label);
}
