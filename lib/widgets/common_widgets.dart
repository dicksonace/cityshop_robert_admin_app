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

String str(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
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

String transferStatusFilterLabel(String option) {
  switch (option) {
    case 'open':
      return 'Needs action';
    case 'payment_submitted':
      return 'Payment in';
    case 'rmb_sent':
      return 'RMB sent';
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
