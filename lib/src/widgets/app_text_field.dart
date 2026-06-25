import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fill =
        p.isDark ? p.bgElevated.withValues(alpha: 0.85) : p.surfaceHigh;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      style: TextStyle(color: p.textPrimary, fontSize: 15),
      cursorColor: p.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: p.textMuted, size: 20),
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
        helperStyle: TextStyle(color: p.textMuted, fontSize: 11.5),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.borderSoft, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.borderSoft, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
        errorStyle: TextStyle(color: p.danger, fontSize: 12),
      ),
    );
  }
}

class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_month_rounded,
    this.placeholder,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData icon;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasValue = value != null && value!.isNotEmpty;
    final fill =
        p.isDark ? p.bgElevated.withValues(alpha: 0.85) : p.surfaceHigh;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: p.borderSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? value! : (placeholder ?? "Sec"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasValue ? p.textPrimary : p.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: p.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
