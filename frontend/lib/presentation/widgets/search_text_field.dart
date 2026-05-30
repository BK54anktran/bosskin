import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Search field chuẩn: prefixIcon search, suffixIcon clear, isDense.
class SearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const SearchTextField({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint ?? s.search,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                },
              )
            : null,
      ),
      onChanged: onChanged,
    );
  }
}
